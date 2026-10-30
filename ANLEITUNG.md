# ANLEITUNG — Lex einrichten und benutzen

Diese Anleitung führt Sie Schritt für Schritt von einem leeren Rechner bis zum
laufenden Agenten — und danach durch die tägliche Nutzung. Jeder Schritt nennt
den Befehl, was er tut und woran Sie erkennen, dass er geklappt hat.

**Inhalt**

- [Teil 1 — Einrichtung](#teil-1--einrichtung)
  - [Schritt 0: Voraussetzungen prüfen](#schritt-0--voraussetzungen-prüfen)
  - [Schritt 1: Dateien besorgen](#schritt-1--dateien-besorgen)
  - [Schritt 2: Trockenlauf ansehen](#schritt-2--trockenlauf-ansehen)
  - [Schritt 3: Installation starten](#schritt-3--installation-starten)
  - [Schritt 4: Modell laden](#schritt-4--modell-laden)
  - [Schritt 5: Aliase aktivieren, Erstkontrolle](#schritt-5--aliase-aktivieren-erstkontrolle)
  - [Schritt 6: llama-server starten](#schritt-6--llama-server-starten)
  - [Schritt 7: Erster Kontakt mit lex](#schritt-7--erster-kontakt-mit-lex)
  - [Schritt 8: Alles verifizieren](#schritt-8--alles-verifizieren)
- [Teil 2 — Lex benutzen](#teil-2--lex-benutzen)
  - [Die Eingabezeile (REPL)](#die-eingabezeile-repl)
  - [Alle Slash-Befehle](#alle-slash-befehle)
  - [Die 19 Werkzeuge](#die-19-werkzeuge)
  - [Ablauf einer typischen Aufgabe](#ablauf-einer-typischen-aufgabe)
  - [Pläne und Aufgabenlisten](#pläne-und-aufgabenlisten)
  - [Gedächtnis: Wiki und Erinnerungen](#gedächtnis-wiki-und-erinnerungen)
  - [Kontext steuern](#kontext-steuern)
  - [Sicherheit: was lex nicht darf](#sicherheit-was-lex-nicht-darf)
  - [sudo richtig benutzen](#sudo-richtig-benutzen)
  - [Konfiguration einstellen](#konfiguration-einstellen)
  - [lex ohne REPL (für Skripte)](#lex-ohne-repl-für-skripte)
  - [Diagnose und Auswertung](#diagnose-und-auswertung)
- [Teil 3 — Wartung und Feinabstimmung](#teil-3--wartung-und-feinabstimmung)
  - [VRAM und Kontext (RTX 4060)](#vram-und-kontext-rtx-4060)
  - [Server betreiben](#server-betreiben)
  - [Änderungen selbst vornehmen](#änderungen-selbst-vornehmen)
  - [Häufige Situationen](#häufige-situationen)

---

# Teil 1 — Einrichtung

## Schritt 0: Voraussetzungen prüfen

**Distribution.** Debian oder Ubuntu, 64-Bit. Prüfen mit:

```bash
cat /etc/os-release
uname -m
```

Erwartet: `PRETTY_NAME="Ubuntu …"` und `x86_64`.

**NVIDIA-Treiber.** Das ist der wichtigste Punkt — ohne Treiber läuft der
Server nicht:

```bash
nvidia-smi
```

Erwartet: eine Tabelle mit Grafikkarte, Treiberversion und Speicher. Bei mir
zum Beispiel „NVIDIA GeForce RTX 4060" mit 16376 MiB. Kommt `Kommando nicht
gefunden` oder ein CUDA-Fehler: erst den Treiber nachinstallieren (Ubuntu:
„Anwendungen → Treiber & Software → NVIDIA-Grafiktreiber für Compute-Modus"),
danach **ab- und wieder anmelden**. Das Tool braucht das später auch für die
VRAM-Anzeige.

**Platz.** Etwa 10 GiB für Quellcode, Build und Dateien; zusätzlich 6,71 GiB
für das Modell:

```bash
df -h ~
```

**Bash.** Version 4 oder neuer:

```bash
bash --version | head -1
```

## Schritt 1: Dateien besorgen

**Variante A — mit git:**

```bash
git clone https://github.com/ch405canova-sudo/Lex-Bash-Agent-Nvidia.git
cd Lex-Bash-Agent-Nvidia
```

**Variante B — ohne git:** das Archiv von der Repo-Seite herunterladen
(„Code → ZIP herunterladen"), entpacken, hineinwechseln:

```bash
cd Lex-Bash-Agent-Nvidia
```

Im Verzeichnis müssen mindestens liegen: `install.sh`, `payload/`, `manifest/`,
`README.md`, `ANLEITUNG.md`.

## Schritt 2: Trockenlauf ansehen

Bevor irgendetwas verändert wird, zeigt der Installer, was er vorhat:

```bash
./install.sh --dry-run
```

Erwartet: eine neunteilige Ausgabe, in der jede Zeile mit `[dry-run]` beginnt —
also „würde kopieren", „würde bauen", „würde Aliase eintragen". Es wird
**nichts** geschrieben (geprüft: bei leerem Zielverzeichnis bleiben 0 Dateien
zurück).

Nebenbei prüft der Trockenlauf auch schon die Voraussetzungen und meldet
Warnungen, zum Beispiel fehlenden Treiber oder belegten Port.

## Schritt 3: Installation starten

```bash
./install.sh
```

Das Skript arbeitet neun Schritte ab. Hier steht, was jeweils passiert und was
Sie eingeben müssen:

| Schritt | Aktion | Ihre Eingabe |
|---|---|---|
| 1 · Precheck | Distribution, Architektur, Treiber, Port, Platz prüfen | keine |
| 2 · Abhängigkeiten | `cmake`, `g++`, `jq`, `curl`, `tar` — fehlt etwas, wird es per `sudo apt-get` installiert | ggf. sudo-Passwort |
| 2b · CUDA-Toolkit | ohne `nvcc` kein Quell-Build; das NVIDIA-Repo wird eingerichtet, `cuda-toolkit-12-4` installiert | ggf. sudo-Passwort |
| 3 · llama-Fork | Klon des PrismML-Forks (fester Stand), Configure mit `-DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89-real`, Build | keine (dauert 10–40 Minuten) |
| 4 · Payload | `payload/Ai/` wird nach `~/Ai/` kopiert | keine |
| 5 · Aliase | Verweis `~/.local/bin/lex`, Block in `~/.bashrc` (`ai`, `lex`, `tlex`, `tlexkill`) | keine |
| 6 · Basisinstallation | `lex --install` legt `~/.lex/` mit `settings.json` an | keine |
| 7 · Modell suchen | sucht die Modell-Datei auf der Platte; liegt sie woanders, verlinkt er sie | ggf. Pfad nennen |
| 8 · Verifikation | Pfade, Syntax, Summen, Testsuite | keine |
| 9 · Bericht | Zusammenfassung und nächste Schritte | keine |

**Wenn der Build scheitert** (z. B. kein `nvcc`): der Installer lädt automatisch
ein fertiges CUDA-Release desselben Projekts und prüft, ob es die nötigen
Startoptionen kennt. Schlägt auch das fehl, beendet er die Schritte mit einem
Hinweis — `ai start` meldet dann den fehlenden Pfad.

**Abbrechen und später weitermachen** ist unkritisch: der Installer ist
wiederholbar (bereits Vorhandenes wird erkannt und übersprungen).

## Schritt 4: Modell laden

Das Modell gehört **nicht** zum Repo — bitte selbst holen:

```
Dateiname:  Ternary-Bonsai-2-27B-PQ2_0.gguf
Größe:      6,71 GiB (6.712.117.xxx Byte — Abweichungen je nach Quelle ok)
Zielpfad:   ~/Ai/model/Ternary-Bonsai-2-27B-PQ2_0.gguf
```

Vorgehen: auf Hugging Face nach dem Dateinamen suchen (Modellkarte des
Herausgebenden „PrismML-Eng"), die `.gguf`-Datei herunterladen und nach
`~/Ai/model/` verschieben:

```bash
mkdir -p ~/Ai/model
mv ~/Downloads/Ternary-Bonsai-2-27B-PQ2_0.gguf ~/Ai/model/
ls -lh ~/Ai/model/
```

Prüfen: die Datei muss **größer als 5 GiB** sein (kleinere Datei = falscher
Download). Danach hilft `./install.sh --verify` weiter — er meldet, ob die
Datei gefunden wurde.

Lag die Datei schon woanders (z. B. `~/models/`), genügt es, sie bei
`ai start` anzugeben:

```bash
MODEL_PATH=$HOME/models/Ternary-Bonsai-2-27B-PQ2_0.gguf ai start
```

## Schritt 5: Aliase aktivieren, Erstkontrolle

```bash
source ~/.bashrc
which lex
lex --version
```

Erwartet: der Verweis zeigt nach `~/Ai/lex/lex`, die Version meldet `lex 0.4.0`.

Die vier neuen Befehle:

| Befehl | Wirkung |
|---|---|
| `ai` | llama-server starten/stoppen, Status abfragen |
| `lex` | den Agenten starten |
| `tlex` | lex in einer tmux-Sitzung namens `lex` |
| `tlexkill` | diese tmux-Sitzung beenden |

## Schritt 6: llama-server starten

```bash
ai start
```

Sie sehen die Begrüßung und ein **Modus-Menü** (Pfeiltasten oder `1`/`2`,
Enter):

```
Startmodus wählen  (↑↓, Enter, 1/2, Esc)
> 1  Standard   262144 ctx, 1 Slot
  2  Split      2 × 131072 (128k), getrennt, parallel
```

- **Standard (1)** — ein Client bekommt den vollen Kontext von 262144 Zeichen.
  Das ist der normale Betrieb für eine Person.
- **Split (2)** — zwei getrennte Slots mit je 131072 Zeichen; sinnvoll, wenn
  zwei Sitzungen (z. B. zwei Terminals) gleichzeitig arbeiten, jede mit
  eigenem Gedächtnis-Speicher.

Beim Start prüft `ai.sh` die GPU und schreibt eine Zeile wie:

```
GPU:          NVIDIA GeForce RTX 4060 · VRAM frei: 15980 von 16376 MiB
```

**Wichtig:** steht dort „wenig VRAM frei", *warnt* das Skript nur — es ändert
nie still etwas. In dem Fall den Server beenden und mit kleinerem Kontext
starten (siehe [VRAM](#vram-und-kontext-rtx-4060)).

Nach dem Start:

```bash
ai status
```

zeigt Server, Startmodus, Modellpfad, Kontextgröße, Log-Pfad und VRAM. Die
Serveradresse steht oben: `http://127.0.0.1:8080` (openai-kompatibel, nur
dieser eine Rechner).

Beenden mit:

```bash
ai stop
```

## Schritt 7: Erster Kontakt mit lex

```bash
lex
```

Sie landen in der Eingabezeile (REPL). Probieren Sie:

```
Status zeigen
```

Der Agent meldet sich kurz, holt sich Werkzeuge und antwortet auf Deutsch.

Sinnvolle erste Eingaben:

```
/ help
```

(spaltet die Hilfe auf — Slash-Befehle werden lokal beantwortet, ohne Anfrage
ans Modell):

```
/server
```

zeigt, ob der Server läuft und welches Modell dahintersteckt.

**Beenden** mit `/exit`, `/quit` oder `Strg-D`.

Das erste `lex` legt automatisch `~/.lex/` an (Sitzungen, Erinnerungen,
Pläne, Einstellungen). Mit `lex --install` geht das auch ohne REPL.

## Schritt 8: Alles verifizieren

```bash
./install.sh --verify
```

prüft: Summen aller Dateien gegen `manifest/sha256-payload.txt`, Syntax aller
Skripte, Testsuite, Modell- und Server-Lage. Am Ende steht entweder
„Verifikation bestanden" oder eine Liste der offenen Punkte.

Die Testsuite einzeln:

```bash
LEX_MOCK=done bash ~/Ai/lex/test/run_all.sh
```

Erwartet: **19 von 19 Läufern grün**. Die Suite arbeitet vollständig simuliert
— es geht kein Request an den Server, es braucht kein Modell und keine GPU.

Damit ist die Einrichtung abgeschlossen.

---

# Teil 2 — Lex benutzen

## Die Eingabezeile (REPL)

`lex` startet und wartet auf Eingabe. Es gibt zwei Arten von Eingaben:

1. **Slash-Befehle** (`/status`, `/help`, …) — werden sofort und **ohne**
   Anfrage ans Modell beantwortet.
2. **Alles andere** — ist eine Aufgabe ans Modell. lex denkt, hält Werkzeuge
   bereit und arbeitet die Aufgabe ab, sichtbar Schritt für Schritt.

Während der Arbeit zeigt lex, welches Werkzeug gerade läuft. Ihre Eingabe
bleibt in der Historie (Pfeil hoch/unten). `Strg-C` bricht die laufende
Antwort ab, ohne die Sitzung zu beenden.

Die Person, die hier antwortet, ist auf Deutsch, kurz und direkt — kein
Ratgeberton, keine leeren Floskeln. Sie kann Dateien lesen und schreiben,
Skripte ausführen, im Web recherchieren, einen echten Browser steuern und
MCP-Server ansprechen.

## Alle Slash-Befehle

| Befehl | Wirkung |
|---|---|
| `/help` | vollständige Hilfe (Modi, Slash-Befehle, Sicherheit, Konfiguration) |
| `/status` | gleiche Anzeige wie `lex --status`: Modus, Sitzung, Kontext, Einstellungen |
| `/server` | Zustand des llama-servers: Port, Modell, Kontext, RAM |
| `/plan` | die aktuelle Aufgabenliste anzeigen (`todo`) |
| `/compact` | den Kontext jetzt zusammenfassen: Altes wird zu einer Zusammenfassung gekürzt, der Antwort-Anfang bleibt erhalten — sinnvoll, bevor große Aufgaben starten |
| `/lexpen` | Prompt-Modus „Lex-Persona" einschalten (Senior-Engineer-Stil) |
| `/lexpen off` / `/lex` | zurück zum Original-Prompt |
| `/autosudo on` | sudo-Freigaben nicht mehr jedes Mal fragen (nur für unbeaufsichtigte Läufe) |
| `/autosudo off` | wieder jedes Mal fragen |
| `/exit`, `/quit` | REPL beenden |

Hinweis zu `/lexpen`: die beiden Modi (Original und Persona) teilen sich einen
Platz — wer den einen einschaltet, verdrängt den anderen.

## Die 19 Werkzeuge

Das sind die Werkzeuge, die lex für Sie benutzen kann (Reihenfolge wie in der
Hilfe):

| Werkzeug | Was es tut |
|---|---|
| `read_file` | eine Datei lesen |
| `write_file` | eine Datei schreiben (überschreibt) |
| `edit_file` | eine Stelle in einer Datei ersetzen |
| `append_file` | Text ans Ende einer Datei hängen (so bleibt das Log erhalten) |
| `bash` | einen Shell-Befehl ausführen (mit Deny-Liste, siehe Sicherheit) |
| `list_files` | Dateien auflisten, mit Muster und Rekursion |
| `search` | in Dateien suchen — Standard wörtlich, mit `regex` auch per Ausdruck |
| `mem_add` | eine Erinnerung ablegen (Typ: `memory`, `fact`, `preference`, `note`) |
| `mem_list` / `mem_search` | Erinnerungen auflisten / durchsuchen |
| `todo` | Aufgabenliste anlegen, abhaken, anzeigen |
| `web_search` | Websuche (ohne Schlüssel, über DuckDuckGo) |
| `web_fetch` | eine Seite als Klartext holen |
| `fetch` | eine Seite als **Quelle ins Wiki** legen (bleibend) |
| `context7` | aktuelle Dokumentation zu Bibliotheken und Frameworks |
| `browser` | echten Browser steuern (navigate, snapshot, click, type, …) |
| `mcp` | generischer Zugriff auf konfigurierte MCP-Server |
| `agent` | einen Teil-Auftrag an einen Sub-Agenten mit eigenem Gedächtnis geben |
| `task` | lange Befehle in den Hintergrund legen (start/list/status/result/kill) |

Sie müssen diese Namen nicht eingeben — beschreiben Sie die Aufgabe, lex wählt
das Werkzeug. Wer wissen will, was tatsächlich passiert, kann jederzeit
`/status` eingeben oder die Log-Datei unter `~/.lex/` ansehen.

## Ablauf einer typischen Aufgabe

Beispiel — Sie wollen wissen, was auf Ihrem Rechner läuft:

```
schau mal was auf diesem Rechner laeuht und ob der llama-server noch geht
```

Was jetzt passiert (Reihenfolge kann variieren):

1. lex schreibt kurz, was es vorhat.
2. Es ruft `bash` mit Befehlen wie `ps`, `ss -tlnp` auf — Sie sehen die Werkzeugaufrufe.
3. Ergebnisse kommen **vollständig** an (keine abgeschnittenen Ausgaben).
4. Am Ende steht eine kurze Antwort auf Deutsch mit dem Befund.

Längere Aufgaben, z. B.:

```
recherchiere ob es fuer unser modell neue versionen gibt, hole die quelle
ins wiki und schreib eine kurze zusammenfassung ins log
```

Dafür arbeitet lex mehrere Werkzeuge nacheinander ab (`web_search`, `fetch`,
`append_file`) und hält sich an die Wiki-Regeln (unten).

**Bitten, die besonders gut funktionieren:**

- *„prüfe X und behebe es, dann verifiziere mit <Befehl>"* — Aufgaben mit
  klarer Gegenprobe.
- *„lies zuerst <Datei>, dann …"* — wenn lex etwas Bestimmtes im Blick haben soll.
- *„leg eine Quelle unter <Wiki-Thema> ab"* — für bleibendes Wissen.

**Was lex von sich aus tut:** bevor es etwas neu baut, prüft es, ob es schon
vorhanden ist (Wiki, Werkstatt, Plan). Bevor es einen fremden Befehl zum ersten
Mal startet, dessen Optionen es nicht sicher kennt, ruft es `<befehl> --help`
auf — nie raten. Weiß es etwas nicht belegt, sagt es das — statt es zu erfinden.

## Pläne und Aufgabenlisten

Bei Aufgaben mit mehr als drei Schritten legt lex zuerst einen Plan an:

```
todo(action=add, text=„Schritt beschreiben“)
```

Sie sehen den Plan jederzeit mit `/plan`. Er wird über Sitzungen hinweg
gespeichert (`~/.lex/plans/`) — eine unterbrochene Aufgabe nimmt der nächste
Start wieder auf.

## Gedächtnis: Wiki und Erinnerungen

Es gibt zwei Ebenen:

**Das Wiki** unter `~/Ai/wiki/` — gebaut nach der Karpathy-Struktur:

```
wiki/
├── index.md          # Verzeichnis: eine Zeile pro Artikel
├── log.md            # Arbeitsprotokoll (nur anhängen, nie überschreiben)
├── errors/           # dokumentierte Fehler und ihre Lösungen
├── concepts/         # Sachwissen (Playbooks, Verfahren)
└── raw/              # unveränderte Rohquellen (Quellen-Nachweis)
```

Regeln, die lex einhält: `raw/` ist unveränderlich, `log.md` wird nur
angehängt, neue Artikel bekommen eine Zeile im `index.md`, jede Aussage im
Wiki braucht eine Quelle. So wächst das Wissen mit — beim nächsten Start liest
lex sein eigenes Wiki, statt alles neu zu recherchieren.

**Die Erinnerungen** unter `~/.lex/mem/` — kurze Notizen zu Präferenzen und
Fakten:

- eine Präferenz ablegen: *„merk dir: logs immer nach ~/log schreiben"*
- später prüfen: `/status` zeigt die Sitzung, `mem_search` sucht Notizen

Wichtig: Erinnerungen sind **Hinweise, kein Gesetz** — jede Statusaussage
prüft lex gegen den tatsächlichen Zustand, bevor sie weitergegeben wird.

## Kontext steuern

Der Kontext ist der Arbeitsgedächtnis-Speicher einer Anfrage (Standard 262144
Zeichen). Irgendwann wird er voll:

- `/compact` — jetzt zusammenfassen und weiterarbeiten
- automatisch: wenn die Auslastung hochläuft, warnt lex und fasst zusammen
- ganz von vorn: `/exit` und neu starten

Zeigt lex an, dass Kontext und Speicher knapp werden, arbeitet es nach der
Regel: **zuerst das Ergebnis sichern, dann feile** — ein fertiges Kernstück
schlägt eine perfekte Antwort ohne Ende.

## Sicherheit: was lex nicht darf

Es gibt mehrere Schichten, die **immer** greifen:

1. **Harte Ablehnungsliste** im `bash`-Werkzeug: Löschen im Wurzelverzeichnis,
   Zugriff auf Blockgeräte, `su`, Neustarts von Systemdiensten und Kürzungs-Pipes
   (`| head`, `| tail`) werden abgelehnt. Das gilt unabhängig von allem anderen.
2. **Keine Anfassung des Displays:** Compositor, Anmelde-Dienste, PAM und
   Anmelde-Konfiguration sind tabu — ein Neustart dort tötet Desktop und REPL.
3. **`--approve`-Modus:** `lex --approve` fragt vor *jeder* Shell-Ausführung
   nach — nützlich, wenn Sie genau sehen wollen, was passiert.
4. **Haken („Hooks"):** legen Sie eine ausführbare Datei nach
   `~/.lex/hooks/pre_tool/`, die bei Aufruf mit `LEX_HOOK_EVENT`, `LEX_HOOK_TOOL`,
   `LEX_HOOK_ARGS` und `LEX_HOOK_RC` versorgt wird. Gibt sie einen Rückgabewert
   ungleich null zurück, wird der Aufruf **blockiert**. `~/.lex/hooks/post_tool/`
   beobachtet nur (schreibt mit). Abschalten mit `LEX_HOOKS=off`.
5. **Kein Zugriff auf fremde Server ohne Rückfrage:** alles, was Verkehr zu
   Dritten öffnet (fremde Rechner, Accounts, Dienste), wird vorher gefragt.
   Ebenso: Kommandos, die nicht umkehrbar sind.

## sudo richtig benutzen

sudo ist bei lex **kein Verbot, sondern ein Gate**:

- Benötigt ein Befehl Root-Rechte, erscheint **genau eine** Aufforderung am
  Terminal mit dem vollständigen Befehl. Das Passwort geht direkt in die
  sudo-Eingabeaufforderung (lex sieht es nie).
- Mit gültigem Recht fragt lex **einmal pro Sitzung**: „sudo für diese ganze
  Sitzung freigeben? (j/N)". Danach läuft sudo ohne Nachfrage weiter.
  Antworten Sie mit Nein, wird weiterhin pro Befehl gefragt.
- **Ohne Terminal läuft kein sudo** — Hintergrund-Läufe bekommen keine Rechte.
- Vollständig sperren: `LEX_SUDO=0`. Alle Freigabefragen unterdrücken:
  `LEX_SUDO_APPROVE=0`. Ohne Nachfragen (nur für unbeaufsichtigte Läufe):
  `/autosudo on`.

Wenn ein sudo-Befehl abgelehnt wird, gibt lex das sichtbar zurück und fordert
den Befehl erneut an — es arbeitet nicht stillschweigend ohne Rechte weiter.

## Konfiguration einstellen

Einstellungen wirken in vier Stufen (spätere überschreiben frühere):

1. mitgelieferte Werte
2. `~/.lex/settings.json` — die dauerhafte Konfiguration
3. `.lex/settings.json` im Projektverzeichnis — für einzelne Projekte
4. Umgebungsvariablen — für einen einzelnen Aufruf

Wichtigste Felder in `settings.json`:

| Feld | Bedeutung |
|---|---|
| `api_url` | Adresse des Servers (`http://127.0.0.1:8080/v1/chat/completions`) |
| `model` | Modellname |
| `max_tokens` | Länge der Antwort |
| `reasoning_budget_tokens` | Budget für das „Mitdenken" |
| `temperature` | Zufall (höhere Werte = freier) |

Wichtigste Umgebungsvariablen (Vollständigkeit in `lex --help`):

| Variable | Wirkung |
|---|---|
| `LEX_API_URL`, `LEX_MODEL` | Serveradresse / Modell |
| `LEX_MAX_TOKENS`, `LEX_TEMPERATURE` | Antwortlänge / Zufall |
| `LEX_MAX_TURNS` | Anzahl der Werkzeug-Schritte pro Aufgabe |
| `LEX_TOOL_TIMEOUT`, `LEX_TOOL_MAX_OUTPUT` | Frist und Ausgabegrenze je Werkzeug |
| `LEX_CTX_LIMIT`, `LEX_COMPACT`, `LEX_COMPACT_KEEP` | Kontextgrenze und Zusammenfassung |
| `LEX_TRACE`, `LEX_SHOW_REASONING` | Lautstärke der Anzeige |
| `LEX_SESSION`, `LEX_MEM_DIR`, `LEX_WIKI_DIR`, `LEX_HTOOLS_DIR` | Pfade für Sitzungen, Erinnerungen, Wiki, Werkstatt |
| `LEX_MOCK`, `LEX_MOCK_FILE` | Tests ohne Server (siehe unten) |

Beispiel — einmalig mit anderem Modell:

```bash
LEX_MODEL=mein-anderes-modell lex
```

Dauerhaft: `~/.lex/settings.json` mit einem Textbearbeiter anpassen (JSON —
Vorsicht mit Kommas und Anführungszeichen; `lex --status` zeigt die gelesenen
Werte und hilft beim Prüfen).

## lex ohne REPL (für Skripte)

```bash
echo "pruefe den datenbank-server" | lex --oneshot
```

Die Aufgabe läuft einmal durch, das Ergebnis geht auf die Standardausgabe,
danach endet lex. Gut für Cron, für Verkettungen und für Skripte.

Weitere Modi:

```bash
lex --status     # nur Zustand zeigen, nichts ausführen
lex --approve    # REPL, jede Shell-Ausführung wird vorher abgefragt
lex --eval       # Auswertung der letzten Laufzeit (spans.jsonl)
lex --install    # ~/.lex/ anlegen, ohne zu starten
lex --version
lex --help
```

## Diagnose und Auswertung

Wenn etwas nicht so läuft wie erwartet:

```bash
lex --status            # welche Konfiguration liest lex wirklich?
/server                 # läuft der Server, welches Modell, welcher Kontext?
lex --eval              # wie lange hat die letzte Aufgabe gedauert?
```

Dateien, die weiterhelfen:

```bash
tail -f ~/Ai/logs/llama.log        # Server-Protokoll
ls ~/.lex/sessions/                # Sitzungsverläufe
ls ~/.lex/log/                     # Laufzeit-Auswertungen
```

Und das einfachste Werkzeug: im Wiki nachschauen, wo lex seine Befunde
festhält:

```bash
less ~/Ai/wiki/wiki/index.md
```

---

# Teil 3 — Wartung und Feinabstimmung

## VRAM und Kontext (RTX 4060)

Die mitgelieferte Einstellung ist auf 16 GiB Speicher ausgelegt und braucht
keine Änderung. Gemessene Werte dieser Kombination (gleicher Server, gleiches
Modell): beim Start etwa 8 GiB belegt, bei 155k ausgelastetem Kontext etwa
14,6 GiB.

Zwei Stellschrauben, wenn es eng wird:

**Kontext halbieren:**

```bash
ai stop
CTX=131072 ai start
```

**Zusätzliche Speicherbehälter freigeben** (bewährter Einzelfall aus der
Dokumentation `KNOWN_ISSUES.md`, Eintrag 183): Start mit einem Slot und
großem RAM-Puffer:

```bash
ai stop
CTX=131072 ai start    # und im Skript bei Bedarf: -np 1 --cache-ram 24576
```

Prüfen lässt sich der Effekt sofort: `ai status` zeigt VRAM-frei, `/server`
zeigt den tatsächlich laufenden Kontext.

Alle Prism-spezifischen Fallstricke (welche Vorlagen nötig sind, was die
Quantisierung bedeutet, welche Optionen es nicht gibt) stehen in
`~/Ai/model/KNOWN_ISSUES.md` — **vor dem Umbauen von Optionen dort nachschlagen**.

## Server betreiben

```bash
ai start 1        # Standard: 262144 Kontext, 1 Slot
ai start 2        # Split: 2 × 131072, parallel
ai status         # inklusive VRAM-Anzeige
ai stop           # alles stoppen
ai restart        # neu starten
ai chat           # Endpunkt-Infos
ai wiki           # Wiki-Seiten auflisten
```

Nebenwerte per Umgebung (vor `ai start`):

| Variable | Default | Bedeutung |
|---|---|---|
| `CTX` | `262144` | Gesamt-Kontext |
| `LLAMA_UB` | `1024` | Micro-Batch-Größe |
| `LLAMA_LV` | `3` | Protokollstufe des Servers |
| `AI_PORT` | `8080` | Port |
| `MODEL_PATH` | `~/Ai/model/…gguf` | wo das Modell liegt |
| `LLAMA_BIN` | `~/Ai/llama.cpp-prism/build/bin/llama-server` | welcher Server |
| `VRAM_WARN_MIB` | `4000` | ab wie viel freiem Speicher gewarnt wird |

Beispiel — zweiter Server auf anderem Port mit anderem Modell:

```bash
AI_PORT=8081 MODEL_PATH=$HOME/models/anderes.gguf ai start
```

## Änderungen selbst vornehmen

Das System ist dafür gebaut, dass Sie es anfassen können:

```bash
less ~/Ai/lex/lex              # der ganze Agent in einer Datei
bash -n ~/Ai/lex/lex           # Syntaxprüfung nach jeder Änderung
shellcheck -S warning ~/Ai/lex/lex
LEX_MOCK=done bash ~/Ai/lex/test/run_all.sh    # danach: 19/19 grün?
```

Werkzeuge und Hilfen liegen in `~/Ai/lex/tools/`:

| Skript | Nutzen |
|---|---|
| `selfcheck_lex.sh` | Selbstcheck nach jeder Änderung am Skript |
| `llama-proxy.sh` | Debug-Proxy: Requests protokollieren (`start`, `stop`, `status`, `tail`, `show`) |
| `werkstatt_index.sh` | Werkstatt-Index auffrischen (`$LEX_HTOOLS_DIR/WERKSTATT.md`) |

Die Werkstatt selbst liegt unter `~/.lex/werkstatt/` — dort gehören
heruntergeladene Tools, Venvs und Skripte hin (nicht nach `/tmp`, nicht ins
Home). Python-Programme laufen grundsätzlich über
`~/.lex/werkstatt/.venv/bin/python`.

Die vollständige Bauweise (Arbeitszyklus, Test-Regeln, Definition of Done)
steht in `~/Ai/lex/LEX.md` — dieses Dokument ist die Basisdoku des Projekts.

## Häufige Situationen

**„Der Server antwortet nicht"**
`ai status` → läuft er überhaupt? → `ai stop && ai start`. Im Zweifel
`tail -20 ~/Ai/logs/llama.log`.

**„lex sagt, das Modell fehlt"**
`ls -lh ~/Ai/model/` — Datei mit dem richtigen Namen und mehr als 5 GiB?
Sonst `MODEL_PATH=… ai start`.

**„Zu wenig VRAM"**
`ai status` (VRAM-frei lesen) → `ai stop && CTX=131072 ai start`.

**„Die Testsuite ist rot"**
Welcher Läufer? Die betreffende Datei unter `~/Ai/lex/test/` einzeln starten,
Ausgabe lesen. Danach `bash -n ~/Ai/lex/lex` als Schnellcheck.

**„lex wiederholt sich"**
Der Wiederholungs-Schutz greift selbstständig (Anstoß, harter Anstoß,
Zusammenfassung). Wenn er dreimal greift: Aufgabe anders formulieren oder
`/exit`, neuen Start — ein frischer Kontext löst das meiste.

**„Ich will alles von vorn"**
`~/.lex/` löschen und `lex --install` — Sitzungen, Erinnerungen und Pläne
sind dann neu. Das Wiki unter `~/Ai/wiki/` bleibt erhalten (bewahren!),
das Modell und der Server-Build auch.

**„Ich habe das System geändert und will prüfen, ob noch alles stimmt"**
`./install.sh --verify` aus dem Repo-Verzeichnis.

---

Zum Nachschlagen:

- `~/Ai/lex/LEX.md` — Bauweise, Ist-Stand, Regeln, offene Fragen
- `~/Ai/lex/CHANGELOG.md` — was wann geändert wurde
- `~/Ai/model/KNOWN_ISSUES.md` — Eigenheiten von Server und Modell
- `~/Ai/wiki/` — Ihr eigenes Gedächtnis, das mit der Arbeit wächst
