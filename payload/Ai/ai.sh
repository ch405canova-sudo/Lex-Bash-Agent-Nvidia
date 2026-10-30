#!/bin/bash
# ai.sh — llama-server-Startskript für lex (NVIDIA-Fassung)
# Einstellungen 1:1 wie die Original-Fassung: CTX 262144, Modus-Menü (Standard/Split),
# identische Sampler-, KV- und Reasoning-Flags. Geändert sind nur:
#   1. alle Pfade auto-abgeleitet aus dem Skriptpfad (kein absoluter Home-Pfad),
#   2. Postgres/Docker/asn entfallen (gehören nicht zur Auslieferung),
#   3. vor dem Start ein GPU-Check per nvidia-smi (nur Meldung, nie stille Umstellung).
#
# Start:  ai start [1|standard|2|split]   Stopp: ai stop   Status: ai status
# Env:    CTX, LLAMA_UB, LLAMA_LV, MODEL_PATH, LLAMA_BIN, AI_PORT — siehe unten
AI_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

HOST="${AI_HOST:-127.0.0.1}"
LLAMA_PORT="${AI_PORT:-8080}"
MODEL="Ternary-Bonsai-2-27B-PQ2_0.gguf"
MODEL_PATH="${MODEL_PATH:-$AI_DIR/model/$MODEL}"
CTX="${CTX:-262144}"      # Gesamt-Kontext; pro Slot = CTX / Slots (Split: 2 x 131072)
LLAMA_BIN="${LLAMA_BIN:-$AI_DIR/llama.cpp-prism/build/bin/llama-server}"
PIDFILE="${PIDFILE:-$AI_DIR/ai.pid}"
LOGDIR="${LOGDIR:-$AI_DIR/logs}"
mkdir -p "$LOGDIR"
WIKI_DIR="${WIKI_DIR:-$AI_DIR/wiki}"
CHAT_TEMPLATE="${CHAT_TEMPLATE:-$AI_DIR/model/chat_template.jinja}"
KV_MEAN_CENTER="${KV_MEAN_CENTER:-$AI_DIR/model/kv-mean-center-bonsai.gguf}"
# VRAM-Warnschwelle in MiB: darunter starten wir trotzdem, warnen aber laut.
VRAM_WARN_MIB="${VRAM_WARN_MIB:-4000}"

check_llama() { ss -tlnp 2>/dev/null | grep -q ":$LLAMA_PORT"; }

# --- Startmodus: 1 = Standard (262k, 1 Slot), 2 = Split (2 x 128k) -------
AI_MODE=1   # Auswahl des Menues (1|2), fuer start_llama
R_NP=""     # Slots des laufenden Servers
R_CTX=""    # Gesamt-Kontext des laufenden Servers

_mode_label() {
    local np="${1:-1}" ctx="${2:-$CTX}"
    if [ "$np" -gt 1 ]; then
        printf 'Split — %d Slots × %d ctx, getrennter KV-Cache je Slot, parallele Anfragen' \
            "$np" "$((ctx / np))"
    else
        printf 'Standard — %d ctx, 1 Slot (ein Client mit vollem Kontext)' "$ctx"
    fi
}

# Laufenden Modus aus /proc/<pid>/cmdline lesen (kein HTTP).
# Setzt R_NP/R_CTX; Rueckgabe 1, wenn kein Server laeuft.
_running_np() {
    R_NP=""
    R_CTX=""
    local pid i
    local -a args
    pid=$(pgrep -x -o llama-server 2>/dev/null) || return 1
    [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] || return 1
    mapfile -d '' -t args < "/proc/$pid/cmdline" || return 1
    R_NP=1
    R_CTX=$CTX
    for ((i = 0; i < ${#args[@]}; i++)); do
        case "${args[i]}" in
            -np|--parallel) R_NP="${args[i + 1]:-1}" ;;
            -c|--ctx-size)  R_CTX="${args[i + 1]:-$CTX}" ;;
        esac
    done
    return 0
}

_menu_cursor_off() { printf '\033[?25l'; }
_menu_cursor_on()  { printf '\033[?25h'; }

# 3-Zeilen-Block; $1 = 1 beim ersten Aufruf (danach 3 Zeilen rueckwaerts)
_menu_paint() {
    local m1=' ' m2=' '
    [ "$AI_MODE" = 1 ] && m1='>' || m2='>'
    [ "${1:-0}" = 1 ] || printf '\033[3A'
    printf '\r\033[2KStartmodus wählen  (↑↓, Enter, 1/2, Esc)\n'
    printf '\r\033[2K%s 1  Standard   %d ctx, 1 Slot\n' "$m1" "$CTX"
    printf '\r\033[2K%s 2  Split      2 × %d (128k), getrennt, parallel\n' "$m2" "$((CTX / 2))"
}

# Auswahl per Cursor-Tasten. Ergebnis in AI_MODE; Rueckgabe 1 = abgebrochen.
_pick_mode() {
    AI_MODE=1
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        printf '  (nicht interaktiv → Modus 1: %s)\n' "$(_mode_label 1)"
        return 0
    fi
    local key rest
    _menu_cursor_off
    trap '_menu_cursor_on; trap - INT TERM; exit 130' INT TERM
    _menu_paint 1
    while true; do
        key=""
        if ! IFS= read -rsn1 key; then
            break
        fi
        if [ "$key" = $'\e' ]; then
            rest=""
            if IFS= read -rsn2 -t 0.2 rest 2>/dev/null; then
                key="$key$rest"
            fi
        fi
        case "$key" in
            $'\e[A'|$'\e[B') AI_MODE=$((3 - AI_MODE)); _menu_paint ;;
            1|2)             AI_MODE=$key; _menu_paint; break ;;
            ''|$'\r')        break ;;
            $'\e'|q|Q)
                _menu_cursor_on
                trap - INT TERM
                printf '  Abgebrochen.\n'
                return 1
                ;;
        esac
    done
    _menu_cursor_on
    trap - INT TERM
    printf '  → %s\n' "$(_mode_label "$AI_MODE")"
    return 0
}

# GPU-Sichtprüfung VOR dem Start. Nur Meldungen — es wird NIE still umgestellt.
_gpu_check() {
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo "⚠ nvidia-smi nicht gefunden — NVIDIA-Treiber prüfen."
        echo "  (llama-server startet trotzdem; ohne Treiber scheitert das Laden der CUDA-Bibliotheken.)"
        return 0
    fi
    local line name total free
    line="$(nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null | head -1)"
    if [ -z "$line" ]; then
        echo "⚠ nvidia-smi liefert keine Daten — Treiber und GPU prüfen."
        return 0
    fi
    name="$(echo "$line" | cut -d, -f1 | sed 's/^ *//;s/ *$//')"
    total="$(echo "$line" | cut -d, -f2 | tr -d ' ')"
    free="$(echo "$line" | cut -d, -f3 | tr -d ' ')"
    echo "GPU:          $name · VRAM frei: ${free:-?} von ${total:-?} MiB"
    if [ -n "$free" ] && [ "$free" -lt "$VRAM_WARN_MIB" ] 2>/dev/null; then
        echo "⚠ wenig VRAM frei (${free} MiB) — der Start kann mit ${CTX:-262144} ctx scheitern."
        echo "  Hinweis (Werte werden hier NICHT geändert):"
        echo "    ai stop && CTX=131072 ai start"
        echo "    oder im Menü Modus 1 (1 Slot) wählen;"
        echo "    Einzelplatz-Empfehlung aus KNOWN_ISSUES #183: -np 1 --cache-ram 24576"
    fi
    return 0
}

start_llama() {
    local np="${1:-1}"
    if check_llama; then
        echo "✓ llama-server läuft bereits (Port $LLAMA_PORT)"
        if _running_np; then
            echo "  Aktiv: $(_mode_label "$R_NP" "$R_CTX")"
            [ "$R_NP" != "$np" ] && echo "  Modus wechseln: ai stop, dann ai start"
        fi
        return 0
    fi
    if [ ! -x "$LLAMA_BIN" ]; then
        echo "✗ llama-server nicht gefunden: $LLAMA_BIN"
        echo "  (erst installieren: ./install.sh — baut den llama.cpp-Prism-Fork)"
        return 1
    fi
    if [ ! -f "$MODEL_PATH" ]; then
        echo "✗ Modell nicht gefunden: $MODEL_PATH"
        echo "  Erwartet: $MODEL (6,71 GiB) — von Hand herunterladen, dann"
        echo "  MODEL_PATH=/pfad/zur/datei ai start"
        return 1
    fi
    _gpu_check

    echo "Starte llama-server (Port $LLAMA_PORT) — $(_mode_label "$np")"
    "$LLAMA_BIN" -m "$MODEL_PATH" \
    -ngl 99 \
    -fa on \
    -c "$CTX" \
    -np "$np" \
    -b 2048 \
    -ub "${LLAMA_UB:-1024}" \
    -ctk q4_0 \
    -ctv q4_0 \
    --chat-template-file "$CHAT_TEMPLATE" \
    --ctx-checkpoints 32 \
    --cache-ram 8192 \
    --cache-idle-slots \
    --spec-type ngram-mod \
    --spec-ngram-mod-n-match 24 \
    --spec-ngram-mod-n-min 48 \
    --spec-ngram-mod-n-max 64 \
    --temp 1.0 \
    --top-p 0.95 \
    --top-k 20 \
    --min-p 0.05 \
    --predict 8192 \
    --kv-mean-center "$KV_MEAN_CENTER" \
    --repeat-penalty 1.0 \
    --presence-penalty 0.0 \
    --reasoning on \
    --reasoning-effort medium \
    --reasoning-budget 4096 \
    --reasoning-budget-message "Budget erreicht - jetzt die beste Antwort geben, nicht zögern oder zweifeln." \
    --reasoning-preserve \
    --jinja \
    -lv "${LLAMA_LV:-3}" \
    --metrics \
    --host "$HOST" \
    --port $LLAMA_PORT > "$LOGDIR/llama.log" 2>&1 &
    local llama_pid=$!

    for _ in {1..30}; do
        if check_llama; then
            echo "✓ llama-server läuft (PID $llama_pid, $np Slot)"
            return 0
        fi
        kill -0 "$llama_pid" 2>/dev/null || break
        sleep 1
    done

    echo "✗ llama-server konnte nicht auf Port $LLAMA_PORT starten"
    echo "  Log: $LOGDIR/llama.log (letzte Zeilen:)"
    tail -n 8 "$LOGDIR/llama.log" 2>/dev/null | sed 's/^/    /'
    return 1
}

stop_all() {
    echo "Stoppe alles..."
    for p in $(pgrep -f "llama-server" 2>/dev/null); do kill -9 $p 2>/dev/null; done
    sleep 1
    rm -f "$PIDFILE"
    echo "✓ llama-server gestoppt"
}

status() {
    echo "=== System-Status ==="
    if check_llama; then
        echo "llama-server: ✓ läuft (Port $LLAMA_PORT)"
        if _running_np; then
            echo "Startmodus:   $(_mode_label "$R_NP" "$R_CTX")"
        fi
    else
        echo "llama-server: ✗ nicht gestartet"
    fi
    echo "Binär:        $LLAMA_BIN"
    if [ -f "$MODEL_PATH" ]; then
        echo "Modell:       $MODEL_PATH ($(du -h "$MODEL_PATH" 2>/dev/null | cut -f1))"
    else
        echo "Modell:       ✗ nicht gefunden — $MODEL_PATH"
    fi
    echo "Kontext:      $CTX (Env CTX überschreibbar)"
    echo "Log:          $LOGDIR/llama.log"
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null \
            | head -1 | sed 's/^\(.*\),\([0-9]*\),\([0-9]*\)$/GPU:          \1 · VRAM frei: \3 von \2 MiB/'
    else
        echo "GPU:          ✗ nvidia-smi nicht gefunden (Treiber?)"
    fi
    echo "Wiki:         $(find $WIKI_DIR/wiki -name '*.md' -type f 2>/dev/null | wc -l) Seiten"
}

start() {
    echo "============================================"
    echo "  Lex-2-27B Server Manager (NVIDIA)"
    echo "  llama-server"
    echo "============================================"
    AI_MODE=1
    case "${2:-}" in
        '')            _pick_mode || return 1 ;;
        1|standard|full) AI_MODE=1 ;;
        2|split|128k)    AI_MODE=2 ;;
        *)
            echo "✗ Unbekannter Modus: $2"
            echo "  Benutzung: ai start [1|standard|2|split]"
            return 1
            ;;
    esac
    start_llama "$AI_MODE" || return 1
    echo ""
    echo "Endpoint: http://$HOST:$LLAMA_PORT"
    echo "Stop:     ai stop"
}

stop() { stop_all; }

chat() {
    echo "============================================"
    echo "  Lex-2-27B — Server Info"
    echo "============================================"
    if ! check_llama; then echo "⚠ llama-server nicht aktiv! Erst: ai start"; return 1; fi
    echo "✓ llama-server läuft: http://$HOST:$LLAMA_PORT (OpenAI-kompatibel)"
    echo ""
    echo "Test: curl http://$HOST:$LLAMA_PORT/v1/models"
}

case "${1:-}" in
    start)   start "$@" ;;
    stop)    stop_all ;;
    restart) bash "$0" stop; sleep 2; bash "$0" start ;;
    status)  status ;;
    chat)    chat ;;
    wiki)    echo "Wiki: $WIKI_DIR"; find "$WIKI_DIR" -type f -name '*.md' | sort ;;
    *) start "$@" && chat ;;
esac
