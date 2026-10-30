# lex

Reines-Bash-basierter LLM-Terminal-Agent (v0.4.0) für einen lokalen
llama-server. Kern: nur `bash`, `jq`, `curl` — **optional** `node` für die
MCP-Tools (Schritt 9) und `python3` für zwei Test-Fixtures. Kein Docker.

Vollständige Bau- und Betriebsdoku: **[LEX.md](LEX.md)** (einziges
Arbeitsdokument, §0/§0.1 zuerst lesen).

## Voraussetzungen

| Werkzeug | Zweck | Fehlt? |
|---|---|---|
| bash | Skript (getestet: 5.2; **Bash ≥ 4** wegen `coproc` — macOS-Systembash 3.2 reicht nicht: `brew install bash`) | harte Anforderung |
| jq | JSON für das OpenAI-Protokoll | harte Anforderung |
| curl | HTTP an den Server | harte Anforderung |
| `timeout`, `realpath`, `readlink -f` | Zeitlimit/Pfad-Normalisierung | **Fallback eingebaut** (`command -v`-Guard) |
| ncat | Fake-Server der Tests | nur für `test_http.sh` |
| shellcheck | Lint | nur für CI/Entwicklung |
| python3 | Fake-Webserver (HTML-/Such-Fixture) in `test_features.sh` | nur für Tests |
| node (v20) + MCP-Server | `web_fetch`, `context7` | nur für diese zwei Tools — ohne sie kommt eine klare Fehlermeldung |

## Schnellstart

```bash
ai.sh start        # llama-server starten (Port 8080)
lex                # interaktiver REPL (Symlink ~/.local/bin/lex, kein Alias nötig)
./lex              # dasselbe über den vollen Pfad
./lex --oneshot    # ein Prompt von stdin, Antwort nach stdout
./lex --status     # Konfigurations- und Laufzeitstatus
./lex --approve    # REPL, jede bash-Ausführung wird vorher abgefragt
./lex --install    # ~/.lex/ anlegen (log/, sessions/, mem/, …)
./lex --eval [f]   # Tool-Aufrufe auswerten (Spans: ok, Fehler-Quote, dauer)
```

REPL-Slash-Befehle: `/status`, `/server`, `/plan`, `/help`, `/compact`
(manuell komprimieren), `/exit` (auch `/quit`, Ctrl-D).

**Context-Compaction:** sobald der geschätzte Prompt (Bytes ÷ 3, im
Live-Verify gegen `prompt_tokens` kalibriert) die Schwelle
`ctx − max(max_tokens, buffer)` (Default 160224 von 180224) erreicht,
fasst lex ältere Nachrichten automatisch in eine Zusammenfassung
zusammen (Marker `<!--lex-compact-->`, Kontext-Integrität als Gate);
`/compact` erzwingt den Lauf, `LEX_COMPACT=0` schaltet ihn ab,
`LEX_COMPACT_KEEP`/`LEX_COMPACT_BUFFER` justieren Tail/Schwelle,
`LEX_CTX_LIMIT` setzt die angenommene Kontextgröße.

## Tools (19)

`read_file`, `write_file`, `edit_file` (mit `all` für alle Vorkommen),
`append_file`, `bash`, `list_files` (+ `pattern`, `recursive`), `search`,
`fetch` (Rohquelle nach `<wiki>/raw/<topic>/`), `todo` (Planung),
`mem_add`, `mem_list`, `mem_search`, dazu aus den letzten Schritten:

- `web_search(query)` — Websuche **ohne API-Key** (DuckDuckGo): Titel,
  URL und Ausschnitt, Redirects (`uddg=`) und HTML-Entities aufgelöst
- `web_fetch(url, max_length?)` — eine bekannte Seite per **Crawler**
  (MCP defuddle) als Klartext, ohne Ablage (für Quellen mit Ablage
  weiter `fetch(url, topic)`)
- `context7(query, library?)` — **aktuelle** Bibliotheken-Doku
  (MCP context7), der Gegenpol zum trainierten Modellwissen
- `browser(action, url?, ref?, …)` — echter Browser über Playwright-MCP
  (System-Chrome): `navigate` → `snapshot` (ARIA-refs) → `click`/`type`
  per Ref; kein Screenshot, der Snapshot ist Text
- `mcp(server, tool?, arguments?)` — generischer Zugriff auf alle
  konfigurierten MCP-Server (defuddle, context7, playwright, desktop,
  postgres, dazu alles aus `~/.lex/mcp.json`); zuerst `__tools` als
  Discovery-Liste, dann Aufruf
- `agent(task, mode)` — Sub-Agent mit **frischem Kontext** (explore/
  plan/review/summarize), Tiefen-Gate, Ergebnis ist reine Textausgabe
- `task(action, command?, id?, name?, tail?)` — **Background-Tasks**
  (start/list/status/result/kill) unter `~/.lex/tasks/<id>/`, laufen in
  eigener Sitzung weiter und bleiben nach Ende von lex lesbar

Memory liegt als Markdown mit YAML-Frontmatter unter `~/.lex/mem/`
(Typen: `memory`, `fact`, `preference`, `note`).
Jede Konversation wird append-only als JSONL unter
`~/.lex/sessions/<id>/session.jsonl` gespeichert — inklusive
`reasoning_content`, das bewusst **nicht** in den Modell-Kontext
geschrieben wird (Kontextschutz, siehe LEX.md §4).

## Oberfläche (CLI mit TUI-Gefühl)

Kein curses-TUI — aber strukturierte Ausgabe, alles über ANSI und ohne neue
Abhängigkeiten:

- `lex>`-Prompt (blau/fett, nur bei TTY — ohne Terminal bzw. mit
  `NO_COLOR` bleibt er farblos), Eingabe mit **Readline**: Pfeiltasten,
  Ctrl-A/E/W/U, **Tab = Pfadvervollständigung**, History unter
  `~/.lex/history` (500 Einträge, über Sessions hinweg)
- `⚙ denken:` — was das Modell gedacht hat (`reasoning_content`): Header
  dim-magenta, Inhalt **grau und eingerückt** auf stderr — bewusst
  abgesetzt, damit Denken und Antwort nicht verwechselt werden; aus mit
  `LEX_SHOW_REASONING=0`, `LEX_REASONING_MAX` (Default 0 = vollständig, kein Kürzen)
- `⏳ denke …` Spinner während der Generierung (startet erst nach 250 ms)
- `⚙ tool args` für laufende Werkzeuge: Name **fett cyan**, Argumente
  grau; `↳ tool` (cyan-dim) mit eingerückter Rückgabe (Default `LEX_TRACE_RESULT_MAX=0` = vollständig, keine Kappung)
  Rückgabe
- `⏱ 3,2s · turn 2/50 · tokens 1409/180224 (1%) prompt + 69 completion`
  und die Trennlinie erscheinen **vor** der Antwort — sie ist das Letzte,
  was auf dem Bildschirm steht (sonst geht sie optisch unter); mit
  `LEX_CTX_LIMIT` (bzw. `ctx_limit`) wird die Kontext-Auslastung als
  Prozentwert angezeigt, ohne Limit nur `tokens X prompt + Y completion`
- finale Antwort mit Markdown-Licht: H1 **fett + unterstrichen** (statt
  „weiß" — auf hellem Terminal unsichtbar), H2 **fett cyan**, H3 cyan,
  `**fett**`, `` `code` ``, `[[wikilinks]]`, Zitate, Warnung orange,
  `❌`/`Fehler:` rot, `✓` grün, Links cyan+unterstrichen, **Pipe-Tabellen**
  sauber gesetzt (Kopf cyan/fett, Raster dim, rechtsbündig bei `:---`)

Alle Sequenzen laufen über eine zentrale Palette: **`NO_COLOR`** und
`TERM=dumb` schalten die Farben komplett ab (Standard-Konvention,
https://no-color.org), `LEX_TRACE=1` zeigt den Trace auch ohne Terminal.

Nur die Antwort selbst steht auf stdout — alles andere läuft auf **stderr**
und nur bei einem Terminal (bzw. mit `LEX_TRACE=1`). Pipes, Dateien und
Tests bleiben damit roh und unverändert.

## MCP & Websuche

Zwei eingebundene MCP-Server laufen über **stdio** (JSON-RPC 2.0), eine
Session pro Aufruf:

| Server | Tool(s) | Startkommando |
|---|---|---|
| `defuddle` | `web_fetch` | `node ~/.mcp/node_modules/defuddle-stdio-mcp/index.js` |
| `context7` | `context7` | `~/.local/bin/context7-mcp` |

Die Standorte liegen in **`~/.lex/mcp.json`** (ohne Datei gelten die
obigen Defaults), mit `LEX_MCP=0` sind beide Tools abgeschaltet und
`LEX_MCP_TIMEOUT` (Sekunden, Standard 60) begrenzt jeden Aufruf.
Die Websuche (`web_search`) läuft ohne MCP direkt gegen DuckDuckGo-html,
`LEX_SEARCH_URL` erlaubt einen anderen Endpunkt (die Tests nutzen das,
damit **kein Test ins Netz geht**).

## Sicherheit

- `tool_bash` hat eine **harte Deny-Liste, die immer aktiv ist** und das
  Kommando in **Segmente** zerlegt (`&&`, `||`, `|`, `;`, Zeilenumbruch):
  - rm auf Root/Home/`.` — auch als `rm -rf -- /`, `rm -Rf /`,
    `rm --no-preserve-root -rf /`, `sudo rm -rf /`, `xargs rm -rf /`
  - Downloads in eine Shell — auch als `curl … | sh | cat` oder
    `curl … && sh x.sh` (nicht nur die letzte Pipe); `curl … | cat`
    und `curl … | grep sh` bleiben erlaubt
  - `su` als Kommando-Wort (`su postgres -c …`, auch hinter `sudo`)
  - Blockgeräte (`mkfs`, `of=/dev/`, `dd … of=/dev/…`), Fork-Bomben,
    Herunterfahren/Neustart, Systemprozesse killen, rekursives
    Rechte-Wegwerfen, `history -c`
- **sudo ist kein Verbot, sondern ein Gate** (LEX.md §6 #13): beim ersten
  `sudo`-Kommando erscheint **genau eine Aufforderung** auf dem Terminal —
  mit dem Kommando, in die du dein Passwort direkt in den sudo-Prompt
  tippst. Das Passwort läuft dabei **direkt an sudo**, nie durch lex
  (keine Variable, kein Log). Ist das sudo-Ticket schon gültig, wird
  stattdessen `y/N` gefragt. Ohne controlling TTY keine sudo-Ausführung.
  `LEX_SUDO=0` sperrt sudo komplett, `LEX_SUDO_APPROVE=0` lässt die
  y/N-Frage bei gültigem Ticket weg.
- **Opt-in** Approval-Gate für **alle** bash-Ausführungen: nur mit
  `--approve` oder `LEX_APPROVE=1` und einem controlling TTY wird jede
  Ausführung abgefragt — ohne Flag läuft der Agent prompt-frei (Tests
  bleiben deterministisch). Das sudo-Gate greift davon **unabhängig**.
- `safe_path` erlaubt nur Pfade außerhalb von `/etc`, `/usr`, `/bin`,
  `/sbin`, `/boot`, `/dev`, `/proc`, `/sys`, `/var`, `/lib`, `/lib64`,
  `/root` — **auch die nackten Wurzeln** (`/etc`, nicht nur `/etc/…`)
  und **Symlink-Ziele** werden aufgelöst und geprüft.

## Konfiguration (4-Tier)

`Defaults → ~/.lex/settings.json → .lex/settings.json (CWD) → ENV`

Wichtige ENV-Variablen: `LEX_API_URL`, `LEX_MODEL`, `LEX_MAX_TOKENS`,
`LEX_REASONING_BUDGET`, `LEX_TEMPERATURE`, `LEX_MAX_TURNS`,
`LEX_TOOL_TIMEOUT`, `LEX_TOOL_MAX_OUTPUT`, `LEX_LOG_DIR`, `LEX_MOCK`,
`LEX_MOCK_FILE`, `LEX_APPROVE`, `LEX_SUDO`, `LEX_SUDO_APPROVE`,
`LEX_SESSION`, `LEX_MEM_DIR`,
`LEX_WIKI_DIR`, `LEX_TRACE` (Trace/HUD/Spinner auf stderr erzwingen),
`LEX_SHOW_REASONING` (0 = Denk-Block aus), `LEX_REASONING_MAX` (Kappung),
`LEX_MCP`/`LEX_MCP_TIMEOUT` (MCP an/aus und Zeitlimit),
`LEX_SEARCH_URL`/`LEX_SEARCH_TIMEOUT` (Endpunkt und Zeitlimit der Suche),
`LEX_CTX_LIMIT`/`LEX_COMPACT`/`LEX_COMPACT_KEEP`/`LEX_COMPACT_BUFFER`
(Kontextgröße, Compaction an/aus, Tail-Budget, Schwellen-Buffer),
`LEX_API_RETRIES` (Wiederholungen bei 429/5xx und curl-Fehlern,
Default 2, max. 10), `LEX_LOOP_GUARD=off` (Fail-Gedächtnis bei
identischen Tool-Läufen abschalten), `LEX_REASONING_STORE_MAX`
(Obergrenze für das gespeicherte Reasoning, Default 20000 Zeichen),
`LEX_HTOOLS_DIR` (Wurzel für Software & Tools).

## Tests

```bash
./test/run_all.sh          # 13 Läufer / 1174 [PASS] = 1161 Einzelf, Exit 0 nur wenn alle grün
shellcheck -S warning lex test/*.sh tools/*.sh
```

Der erste Läufer ist **`testboden`**: er bricht ab, wenn eine Testdatei
gelöscht, als Runner referenziert aber nicht vorhanden oder vorhanden aber
nicht eingebunden ist. Drei Läufer decken den Weg durch lex direkt ab:
`test/test_sse.sh` (Stream — Content-- und `tool_calls`-Deltas, echter
curl-/HTTP-Guard, fehlendes `[DONE]`, keine Nudges bei Server-/HTTP-Fehlern,
**Performance-Budget** 3000 Chunks < 2 s mit Inhaltsprüfung),
`test/test_eval.sh` (Spans + `lex --eval`) und `test/test_limits.sh`
(**kein Abschneiden an der lex↔llama-Grenze**: 280 000-B-Nachrichten in
Kontext und Session, 250 000-B-System-Prompt, Spill-Ablage mit Zeiger,
150 000-Zeichen-Server-Antwort vollständig).

## Auswertung (Observability)

Jeder `dispatch_tool`-Aufruf schreibt einen Span nach
`~/.lex/log/spans.jsonl` (pro Aufruf `ts`, `name`, `args_hash`,
`duration_ms`, `ok` — die Argumente landen als Prüfsumme in der Zeile,
nicht als Payload), append-only. Auswertung:

```bash
./lex --eval              # Auswertung der aktuellen Session
./lex --eval /pfad.jsonl  # eine konkrete Datei statt ~/.lex/log/spans.jsonl
```

Der API-Pfad ist sowohl gegen Streaming- als auch gegen klassische
JSON-Antworten des llama-servers abgesichert: curl-Rückgabecode **und** HTTP-Status werden
geprüft, `tool_calls` über alle Deltas fusioniert, `usage` kommt aus dem
Stream, und ein fehlendes `[DONE]` wird ausdrücklich gewarnt.

Die Tests sind **ohne Netzwerk und ohne Server** — entweder mit
`LEX_MOCK=done` (statisch), `LEX_MOCK_FILE` (Sequenz, Quelldatei bleibt
unversehrt) oder dem mitgelieferten Fake-Server (`test/fake_server.sh`).
Ein echter Request an `127.0.0.1:8080` findet in den Tests nie statt.
Die MCP-Tests laufen gegen `test/fake_mcp.sh` (minimaler stdio-Server),
die Such-Tests gegen einen lokalen `python3 -m http.server` mit Fixture.

## Debug-Proxy (Traffic mitlesen)

```bash
LEX_PROXY_UPSTREAM=http://127.0.0.1:8080 ./tools/llama-proxy.sh start 24480
LEX_API_URL=http://127.0.0.1:24480/v1/chat/completions ./lex --oneshot   # lex damit testen
./tools/llama-proxy.sh show 1     # n-ter Request UND Response, roh + eingerückt
./tools/llama-proxy.sh tail 20    # traffic.log (Status, Bytes, rb, finish, reasoning)
./tools/llama-proxy.sh status | stop
```

Der Proxy leitet an den llama-Server weiter und protokolliert beides unter
`.proxy/` (gitignore). Er lauscht **nur auf 127.0.0.1**, Port 8080 lehnt er ab.

## Struktur

```
lex              Hauptskript (eine Datei, 5995 Zeilen, 19 Tools)
LEX.md           Arbeitsdokument (Ist-Stand, Bugs, Roadmap)
tools/           llama-proxy.sh (Debug-Proxy zum llama-Server)
test/            run_all.sh + 11 Testdateien + fake_server.sh + fake_mcp.sh
archiv/          ältere Spezifikationen (ARCHITEKTUR.md §6 = Quelle der Features)
.github/         CI (shellcheck + run_all.sh)
```
