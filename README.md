# Lex — Bash-Terminal-Agent für NVIDIA-GPUs

**Lex** ist ein Terminal-Agent für die Kommandozeile: Du gibst eine Aufgabe in
deutschsprachigem Klartext ein, lex recherchiert, prüft und arbeitet sie mit
echten Werkzeugen ab (Dateien, Shell, Web, Browser, Wiki). Er läuft lokal gegen
einen lokalen **llama-server** (PrismML-Fork von llama.cpp) mit dem Modell
**Ternary-Bonsai-2-27B (q4_0, 262k Kontext)**.

Das Besondere: der ganze Agent ist **eine einzige Bash-Datei** (~5100 Zeilen,
ohne Fremd-Werkzeuge, ohne Python-Laufzeitumgebung) — man kann ihn komplett
lesen und nachvollziehen. Er arbeitet deutschsprachig, schreibt sein Wissen in
ein Wiki unter `~/Ai/wiki/` und merkt sich Präferenzen in `~/.lex/mem/`.

Diese Auslieferung ist **ausschließlich deutschsprachig**, vollständig
dokumentiert und enthält **keine privaten Daten** und **keine Modellgewichte**.

## Was in diesem Repo liegt

| Datei/Ordner | Inhalt |
|---|---|
| `install.sh` | komplette Einrichtung (Abhängigkeiten, CUDA-Build, `~/Ai/`, Aliase, Tests) |
| `ANLEITUNG.md` | **detaillierte Schritt-für-Schritt-Anleitung**: Einrichtung und Nutzung |
| `README.md` | diese Übersicht |
| `manifest/sha256-payload.txt` | Summenprüfung aller gelieferten Dateien |
| `payload/Ai/lex/` | der Agent (`lex`), `test/` (19 Läufer), `tools/`, `LEX.md`, `CHANGELOG.md` |
| `payload/Ai/ai.sh` | llama-server-Startskript (Modus-Menü, GPU-Anzeige) |
| `payload/Ai/model/` | Chat-Vorlage, KV-Mittelwert-Datei, `KNOWN_ISSUES.md` |
| `payload/Ai/wiki/` | leeres Wissens-Skelett (dein Wiki wächst selbst) |

Nicht enthalten, bewusst: das Modell (6,71 GiB), `.git`-Historie, persönliche
Einstellungen, fertiges Wissen, Logs.

## Voraussetzungen

- **Debian oder Ubuntu**, 64-Bit (getestet: Ubuntu 24.04 und 26.04)
- **NVIDIA-Grafikkarte mit Treiber** (`nvidia-smi` muss antworten) —
  getestet mit **RTX 4060, 16 GiB VRAM**
- ca. **10 GiB** freier Plattenplatz, dazu **6,71 GiB** für das Modell
- **Bash 4 oder neuer**, `git` (optional, sonst Tarball)

## Schnellstart

```bash
# 1. Repo holen
git clone https://github.com/ch405canova-sudo/Lex-Bash-Agent-Nvidia.git
cd Lex-Bash-Agent-Nvidia

# 2. vorher anschauen (verändert nichts)
./install.sh --dry-run

# 3. einrichten (fragt ggf. sudo für Pakete und CUDA ab)
./install.sh

# 4. Modell manuell laden — Datei nach ~/Ai/model/ legen:
#    Ternary-Bonsai-2-27B-PQ2_0.gguf   (6,71 GiB, Hugging Face)

# 5. Aliase aktivieren und loslegen
source ~/.bashrc
ai start          # llama-server starten (zeigt VRAM, Modus-Menü)
lex               # der Agent
```

**Der Punkt 4 ist der einzige manuelle Schritt:** das Modell wird nicht
heruntergeladen — bitte selbst von Hugging Face holen (Dateiname suchen).

Alle Einzelheiten — was der Installer wann tut, wie man den Server im
Split-Modus betreibt, wie die Werkzeuge funktionieren, wie man das Wiki
aufbaut — stehen in der **[ANLEITUNG.md](ANLEITUNG.md)**.

## Prüfen, dass alles stimmt

```bash
./install.sh --verify        # Pfade, Syntax, Summen, Testsuite
LEX_MOCK=done bash ~/Ai/lex/test/run_all.sh   # 19 Läufer, ohne Server, ohne GPU
```

Erwartet: **19 von 19 Läufern grün**. Die Tests laufen vollständig simuliert
(es geht kein einziger Request an den Server).

## Struktur nach der Einrichtung

```
~/Ai/
├── lex/
│   ├── lex                # der Agent (eine Bash-Datei)
│   ├── test/run_all.sh    # Testsuite (19 Läufer)
│   ├── tools/             # Helfer-Skripte (Proxy, Selbstcheck, Werkstatt-Index)
│   ├── LEX.md             # Bauweise, Ist-Stand, Regeln (Basisdoku)
│   └── CHANGELOG.md       # Änderungsverlauf
├── ai.sh                  # Server-Manager
├── model/                 # Vorlagen + KNOWN_ISSUES (+ dein Modell)
├── wiki/                  # dein Gedächtnis (wächst mit der Nutzung)
├── logs/                  # llama.log
└── llama.cpp-prism/       # gebauter Server (sm_89)
~/.lex/                    # Einstellungen, Sitzungen, Erinnerungen, Pläne
~/.local/bin/lex           # Verweis auf ~/Ai/lex/lex
```

## Nützlichste Befehle

```bash
ai start | ai status | ai stop     # Server steuern (mit VRAM-Anzeige)
lex                                # Agent starten (REPL)
lex --status                       # Konfiguration und Laufzeit prüfen
lex --oneshot                      # eine Aufgabe aus Stdin, für Skripte
```

In der REPL: `/help` zeigt alles, `/exit` beendet, `/compact` räumt den
Kontext zusammen, `/server` zeigt den Serverzustand.

## Häufige Probleme

| Symptom | Abhilfe |
|---|---|
| `llama-server nicht gefunden` | `./install.sh --verify` — Schritt 3 wiederholen |
| Startabbruch mit CUDA-Meldung | `libcudart.so.12` im ldconfig-Cache: Installer erledigt es; sonst Pfad eintragen und `sudo ldconfig` |
| `nvidia-smi nicht gefunden` | NVIDIA-Treiber installieren, dann neu einloggen |
| Port 8080 belegt | `ai status` — oder `AI_PORT=8081 ai start` |
| Speicher reicht nicht | `CTX=131072 ai start` (siehe ANLEITUNG, Kapitel VRAM) |
| Testsuite rot | betroffene Datei lesen, `bash -n ~/Ai/lex/lex` als Schnellcheck |

## Über diese Auslieferung

Die Doku ist bewusst auf Deutsch, der Agent antwortet standardmäßig auf
Deutsch. Private Pfade, Sitzungsverläufe, Wissens-Inhalte und die Historie der
Entwicklung sind **nicht** enthalten — was Sie lesen, ist der Stand der
Software, nicht die Geschichte ihrer Entstehung. Der Betriebslog der
Entwicklung liegt in einer privaten Kopie und wird hier nicht gezeigt.
