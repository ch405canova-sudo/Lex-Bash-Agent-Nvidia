#!/bin/bash
# install.sh — Lex-Bash-Agent-Nvidia
#
# Baut die Umgebung von ~/Ai/ 1:1 nach, aber ohne Modell und ohne private Daten:
#   1 Precheck   2 Abhängigkeiten (sudo)   3 llama.cpp-Prism-Fork mit CUDA bauen
#   4 Payload nach ~/Ai/   5 Aliase + Symlink   6 lex --install   7 Modell suchen
#   8 Verifikation (Pfade, Syntax, 19 Testläufer, sha256)   9 Report
#
# Flags:
#   --dry-run    nichts schreiben, nur ausgeben
#   --verify     nichts installieren, nur Integritäts-/Funktionstests
#   -h/--help    diese Hilfe
# Ohne TTY wird ebenfalls nur berichtet (Kopierschutz für Pipelines).
#
# Regeln dieses Skripts: nur Pure Bash + jq + curl, nichts außerhalb $HOME
# (außer ~/.bashrc-Markerblock und ~/.local/bin), kein Download eines Modells,
# niemals eine Anfrage an 127.0.0.1:8080.
set -u

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload/Ai"
AI_ROOT="$HOME/Ai"
LEX_DIR="$AI_ROOT/lex"
BIN_DIR="${LEX_BIN_DIR:-$HOME/.local/bin}"
BASHRC="$HOME/.bashrc"
MANIFEST="$SCRIPT_DIR/manifest/sha256-payload.txt"

LLAMA_REPO="https://github.com/PrismML-Eng/llama.cpp.git"
# Produktions-Commit — derselbe Stand wie auf der Entwickler-Maschine (Branch prism).
LLAMA_COMMIT="e3de715222b2667c54a267441159a5729f11155e"
# Fallback: fertiges CUDA-Release desselben Forks (sm_89-CUDA-Build).
FALLBACK_CUDA_REL="prism-b10828-a153697"
FALLBACK_CUDA_ASSET="llama-prism-b10828-a153697-bin-linux-cuda-12.4-x64.tar.gz"

MODEL_NAME="Ternary-Bonsai-2-27B-PQ2_0.gguf"
# Aux-Dateien, die bereits im Payload liegen (kein Modellgewicht):
#   model/chat_template.jinja, model/kv-mean-center-bonsai.gguf, model/KNOWN_ISSUES.md

DRY=0
VERIFY_ONLY=0
INTERACTIVE=1
WARNINGS=()

# ------------------------------------------------------------------ Ausgabe
c_ok="✓"; c_no="✗"; c_info="·"; c_warn="⚠"
[ -t 1 ] || { c_ok="[OK]"; c_no="[FEHLER]"; c_info="[INFO]"; c_warn="[WARNUNG]"; }
info() { printf '%s %s\n' "$c_info" "$*"; }
ok()   { printf '%s %s\n' "$c_ok" "$*"; }
warn() { printf '%s %s\n' "$c_warn" "$*"; WARNINGS+=("$*"); }
err()  { printf '%s %s\n' "$c_no" "$*" >&2; }
step() { printf '\n\033[1m== %s ==\033[0m\n' "$*" 2>/dev/null || printf '\n== %s ==\n' "$*"; }

# Ohne TTY wird nichts beschrieben, nur berichtet (Kopierschutz für Pipelines).
ask() {
    [ "$DRY" = 1 ] && { info "[dry-run] würde ausführen: $*"; return 1; }
    [ "$VERIFY_ONLY" = 1 ] && return 1
    [ "$INTERACTIVE" = 1 ] || { info "[headless] übersprungen: $*"; return 1; }
    return 0
}

run_cmd() {   # ausführen oder im dry-run ausgeben
    if [ "$DRY" = 1 ]; then info "[dry-run] $*"; return 0; fi
    "$@"
}

usage() {
    cat <<EOF
install.sh — Lex-Bash-Agent-Nvidia

Aufruf: ./install.sh [--dry-run|--verify|--help]

  (kein Flag)  Installation: Abhängigkeiten, llama-Build, ~/Ai/, Aliase, Tests
  --dry-run    nur ausgeben, nichts verändern
  --verify     nur prüfen: Pfade, Syntax, Testlauf, sha256
  --help       diese Hilfe

Voraussetzungen: Debian/Ubuntu x86_64, NVIDIA-Treiber (nvidia-smi),
Modell $MODEL_NAME (6,71 GiB) wird NICHT mitgeliefert —
es muss schon lokal vorliegen (Schritt 7 sucht es).
EOF
}

# ------------------------------------------------------------ Argumente
for a in "$@"; do
    case "$a" in
        --dry-run)  DRY=1 ;;
        --verify)   VERIFY_ONLY=1 ;;
        -h|--help)  usage; exit 0 ;;
        *) err "Unbekanntes Argument: $a"; usage; exit 2 ;;
    esac
done
[ -t 0 ] && [ -t 1 ] || INTERACTIVE=0

# ================================================================== 1 Precheck
precheck() {
    step "1 · Precheck"
    local okall=0

    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
            debian|ubuntu) ok "$PRETTY_NAME" ;;
            *) warn "nicht Debian/Ubuntu (${ID:-unbekannt}) — apt-Befehle passen evtl. nicht"; okall=1 ;;
        esac
    else
        warn "/etc/os-release fehlt — Distribution unbekannt"; okall=1
    fi

    [ "$(uname -m)" = "x86_64" ] && ok "Architektur x86_64" \
        || { err "Architektur $(uname -m) — nicht unterstützt (CUDA-Build nur x86_64)"; okall=1; }

    if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        ok "bash ${BASH_VERSION} (≥ 4)"
    else
        err "bash ${BASH_VERSION} zu alt (≥ 4 nötig, coproc)"; okall=1
    fi

    if [ -w "$HOME" ]; then ok "\$HOME beschreibbar: $HOME"
    else err "\$HOME nicht beschreibbar"; okall=1; fi

    # Payload vorhanden?
    if [ -d "$PAYLOAD/lex" ] && [ -f "$PAYLOAD/lex/lex" ] && [ -f "$PAYLOAD/ai.sh" ]; then
        ok "Payload gefunden: $PAYLOAD"
    else
        err "Payload unvollständig — Skript aus dem Repo-Wurzelverzeichnis starten"
        err "  erwartet: payload/Ai/lex/lex und payload/Ai/ai.sh"
        okall=1
    fi

    # GPU / Treiber
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_line
        gpu_line="$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | head -1)"
        if [ -n "$gpu_line" ]; then
            ok "GPU: $gpu_line"
        else
            warn "nvidia-smi vorhanden, liefert aber keine Daten (Treiber/Konflikt?)"; okall=1
        fi
    else
        warn "nvidia-smi fehlt — NVIDIA-Treiber installieren (ohne Treiber startet llama-server nicht)"
        warn '  Treiber-Check: Ubuntu → Treiber & Software → "NVIDIA-Grafiktreiber"'
        okall=1
    fi

    # Port 8080 (nur schauen, nie anfragen)
    if ss -tln 2>/dev/null | grep -q ':8080'; then
        info "Port 8080 ist belegt — vermutlich läuft bereits ein llama-server"
    else
        ok "Port 8080 frei"
    fi

    # Platz: Payload + Fork-Quellen + Build
    local free_mb
    free_mb="$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}')"
    if [ -n "${free_mb:-}" ]; then
        if [ "$free_mb" -ge 6144 ]; then
            ok "freier Speicher: ${free_mb} MiB (≥ 6 GiB empfohlen)"
        else
            warn "nur ${free_mb} MiB frei — Build braucht ca. 5 GiB (Quellen + CUDA-Toolkit)"; okall=1
        fi
    fi

    [ "$okall" = 0 ] || info "Warnungen oben sind kein Abbruch, es sei denn ein harter Punkt ist markiert."
    return 0
}

# ============================================================ 2 Abhängigkeiten
have() { command -v "$1" >/dev/null 2>&1; }

apt_install() {   # apt_install paket...
    local pkgs=("$@") missing=() p
    for p in "${pkgs[@]}"; do have "$p" && continue; missing+=("$p"); done
    [ "${#missing[@]}" -eq 0 ] && return 0
    if [ "$DRY" = 1 ]; then
        info "[dry-run] sudo apt-get install -y ${missing[*]}"
        return 0
    fi
    if ! have sudo || ! sudo -n true 2>/dev/null; then
        warn "Pakete fehlen und sudo nicht freigegeben: ${missing[*]}"
        warn "  von Hand nachinstallieren: sudo apt-get install -y ${missing[*]}"
        return 1
    fi
    info "installiere: ${missing[*]}"
    sudo apt-get update -qq || warn "apt-get update fehlgeschlagen (weiter trotzdem)"
    sudo apt-get install -y "${missing[@]}" || { warn "Installation fehlgeschlagen: ${missing[*]}"; return 1; }
    return 0
}

# Kommando → Paketname (die Pakete heißen anders als die Binaries)
need_cmds() {
    local missing=() pair cmd pkg
    for pair in "cmake:cmake" "make:make" "g++:g++" "git:git" "jq:jq" "curl:curl" "tar:tar"; do
        cmd="${pair%%:*}"; pkg="${pair##*:}"
        have "$cmd" || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        step "2 · Abhängigkeiten"
        apt_install "${missing[@]}" || true
    fi
    # Nur für die Tests nötig
    if ! have ncat && ! have nc; then
        step "2 · Abhängigkeiten"
        apt_install netcat-openbsd || true
    fi
    if ! have python3; then
        apt_install python3 || true
    fi
    if ! have shellcheck; then
        apt_install shellcheck || true
    fi
    if ! have tmux; then
        apt_install tmux || true
    fi
    return 0
}

# CUDA-Toolkit besorgen (nvcc) — nötig für den Quell-Build und für die
# Laufzeitbibliotheken libcudart/libcublas der fertigen Binaries.
ensure_cuda_toolkit() {
    step "2b · CUDA-Toolkit"
    if have nvcc; then
        ok "nvcc vorhanden: $(nvcc --version 2>/dev/null | grep -o 'release [0-9.]*' | head -1)"
        return 0
    fi
    if ! have nvidia-smi; then
        warn "kein nvcc und kein nvidia-smi — CUDA-Build nicht möglich"
        warn "  Treiber zuerst installieren, dann dieses Skript erneut ausführen"
        return 1
    fi
    warn "nvcc fehlt — CUDA-Toolkit wird installiert (ca. 3–4 GiB Download)"

    local ubUNTU_VER=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        ubUNTU_VER="$(echo "${VERSION_ID:-}" | tr -d '.')"
    fi
    if [ -z "$ubUNTU_VER" ]; then
        warn "Ubuntu-Version unbekannt — cuda-toolkit von Hand installieren"
        return 1
    fi
    local keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${ubUNTU_VER}/x86_64/cuda-keyring_1.1-1_all.deb"
    local keyring_deb="/tmp/cuda-keyring_1.1-1_all.deb"

    if [ "$DRY" = 1 ]; then
        info "[dry-run] curl -fL -o $keyring_deb $keyring_url"
        info "[dry-run] sudo dpkg -i $keyring_deb && sudo apt-get install -y cuda-toolkit-12-4"
        return 0
    fi
    if ! have sudo || ! sudo -n true 2>/dev/null; then
        warn "CUDA-Toolkit braucht sudo — von Hand: siehe NVIDIA CUDA-Installationsanleitung"
        return 1
    fi
    if curl -fsSL -o "$keyring_deb" "$keyring_url"; then
        sudo dpkg -i "$keyring_deb" && sudo apt-get update -qq || warn "NVIDIA-Repo konnte nicht eingerichtet werden"
    else
        warn "cuda-keyring nicht ladbar ($keyring_url)"
    fi
    if sudo apt-get install -y cuda-toolkit-12-4; then
        ok "cuda-toolkit-12-4 installiert"
    else
        warn "cuda-toolkit-12-4 fehlgeschlagen — versuche Paket des Distribution-Repositories"
        sudo apt-get install -y nvidia-cuda-toolkit || { warn "auch nvidia-cuda-toolkit fehlgeschlagen"; return 1; }
    fi
    have nvcc && ok "nvcc: $(nvcc --version 2>/dev/null | grep -o 'release [0-9.]*' | head -1)"
    return 0
}

# libcudart/libcublas in den ldconfig-Cache holen (sonst startet weder der
# Quell-Build noch das fertige Release).
ensure_cuda_libs() {
    if ldconfig -p 2>/dev/null | grep -q 'libcudart\.so\.12'; then
        ok "libcudart.so.12 im ldconfig-Cache"
        return 0
    fi
    local d
    d="$(find /usr/local -maxdepth 5 -name 'libcudart.so.12*' -printf '%h\n' 2>/dev/null | head -1)"
    [ -z "$d" ] && d="$(find /usr/lib -maxdepth 4 -name 'libcudart.so.12*' -printf '%h\n' 2>/dev/null | head -1)"
    if [ -z "$d" ]; then
        warn "libcudart.so.12 nicht gefunden — CUDA-Toolkit unvollständig?"
        return 1
    fi
    if [ "$DRY" = 1 ]; then
        info "[dry-run] sudo sh -c 'echo $d > /etc/ld.so.conf.d/00-cuda.conf' && sudo ldconfig"
        return 0
    fi
    if have sudo && sudo -n true 2>/dev/null; then
        printf '%s\n' "$d" | sudo tee /etc/ld.so.conf.d/00-cuda.conf >/dev/null && sudo ldconfig \
            && ok "ldconfig erweitert: $d" || warn "ldconfig-Eintrag fehlgeschlagen"
    else
        warn "libcudart unter $d, sudo nötig für ldconfig"
        warn "  von Hand: echo $d | sudo tee /etc/ld.so.conf.d/00-cuda.conf && sudo ldconfig"
    fi
    return 0
}

# ============================================================ 3 llama-Fork
llama_build() {
    step "3 · llama.cpp-Prism-Fork (CUDA)"
    local dir="$AI_ROOT/llama.cpp-prism"
    local bin="$dir/build/bin/llama-server"

    if [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1; then
        ok "bereits gebaut: $bin"
        ok "$("$bin" --version 2>&1 | head -1)"
        return 0
    fi

    if ask "llama-Fork klonen und mit CUDA bauen"; then
        mkdir -p "$AI_ROOT"
        if [ ! -d "$dir/.git" ]; then
            info "klone $LLAMA_REPO → $dir (Commit $(echo "$LLAMA_COMMIT" | cut -c1-9))"
            if [ "$DRY" = 1 ]; then
                info "[dry-run] git init + fetch --depth 1 origin $LLAMA_COMMIT"
            else
                mkdir -p "$dir"
                git -C "$dir" init -q 2>/dev/null || true
                git -C "$dir" remote add origin "$LLAMA_REPO" 2>/dev/null || \
                    git -C "$dir" remote set-url origin "$LLAMA_REPO"
                if git -C "$dir" fetch -q --depth 1 origin "$LLAMA_COMMIT" 2>/dev/null; then
                    git -C "$dir" checkout -q FETCH_HEAD
                    ok "Commit $(echo "$LLAMA_COMMIT" | cut -c1-9) ausgecheckt (Tiefen-Fetch)"
                else
                    warn "SHA-Fetch fehlgeschlagen — vollständiger Klon"
                    rm -rf "$dir"
                    git clone -q "$LLAMA_REPO" "$dir" || { err "Klon fehlgeschlagen"; return 1; }
                    git -C "$dir" checkout -q "$LLAMA_COMMIT" || { err "Checkout $LLAMA_COMMIT fehlgeschlagen"; return 1; }
                    ok "vollständiger Klon, Commit ausgecheckt"
                fi
            fi
        else
            info "Vorhanden: $dir"
        fi

        if have cmake && have nvcc; then
            info "configure: -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89-real (RTX 4060 = Ada)"
            if [ "$DRY" = 1 ]; then
                info "[dry-run] cmake -S $dir -B $dir/build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89-real -DGGML_NATIVE=OFF"
                info "[dry-run] cmake --build $dir/build -j\$(nproc)"
            else
                if cmake -S "$dir" -B "$dir/build" \
                        -DCMAKE_BUILD_TYPE=Release \
                        -DGGML_CUDA=ON \
                        -DCMAKE_CUDA_ARCHITECTURES=89-real \
                        -DGGML_NATIVE=OFF 2>&1 | tail -n 5; then
                    info "baue mit -j$(nproc) (dauert je nach Maschine 10–40 Minuten) …"
                    if cmake --build "$dir/build" -j"$(nproc)" >"$AI_ROOT/logs-llama-build.log" 2>&1; then
                        ok "Build fertig: $bin"
                    else
                        warn "Build fehlgeschlagen — Log: $AI_ROOT/logs-llama-build.log"
                        llama_fallback && return 0
                        return 1
                    fi
                else
                    warn "cmake-Konfiguration fehlgeschlagen"
                    llama_fallback && return 0
                    return 1
                fi
            fi
        else
            info "cmake/nvcc fehlt — fertiges CUDA-Release als Fallback"
            llama_fallback && return 0
            return 1
        fi
    else
        llama_fallback && return 0
        info "llama-Build übersprungen — `ai start` meldet dann einen fehlenden Pfad"
        return 0
    fi
    return 0
}

llama_fallback() {
    local dir="$AI_ROOT/llama.cpp-prism"
    local bin="$dir/build/bin/llama-server"
    [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1 && return 0

    local url="https://github.com/PrismML-Eng/llama.cpp/releases/download/${FALLBACK_CUDA_REL}/${FALLBACK_CUDA_ASSET}"
    if [ "$DRY" = 1 ]; then
        info "[dry-run] curl -fL -o /tmp/$FALLBACK_CUDA_ASSET $url"
        info "[dry-run] tar -xzf … -C $dir/build/bin --strip-components=1"
        return 0
    fi
    ask "fertiges CUDA-Release laden ($FALLBACK_CUDA_ASSET)" \
        || { info "Release-Fallback übersprungen (nicht interaktiv)"; return 1; }
    info "lade fertiges CUDA-Release: $FALLBACK_CUDA_ASSET"
    local tmp="/tmp/$FALLBACK_CUDA_ASSET"
    if ! curl -fsSL -o "$tmp" "$url"; then
        # Release-URL tot → aktuellsten Release suchen
        local api latest
        api="https://api.github.com/repos/PrismML-Eng/llama.cpp/releases/latest"
        latest="$(curl -fsSL "$api" 2>/dev/null | grep -o '"browser_download_url": *"[^"]*bin-linux-cuda-12\.4-x64\.tar\.gz"' \
                  | grep -o 'https[^"]*' | head -1)"
        if [ -n "$latest" ]; then
            info "aktuellere Release gefunden — lade sie"
            curl -fsSL -o "$tmp" "$latest" || { warn "Download fehlgeschlagen"; return 1; }
        else
            warn "kein CUDA-Release erreichbar"; return 1
        fi
    fi
    mkdir -p "$dir/build/bin"
    tar -xzf "$tmp" -C "$dir/build/bin" --strip-components=1 \
        || { warn "Entpacken fehlgeschlagen"; return 1; }
    rm -f "$tmp"
    [ -x "$bin" ] || { warn "llama-server nach Entpacken nicht ausführbar"; return 1; }
    ok "fertiges Release entpackt: $bin"

    # Pflicht-Flags prüfen — sonst passt die Startkonfiguration nicht
    local f
    for f in --kv-mean-center --ctx-checkpoints --cache-ram --reasoning-budget-message --spec-type; do
        if ! "$bin" --help 2>&1 | grep -q -- "$f"; then
            err "Release-Binary kennt $f nicht — Startkonfiguration wäre unvollständig"
            err "  von Hand aus Quellen bauen (cmake mit -DGGML_CUDA=ON)"
            return 1
        fi
    done
    ok "alle Pflicht-Flags vorhanden"
    return 0
}

# ============================================================ 4 Payload
copy_payload() {
    step "4 · Payload nach $AI_ROOT"
    if ask "Dateien aus payload/Ai nach $AI_ROOT/ kopieren"; then
        mkdir -p "$AI_ROOT"
        if have rsync; then
            run_cmd rsync -a "$PAYLOAD/" "$AI_ROOT/"
        else
            run_cmd cp -a "$PAYLOAD/." "$AI_ROOT/"
        fi
        [ "$DRY" = 1 ] || ok "kopiert: $(du -sh "$PAYLOAD" | cut -f1) → $AI_ROOT"
        # Anleitung und Übersicht auch offline verfügbar machen
        local d
        for d in README.md ANLEITUNG.md; do
            [ -f "$SCRIPT_DIR/$d" ] || continue
            if [ "$DRY" = 1 ]; then
                info "[dry-run] würde kopieren: $SCRIPT_DIR/$d → $AI_ROOT/doku/$d"
            else
                mkdir -p "$AI_ROOT/doku"
                cp -a "$SCRIPT_DIR/$d" "$AI_ROOT/doku/$d"
            fi
        done
        [ "$DRY" = 1 ] || ok "Doku unter $AI_ROOT/doku/ (README, ANLEITUNG)"
    fi
    if [ "$DRY" = 1 ]; then
        info "[dry-run] würde anlegen: $AI_ROOT/{logs,wiki/wiki,wiki/raw,wiki/errors}"
    else
        mkdir -p "$AI_ROOT/logs" "$AI_ROOT/wiki/wiki" "$AI_ROOT/wiki/raw" "$AI_ROOT/wiki/errors" 2>/dev/null || true
    fi
    [ "$DRY" = 1 ] || ok "Ordnerstruktur: $AI_ROOT/{lex,model,logs,wiki,llama.cpp-prism}"
    return 0
}

# ============================================================ 5 Aliase
anchors() {
    step "5 · Aliase und Symlink"
    if ask "Symlink $BIN_DIR/lex → $LEX_DIR/lex anlegen"; then
        mkdir -p "$BIN_DIR"
        run_cmd ln -sfn "$LEX_DIR/lex" "$BIN_DIR/lex"
        [ "$DRY" = 1 ] || ok "$BIN_DIR/lex → $LEX_DIR/lex"
        case ":$PATH:" in
            *":$BIN_DIR:"*) ok "$BIN_DIR liegt im PATH" ;;
            *) warn "$BIN_DIR fehlt im PATH — in ~/.bashrc eintragen: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
        esac
    fi

    if ask "Alias-Block in $BASHRC eintragen"; then
        if [ "$DRY" = 1 ]; then
            info "[dry-run] Marker-Block in $BASHRC: ai, lex, tlex, tlexkill"
        else
            [ -f "$BASHRC" ] || : > "$BASHRC"
            # alten Block entfernen (idempotent), dann neu anhängen
            if grep -qF '# >>> lex-nvidia-reinstall >>>' "$BASHRC" 2>/dev/null; then
                local tmpb
                tmpb="$(mktemp)"
                awk '/# >>> lex-nvidia-reinstall >>>/{skip=1} /# <<< lex-nvidia-reinstall <<</{skip=0; next} !skip' \
                    "$BASHRC" > "$tmpb" && mv "$tmpb" "$BASHRC"
                info "vorhandenen Marker-Block ersetzt"
            fi
            {
                printf '\n# >>> lex-nvidia-reinstall >>>\n'
                printf '# lex — LLM-Terminal-Agent (~/Ai/lex/lex), Details: ~/Ai/lex/README.md\n'
                printf "alias ai='bash ~/Ai/ai.sh'\n"
                printf "alias lex='~/Ai/lex/lex'\n"
                printf "alias tlex='tmux new -A -s lex'\n"
                printf "alias tlexkill='tmux kill-session -t lex'\n"
                printf '# <<< lex-nvidia-reinstall <<<\n'
            } >> "$BASHRC"
            ok "Aliase in $BASHRC: ai · lex · tlex · tlexkill"
            ok "aktiv nach: source ~/.bashrc"
        fi
    fi
    return 0
}

# ============================================================ 6 lex --install
lex_install() {
    step "6 · lex-Basisinstallation (~/.lex)"
    local lexbin="$LEX_DIR/lex"
    [ -f "$lexbin" ] || { warn "$lexbin fehlt — Schritt 4 prüfen"; return 1; }
    if ask "lex --install ausführen (legt ~/.lex/ an)"; then
        if [ "$DRY" = 1 ]; then
            info "[dry-run] bash $lexbin --install"
        else
            if bash "$lexbin" --install >/dev/null 2>&1 || bash "$lexbin" --install; then
                ok "$HOME/.lex/ angelegt (settings.json nur, falls noch nicht vorhanden)"
            else
                warn "lex --install meldete einen Fehler — ~/.lex/ evtl. unvollständig"
            fi
        fi
    fi
    return 0
}

# ============================================================ 7 Modell
find_model() {
    step "7 · Modell $MODEL_NAME"
    local hit=""
    local -a roots=("$AI_ROOT/model" "$HOME/models" "$HOME/model" "$HOME/Downloads" "$HOME/.cache/huggingface")
    local r
    for r in "${roots[@]}"; do
        [ -d "$r" ] || continue
        hit="$(find "$r" -maxdepth 6 -name "$MODEL_NAME" -size +5G -print -quit 2>/dev/null)"
        [ -n "$hit" ] && break
    done

    if [ -z "$hit" ] && [ "$INTERACTIVE" = 1 ] && [ "$DRY" = 0 ] && [ "$VERIFY_ONLY" = 0 ]; then
        printf 'Pfad zum Modell (Enter = später): '
        read -r answer || answer=""
        [ -n "$answer" ] && [ -f "$answer" ] && hit="$answer"
    fi

    if [ -n "$hit" ]; then
        ok "Modell gefunden: $hit ($(du -h "$hit" 2>/dev/null | cut -f1))"
        # Ziel: ~/Ai/model/$MODEL_NAME — dorthin verlinken, falls es woanders liegt
        if [ "$(readlink -f "$hit")" != "$(readlink -f "$AI_ROOT/model/$MODEL_NAME" 2>/dev/null)" ]; then
            mkdir -p "$AI_ROOT/model" 2>/dev/null || true
            if ask "nach $AI_ROOT/model/$MODEL_NAME verlinken"; then
                run_cmd ln -sfn "$hit" "$AI_ROOT/model/$MODEL_NAME"
                [ "$DRY" = 1 ] || ok "Symlink gesetzt"
            fi
        fi
        set_model_setting "$AI_ROOT/model/$MODEL_NAME"
    else
        warn "Modell nicht gefunden — bitte selbst herunterladen:"
        warn "  $MODEL_NAME (6,71 GiB) nach $AI_ROOT/model/ legen"
        warn "  danach: ./install.sh --verify   bzw.   ai start"
        warn "  (kein Download durch dieses Skript)"
    fi
    return 0
}

set_model_setting() {
    local path="$1"
    local settings="$HOME/.lex/settings.json"
    [ -f "$settings" ] || return 0
    if ask "settings.json: model → $path"; then
        if [ "$DRY" = 1 ]; then
            info "[dry-run] jq '.model = \"$path\"' $settings"
        elif have jq; then
            local tmp
            tmp="$(mktemp)"
            if jq --arg m "$path" '.model = $m' "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
                mv "$tmp" "$settings" && ok "settings.json aktualisiert (model)"
            else
                rm -f "$tmp"
                warn "settings.json konnte nicht aktualisiert werden"
            fi
        else
            warn "jq fehlt — settings.json von Hand anpassen (Feld: model)"
        fi
    fi
    return 0
}

# ============================================================ 8 Verifikation
verify() {
    step "8 · Verifikation"
    local fail=0

    # a) keine fremden Home-Pfade
    local hits
    hits="$(grep -rIlE '/home/[[:alnum:]_.-]+' "$AI_ROOT/lex" "$AI_ROOT/ai.sh" 2>/dev/null | wc -l)"
    if [ "${hits:-0}" -eq 0 ]; then
        ok "kein fremder Home-Pfad in lex/ und ai.sh"
    else
        err "absolute Home-Pfade in $hits Dateien:"; grep -rIlE '/home/[[:alnum:]_.-]+' "$AI_ROOT/lex" "$AI_ROOT/ai.sh" 2>/dev/null | sed 's/^/    /'
        fail=1
    fi

    # b) Syntax
    local syn=0 f
    for f in "$AI_ROOT/lex/lex" "$AI_ROOT/ai.sh" "$SCRIPT_DIR/install.sh" "$AI_ROOT"/lex/test/*.sh "$AI_ROOT"/lex/tools/*.sh; do
        [ -f "$f" ] || continue
        bash -n "$f" 2>/dev/null || { err "Syntaxfehler: $f"; syn=1; fail=1; }
    done
    [ "$syn" = 0 ] && ok "bash -n über lex, ai.sh, install.sh, test/, tools/"

    # c) sha256 gegen Manifest
    if [ -f "$MANIFEST" ]; then
        if (cd "$AI_ROOT" && sha256sum -c --quiet "$MANIFEST" >/dev/null 2>&1); then
            ok "sha256-Manifest: $(wc -l < "$MANIFEST") Dateien unverändert"
        else
            local bad
            bad="$(cd "$AI_ROOT" && sha256sum -c "$MANIFEST" 2>/dev/null | grep -c FAILED || true)"
            warn "sha256: $bad Dateien abweichend (evtl. nachträglich bearbeitet)"
        fi
    else
        info "kein Manifest — sha256-Prüfung übersprungen"
    fi

    # d) Testlauf (ohne Server, ohne Modell, ohne Werkstatt)
    if [ -f "$AI_ROOT/lex/test/run_all.sh" ]; then
        if [ "$VERIFY_ONLY" = 1 ] || ask "Testsuite starten (LEX_MOCK, 19 Läufer)"; then
            info "starte run_all.sh — das dauert eine Weile …"
            if [ "$DRY" = 1 ]; then
                info "[dry-run] LEX_MOCK=done bash $AI_ROOT/lex/test/run_all.sh"
            else
                local tlog="/tmp/lex-nvidia-run_all.log"
                if LEX_MOCK='done' timeout 1200 bash "$AI_ROOT/lex/test/run_all.sh" > "$tlog" 2>&1; then
                    ok "Testsuite: $(grep -Eo 'PASS: *[0-9]+ *FAIL: *[0-9]+' "$tlog" | tail -1)"
                else
                    err "Testsuite fehlgeschlagen — Log: $tlog"
                    tail -n 20 "$tlog" | sed 's/^/    /'
                    fail=1
                fi
            fi
        fi
    fi

    # e) llama-Binary vorhanden?
    local lbin="$AI_ROOT/llama.cpp-prism/build/bin/llama-server"
    if [ -x "$lbin" ] && "$lbin" --version >/dev/null 2>&1; then
        ok "llama-server: $("$lbin" --version 2>&1 | head -1)"
    else
        warn "llama-server fehlt oder startet nicht — Schritt 3 wiederholen"
        fail=1
    fi

    # f) Modell
    if [ -f "$AI_ROOT/model/$MODEL_NAME" ]; then
        ok "Modell vorhanden: $AI_ROOT/model/$MODEL_NAME"
    else
        warn "Modell fehlt: $AI_ROOT/model/$MODEL_NAME (Selbstherunterladen, siehe Schritt 7)"
    fi

    [ "$fail" = 0 ] && ok "Verifikation bestanden" || err "Verifikation mit Befunden"
    return "$fail"
}

# ============================================================ 9 Report
report() {
    step "9 · Fertig"
    cat <<EOF
  Verzeichnisstruktur (wie auf der Original-Maschine):
    $AI_ROOT/lex/            lex-Skript, test/ (19 Läufer), tools/
    $AI_ROOT/ai.sh           llama-server-Startskript (NVIDIA)
    $AI_ROOT/model/          chat_template, kv-mean-center, KNOWN_ISSUES
    $AI_ROOT/wiki/           leeres Wissens-Skelett (wächst selbst)
    $AI_ROOT/llama.cpp-prism/  Prism-Fork, CUDA-build (sm_89)
    ~/.local/bin/lex         Symlink
    ~/.lex/                  Einstellungen + Sessions

  Nächste Schritte:
    source ~/.bashrc          # Aliase aktivieren
    ai start                  # llama-server (Modus-Menü: Standard/Split)
    ai status                 # inkl. VRAM-Anzeige
    lex                       # der Terminal-Agent
    bash ~/Ai/lex/test/run_all.sh   # Testsuite jederzeit prüfbar

  Wichtig: das Modell $MODEL_NAME
  wird NICHT mitgeliefert — es muss in $AI_ROOT/model/ liegen.
EOF
    if [ "${#WARNINGS[@]}" -gt 0 ]; then
        printf '\n  Warnungen (%d):\n' "${#WARNINGS[@]}"
        printf '    - %s\n' "${WARNINGS[@]}"
    fi
    printf '\n'
}

# ============================================================ Ablauf
main() {
    printf 'Lex-Bash-Agent-Nvidia — Installation%s\n' \
        "$([ "$DRY" = 1 ] && echo ' (TROCKENLAUF — nichts wird verändert)')"
    [ "$VERIFY_ONLY" = 1 ] && printf '(nur Verifikation)\n'

    if [ "$VERIFY_ONLY" = 1 ]; then
        precheck
        verify
        exit $?
    fi

    precheck
    [ -d "$PAYLOAD/lex" ] || { err "Payload fehlt — Abbruch"; exit 1; }
    need_cmds
    if have nvcc || command -v nvidia-smi >/dev/null 2>&1; then
        ensure_cuda_toolkit || warn "CUDA-Toolkit fehlt — Quell-Build wird auf Fallback umstellen"
        ensure_cuda_libs || true
    fi
    llama_build
    copy_payload
    anchors
    lex_install
    find_model
    verify || true
    report
}

main
