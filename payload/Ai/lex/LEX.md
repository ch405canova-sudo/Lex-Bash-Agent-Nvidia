# LEX — Einziges Arbeitsdokument für Project-Lex

> **Stand**: 2026-09-28 · **Ersetzt** die 7 alten MD-Dateien (liegen in [`archiv/`](archiv/)).
> **Regel**: Ab jetzt nur noch hier pflegen. Alles andere ist Archiv/Referenz.
> **Für einen neuen Chat / zoocode**: §0 lesen → §3 (Ist-Stand) → §7 (nächster Schritt). Sonst nichts.

---

## 0. SO ARBEITEST DU HIER WEITER (Handover)

### Pfade & Status prüfen (30 Sekunden)
```bash
# Wo bin ich, was steht?
less ~/Ai/lex/LEX.md            # dieses Dokument

# Geht das Skript überhaupt noch?
bash -n ~/Ai/lex/lex            # Syntax
bash ~/Ai/lex/test/run_all.sh   # 19 Läufer — Stand 2026-10-28 grün (v0.5.1); Ausbau siehe CHANGELOG.md und §3

# Schnelltest OHNE Server
echo "Sag Hallo" | LEX_MOCK=done ~/Ai/lex/lex --oneshot   # → "Taugt."
```

### Die 4 goldenen Regeln beim Weiterarbeiten
1. **Nie echte Requests an `127.0.0.1:8080`** — der llama-server ist **gemeinsam**: ZooCode (ich) und Lex laufen auf demselben llama-server (Port 8080) mit demselben Modell (Ternary-Bonsai-2-27B). **Bis der User eine Live-Test-Freigabe erteilt: NIE echtes Testing gegen den Server** — immer `LEX_MOCK=done` oder `LEX_MOCK_FILE=<datei>`. Die Ausnahme (Live-Test) gilt **nur** mit expliziter Freigabe des Users.
2. **Alles auf Deutsch** — Code-Kommentare, Fehlermeldungen, Doku, Antworten.
3. **Nur Pure Bash + jq + curl** — keine neue Abhängigkeit, ohne Eintrag in §2.
4. **§7-Reihenfolge einhalten** — nicht springen, nichts parallel bauen.

### Wo steht was
| Ich will… | Datei |
|---|---|
| weiterbauen | `LEX.md` §7 |
| eine offene Entscheidung klären | `LEX.md` §9 |
| einen Bug fixen | `LEX.md` §6 |
| den API-Kontrakt nachschlagen | `LEX.md` §4 |
| alte Recherche nachschlagen | `archiv/` (vor allem `TIEFE-RECHERCHE.md` §14–16, §19) |
| etwas ins Wissen schreiben | `~/Ai/wiki/` (Log → `wiki/log.md`, Fehler → `wiki/errors/`) |

### Sofort-Start in einem frischen zoocode-Chat
> „Lies `~/Ai/lex/LEX.md`. Phase 0 ist abgeschlossen (§7 alle Schritte ✅) — nimm die nächste Aufgabe aus §8/§10. Arbeite nach §0.1. Benutze nur Mock-Requests, echte Requests nur nach Freigabe."

---

## 0.1 DIE BAUWEISE — einheitliche Vorgehensweise

> Das ist das Protokoll, nach dem **jede** Änderung an Lex abläuft. Gleiche Schritte, gleiche Reihenfolge, jedes Mal. Wer davon abweicht, begründet es im Log.

### A. Sechs unverrückbare Prinzipen
1. **Spec vor Code.** Erst eine Zeile Entscheidung in `LEX.md` (§2 oder §6), dann der Code. Kein „später festhalten".
2. **Der Loop ist heilig.** `run_turn()` wird nie umgeschrieben — neue Fähigkeiten kommen als Funktion + Dispatch-Eintrag *darüber* (learn-claude-code s01/s02). Wer den Loophörper anfasst, begründet es explizit.
3. **Eine Sache nach der anderen.** Keine Sprünge über Phasen, kein paralleles Bauen zweier Features. Eine in-flight-Aufgabe maximal.
4. **Belege statt Behauptungen.** Jeder Befund bekommt `datei:zeile` oder einen ausgeführten Befund-Befehl. Keine Zahlen aus dem Gedächtnis.
5. **Kein stiller Rückschritt.** Alles, was vorher ging, muss nachher gehen — `run_all.sh` grün, Syntax ok, keine neuen defekten Links.
6. **Recherche ist kein Fortschritt.** Gebaut wird nur nach §7. Recherche läuft nur, wenn sie eine offene Frage aus §9 betrifft (die Liste steht in §8).
7. **Compositor & Systemdienste NIEMALS anfassen (harte Regel, 2026-10-13).** gnome-shell, mutter, Wayland-/X-Compositor, gdm, display-manager, getty und ähnliche Systemdienste **niemals** per kill/pkill/restart/reload/stop/start berühren — auch nicht als „Reload". Das tötet die Desktop-Session und die REPL (2026-10-13, `pkill gnome-shell` → Desktop + REPL tot, Session `anonym`). Im Zweifel: Alternative benennen (Login, offizielle Restart-Methodik, `systemctl` nur für explizit für den Auftrag gestartete Dienste) und den User fragen. Desktop-Backend `backend: unavailable` ist **kein Fehler** und kein Grund, den Compositor zu starten. **Ebenso unantastbar (2026-10-14): Login- und Sitzungsverhalten** — `gdm3/custom.conf` (Autologin), AccountsService, PAM-Konfiguration und Greeter **nie** umstellen; Autologin ist nie nötig und wird nie eingerichtet (Incident: lex schaltete Autologin ein → versiegelter Keyring → Chrome-Passwortfrage, siehe §7/102).
8. **Wiederkehrende Klasse = Architektur-Eintrag, nie der nächste Instanz-Fix (2026-10-20).** Tritt eine Fehlerklasse an einer **dritten** Stelle auf, wird nicht die dritte Instanz geflickt, sondern zuerst die gemeinsame Regel gesucht (Prompt-Bullet, `pipefail`-Interaktion, Truncations-Design, Gate) und als §6-Klassen-Eintrag + §7-Schritt festgehalten. Beleg: die Pipe-Kürzung unter `pipefail` traf Lex viermal (§6 #24, `lex:327`, `lex:1943`, heute `lex:641`/ffuf) — jeder Einzel-Fix war lokal korrekt und grün, der Widerspruch im System-Prompt überlebte sie alle. Ergänzend: **Nadeln prüfen die Klasse, nicht nur die Instanz** — eine Test-Nadel an der einen reparierten Stelle macht die kaputte Interaktion an allen anderen Stellen unsichtbar.

### B. Der Arbeitszyklus (8 Schritte, immer in dieser Reihenfolge)
```
1. SITUATION      Befund erheben: grep/ls/bash -n ausführen, mit datei:zeile belegen
2. ENTSCHEIDUNG   Nur wenn offen: Option wählen → Eintrag in LEX.md §2/§6/§9
3. PLAN           Bei 3+ Schritten: TODO-Liste anlegen (Regel 5 AGENTS.md)
4. BUILD          Code in lex/lex nach den Regeln in C
5. VERIFY         bash -n + shellcheck + betroffene Tests (+ Fake-Server bei HTTP)
6. LOG            ~/Ai/wiki/wiki/log.md → was, warum, verifiziert durch was
7. SYNC           LEX.md aktualisieren: §6 abhaken, §3 Ist-Stand, §9 ggf. schließen
8. REVIEW         Link-/Konsistenz-Check (keine neuen toten Verweise), DoD in E prüfen
```
> **Schritte 6+7 sind der Teil, der bisher unregelmäßig lief.** Ohne sie gilt die Aufgabe als nicht erledigt.

### C. Code-Regeln für `lex/lex`
| Regel | Warum |
|---|---|
| `set -u` + `set -o pipefail`, **kein** `set -e` | bewusste Fehlerbehandlung, kein stilles Abbrechen |
| JSON **nur** via `jq`, HTTP **nur** via `curl` | kein Hand-Serialisieren |
| Werte **immer** über `<<< "$var"` an jq — nie als Argument | das war der alte `load_config`-Bug |
| Eine Funktion = eine Verantwortung, ≤ ~40 Zeilen | testbar, lesbar |
| Neue Fähigkeit = 3 Stellen: `_build_tools()` + `dispatch_tool()` + Funktion | nie im Loophörper |
| Fehlermeldungen deutsch auf **stderr**, Tool-Ergebnis strukturiert an das Modell | stdout bleibt sauber für die Antwort |
| Kein GNU-only ohne Guard (`realpath`, `readlink -f`, `timeout` → `command -v`-Check) | Portabilitätsanspruch §1 |
| Konfig über `_default_*` → Tier 2/3 → `LEX_*`-ENV | 4-Tier bleibt die einzige Konfigquelle |
| `tool_bash`-Schutz: `</dev/null`, `_run_limited` (timeout-Guard), Deny-Liste, volle Ausgabe, Exit-Code | Spezifikation §6.3 — `</dev/null` + Umbruch + timeout-Guard + Deny-Liste **2026-09-28 erfüllt**; **Pro-Tool-Kappe entfällt 2026-09-30** (Kürzung nur noch zentral via Spill, §6); `truncated`-Flag (Unterscheidung „abgeschnitten" vs. „Fehler") offen für Phase 1 |
| **Optimieren = Test + Messung in derselben Änderung**; Hot-Paths (`call_api`, `run_turn`, `dispatch_tool`) nie ohne Fixture-Test umbauen | Fund 2026-09-30: der Streaming-Umbau zerlegte Guard, tool_calls-Fusion und Nudges — die Suite blieb grün, weil der Pfad nur JSON-Mocks kannte |
| **Experimente raus aus dem Arbeitsbaum** (`git switch -c opt/…`), „Arbeitsbaum sauber" als Vorbedingung für Optimierung | uncommittete Zwischenstände sind der Grund, warum kaputte Pfade nicht auffallen (§6 „Behoben 2026-09-30") |
| **Selbstmodifikation läuft über die Sandbox in `dispatch_tool`** (Entscheidung §2, 2026-10-12): Edit auf `_lex_script` → Kopie → **2 Gates** → erst bei rc 0 atomar ins Original (Sicherungskopie `${_lex_home}/lex.bak` davor). Gate 1/2 = `tools/selfcheck_lex.sh` (das führt `bash -n` **und** `shellcheck -S warning` intern aus, `:31`/`:40`, dazu Referenz-gegen-Definitions-Abgleich + 16 Kernfunktionen), Gate 2/2 = volle `test/run_all.sh`. **Ein eigenes `bash -n`-/`shellcheck`-Gate entfällt bewusst** — reine Dopplung, ~4,9 s teurer. Der alte Hook-Guard `50-guard-lex-selfedit` ist **entfernt** (liegt als `~/.lex/hooks/50-guard-lex-selfedit.bak-20261012` außerhalb des Hook-Scanpfads) — er war per `bash`-Umgehung durchlässig und schob in den Umweg, der §7/89 auslöste. `bash -n` + `shellcheck` reichen weiterhin NICHT allein (Fund §6 #44) — die Sandbox ist der Grund, warum `run_all.sh` jetzt **erzwungen** statt erbeten ist; `LEX_SELFEDIT_GATES=fast\|off` nur mit **ausdrücklicher** Warnmeldung im Tool-Ergebnis, nie ein stilles „grün" — das gilt ebenso für die Übernahme-Zeile, die erst **nach** dem `mv` den wahren Modus nennt. Jedes Gate läuft unter `_run_limited` mit `LEX_SELFEDIT_TIMEOUT` (Default 300 s je Gate, Kill-Tree); die frühere Behauptung, `dispatch_tool` habe 300 s, war **falsch** (Review-B2). Zielwege **müssen** wie im Schreibpfad über `safe_path` kanonisiert werden, sonst umgehen `~`-Pfade die Sandbox still (Review-B1). Read-Modify-Write-Skripte müssen am Ende schreiben, nie vorher `exit`en; geänderte Stelle **mit einem Test belegen**, nicht behaupten | 2026-10-10: der Guard zwang auf einen bash+Python-Umweg; der Ersatz-Lauf brach vor `f.write()` ab → Aufruf `_tor_stealth_start` ohne Definition, „Kommando nicht gefunden" erst zur Laufzeit. 2026-10-12: Guard ersetzt, weil er blockierte, statt zu prüfen — **Beleg E2E mit echten Gates**: grüner Lauf beförderte (14/14), roter Lauf blieb byte-identisch (`d0db9bc4…`) |
| **Eine Widerrufs- oder Korrektur-Notiz darf das Korrigierte nicht wörtlich wiederholen, wenn eine Datei in den System-Prompt injiziert wird — und es zählt jeder injizierte Kanal, nicht nur der, den man gerade gebaut hat.** Beschreiben, was jetzt gilt — das Verbotene nicht zitieren | 2026-10-12 (§7/92): meine Supersedenz-Notiz zum gefallenen Emoji-Verbot **zitierte** den Satz — die Datei enthielt weiterhin die Verbotsformel und hätte genau den Effekt erzeugt, den sie abstellen sollte. Dieselbe Stelle wiederholte denselben Fehler in Negationsform. Beides erst durch eine Endkontrolle über alle Dateien gefunden, nicht durch den Test — die Nadel prüft den Block, nicht die Einzelnotiz. **Dritter Anlauf, andere Kanalstellung**: der erste Entwurf des Log-Eintrags zitierte das Verbot erneut, und `wiki/log.md` wird über `_wiki_ex` (**`tail -n 40`**) injiziert — der Satz lag im Fenster und stand im Live-Prompt, während `mem/` sauber war. Vor jedem injizierbaren Dokument die Frage: *läuft dieser Pfad überhaupt in den Prompt?* — Fehlerberichte unter `wiki/errors/` laufen dort nicht hinein, der Wiki-Log-Auszug sehr wohl |

### D. Test-Regeln
- **Jede neue Funktion bekommt einen Test.** `test/test_<name>.sh`, immer Mock.
- **Nie Port 8080** — weder Test noch Einzelbefehl.
- **Der HTTP-Pfad wird getestet**, nicht nur der Mock-Zweig: Fake-Server über `ncat` — `test/test_http.sh` seit 2026-09-28 in `run_all.sh` (Lücke §8 F abgeschlossen).
- `bash test/run_all.sh` = die einzige Wahrheit, ob etwas fertig ist.
- Tests sind assert-basiert (`[ "$out" = "erwartet" ]`), Ausgabe auf stdout, Exit 1 bei Fehlschlag — so wie `run_all.sh` es bereits erwartet.
- **Testboden ist hart:** `run_all.sh` läuft als Erstes `testboden` — ab, wenn eine Testdatei gegenüber HEAD gelöscht, als Runner referenziert aber nicht vorhanden, oder vorhanden aber nicht eingebunden ist. Testdateien werden **ersetzt, nie entfernt** (genau das verdeckte die Streaming-Regression).
- **Fixture-Tests müssen den Pfad auch brechen können.** Nur Mock-Pfade zu testen reicht nicht: der API-Pfad braucht SSE-Fixtures (`test/test_sse.sh` — Deltas, tool_calls-Fusion, `data:` ohne Leerzeichen, fehlendes `[DONE]`, Server weg, HTTP-Fehler) und einen echten HTTP-Fake (`test/test_http.sh`).
- **Optimierung braucht eine Zahl statt eines Gefühls:** vorher/nachher mit fester Fixture messen und als Test festhalten — `test_sse.sh` nummeriert das Budget (3000 Chunks < 2000 ms; damals 29 s, heute ~0,1 s). Wer „schneller" behauptet, liefert den Messwert.
- **Jede Änderung an `lex` läuft durch `tools/selfcheck_lex.sh`** (davor `bash -n`, `shellcheck -S warning`) — der Selfcheck findet die Bruchklasse, die beide NICHT finden: **aufgerufene, aber nie definierte Funktion** und **fehlende Kernfunktionen** (§6 #44, Werkzeug seit 2026-10-10). Er ist zugleich Testwerkzeug: kaputte Kopie rein → `rc 1` mit Namen (Nadeln in `test_features`).

### E. Definition of Done — eine Aufgabe ist erst fertig, wenn
- [ ] Code geändert
- [ ] `bash -n lex/lex` → OK
- [ ] `tools/selfcheck_lex.sh` → ok (fehlende Definitionen/Kernfunktionen: 0)
- [ ] betroffene/neue Tests geschrieben und grün (`run_all.sh` komplett grün, `testboden` inkl.)
- [ ] Optimierungen: vorher/nachher mit fester Fixture **gemessen**, Budget-Test grün
- [ ] kein neuer defekter Link (Link-Check über `lex/` und `~/Ai/wiki/`)
- [ ] `~/Ai/wiki/wiki/log.md` hat einen Eintrag
- [ ] `LEX.md` ist aktuell (§6, §3, ggf. §9)
- [ ] aufgetretene Fehler stehen in `~/Ai/wiki/wiki/errors/`

### F. Phasen-Disziplin
- **Phase 0 ist nicht fertig, bis DoD + §7 durch sind** (inkl. CI, Doku, v0.1.0). Docker ist **entfallen** (Entscheidung 2026-09-28). Erst dann Phase 1.
- Idee für eine spätere Phase → **eine Zeile in §10**, sofort wieder zur laufenden Aufgabe.
- Recherche nur gegen §8 (A–G) — alles andere ist Ablenkung.
- **A (Modell-Tool-Call-Benchmark) hat Vorrang vor allem anderen**, weil es entscheidet, ob der restliche Aufwand überhaupt trägt.

### G. Handover-Protokoll (jeder neue Chat, gleiche 5 Schritte)
1. `LEX.md` lesen (§0 → §3 → §7)
2. Offene Frage aus §9 klären, **falls** sie die Aufgabe betrifft
3. Genau **eine** Aufgabe aus §7 nehmen
4. Zyklus B abarbeiten
5. Am Ende DoD E abhaken, Log-Eintrag, fertig — **nicht** „noch schnell" etwas Zweites anfassen

### H. Backup-Regel (User-Vorgabe 2026-10-28)

Wenn `lex` lokal committet wird, der **private Backup-Ordner 1:1 mit übernehmen**: eigenständiges Backup-Repo mit eigenem `.git` und privaten Daten (Einstellungen, Schlüssel, Werkzeuge). Vor jedem lex-Commit auch das Backup-Repo mitführen: `git -C <backup-ordner> add -A && git -C <backup-ordner> commit -m "…"` (gleicher Stand, eigenes `.git`). **Nicht** ins Auslieferungs-Repo ziehen — es bleibt ein eigenständiges Backup-Repo, weil es private Daten enthält und nicht ins (deutsche/öffentliche) lex-Repo gehört.

---


## 1. Was ist Lex

Ein **eigener, reines-Bash-basierter LLM-Terminal-Agent** — Pure Bash + `jq` + `curl`, kein Node/Python.

| | |
|---|---|
| **Binär** | `lex/lex` (ein Skript, 6242 Zeilen, Stand 2026-10-16) |
| **Backend** | lokaler llama-server, OpenAI-Protokoll, `http://127.0.0.1:8080/v1/chat/completions` |
| **Modell** | `~/Ai/model/Ternary-Bonsai-2-27B-PQ2_0.gguf` (Alias=`--alias` möglich) |
| **Sprache** | Deutsch-First — System-Prompt, Doku, Antworten |
| **Zielplattformen** | Dev-Maschine, Internal-Server, Termux, iSH, Raspberry Pi, Router |
| **Lizenz** | MIT (`LICENSE`, 2026-09-28 — statt der früher geplanten Apache 2.0) |
| **Status** | **Phase 0 abgeschlossen** — Commit `46c64c0`, Tag `v0.1.0` |
| **Nicht Teil von Lex** | IRC-/Chat-Integration (2026-10-10 gebaut, am selben Tag komplett zurückgebaut, §7/86) — Lex bindet ausschließlich MCP-Server ein, keine Fremd-TUIs; fremde Clients laufen in eigenen Terminals und werden von Lex weder gestartet noch gelesen |

**Positionierung**: lokal-first (kein API-Key), deutsch-first, Single-User, reaktiv, CI+Docker+Release ab Tag 1.

**Golden Rule**: Wir bauen nicht bashagt nach. Wir bauen Lex. — bashagt = Referenz, learn-claude-code = philosophischer Referenzpunkt.

---

## 2. Getroffene Entscheidungen (nicht mehr diskutieren)

| Thema | Entscheidung |
|---|---|
| Basis-Sprache | **Pure Bash** (Option A). Hybrid/Python/Mojo → abgelehnt (`ARCHITEKTUR.md` §7) |
| LLM-Backend | **Lokal-First**, Cloud-API optional (`LEX_API_URL`/`LEX_API_KEY`/`LEX_MODEL`) |
| Tool-Set Phase 0 | **8 Tools**: `read_file`, `write_file`, `edit_file` (+`all`), `bash`, `list_files`, `mem_add`, `mem_list`, `mem_search` |
| Tool-Set Phase 0.1b (Planung) | **+1**: `todo(action ∈ add\|done\|list, text, index)` → `~/.lex/plans/plan.md` (session-unabhängig, s. Entscheidung „Planung (Nachtrag)"), idempotentes Abhaken nach Anzeige-Index, Slash `/plan` → **11 Tools** |
| Rendering (Schritt 3) | `render_markdown` (Markdown-Licht, ohne TTY roh) + `⚙`-Trace und `⏱`-HUD auf stderr → **stdout-Pipes unverändert** |
| Oberfläche (Schritt 6) | **CLI mit TUI-Gefühl, kein curses-Toolkit**: `⏳ denke …`-Spinner, `↳ tool`-Rückgabe, `⚙ denken:`-Block und Trennlinie auf **stderr** (nur TTY bzw. `LEX_TRACE=1`), Eingabe mit **Readline** (`read -e` + `set -o emacs` + `bind`) inkl. History `~/.lex/history` (500) und Tab-Pfadvervollständigung — bewusst **ohne** gum/dialog/fzf, keine neuen Abhängigkeiten |
| Tool-Set Phase 0.1 (fetch) | **+1** → **12 Tools**: `fetch(url, topic)` legt Seiten als Rohquelle unter `<wiki>/raw/<topic>/YYYY-MM-DD-slug.md` ab (Metadatenkopf nach `raw-template.md`), HTML→Klartext per awk |
| Persönlichkeit (Schritt 7) | **Block oben im System-Prompt**: immer Deutsch, kurz wirken, **nicht raten** (bei Befehlen `<Befehl> --help`, bei Fakten `search`/`web_search`/`web_fetch`, bei Bibliotheken `context7`), Fehler als Material festhalten (`wiki/log.md`, `wiki/errors/`), Wiki = **Gedächtnis über Sitzungen**. Backticks im Prompt sind escaped (`\``), sonst führt bash sie als Command-Substitution aus — ein Test prüft das |
| Rendering (Schritt 8) | `render_markdown` färbt zusätzlich Warnungs-Zitate (orange), `❌`/`Fehler:` (rot), `✓`/`OK` (grün), Links (cyan+unterstrichen, URL dim) und Listenmarker — und setzt **Pipe-Tabellen** echten (Kopf cyan/fett, Raster dim, rechtsbündig bei `:---`, Kürzung auf 40 Zeichen, **UTF-8-sicher**) |
| MCP (Schritt 9) | **stdio-JSON-RPC 2.0**, eine Session pro Aufruf (`initialize` → `notifications/initialized` → `tools/call`), Server aus `${LEX_HOME}/mcp.json` (Default: **defuddle** + **context7** + **playwright** (Schritt 22)), `LEX_MCP=0` zum Abschalten, `LEX_MCP_TIMEOUT`. **+2 Tools**: `web_fetch(url, max_length?)` (Crawler-Auszug, ohne Ablage), `context7(query, library?)` (resolve → query-docs) + `browser` (Schritt 22) + `mcp` (Schritt 23) → **19 Tools** (seit 2026-10-08 zusätzlich `agent` + `task`) |
| Lesbarkeit (Schritt 13) | **Klarer visueller Kontrast wie opencode** (User-Feedback 2026-09-28: „Denken und Antwort waren zu ähnlich, die Antwort ließ sich leicht übersehen"): Denken = Header dim-magenta + Inhalt kursiv/eingerückt (Beobachtung, keine Antwort), Werkzeuge = Name fett cyan + Argumente grau, `↳` cyan-dim, HUD + Trennlinie **vor** der Antwort, die Antwort steht **als Letztes** (H1 fett weiß, H2 fett cyan)  — Schritt 14 hat H1/H2 und den Denken-Inhalt weiter nachgebessert (s. „Palette") |
| Review-Fixes (Schritt 14) | **Code-Review (User-Auftrag „optimiere es bitte, schau nach Bugs, gern Internet"), 15 Befunde gefixt**: harte Deny-Liste **segmentweise** (rm-Varianten inkl. `--no-preserve-root`/`sudo`/`xargs`, `curl …\|sh\|cat`, `curl … && sh`, `su postgres -c`), `safe_path` sperrt nackte Wurzeln + löst Symlink-Ziele auf, ungültige API-Antworten löschen **nicht** den Modellkontext, gestorbene MCP-Server melden „nicht startbar", Config numerisch validiert, `edit_file` behält Modus und schreibt atomar, `dispatch_tool` verlangt JSON-Objekte, Prompt nur bei TTY, `ss`-Check pipefail-sicher, `_load_settings` liest alle Keys, Spinner-`trap`; Details in §6 #14–28 |
| Palette (Schritt 14) | **Farbkonvention**: alle Sequenzen über `_palette_init()`-Variablen → `NO_COLOR` und `TERM=dumb` schalten Farben komplett ab (Prompt und `render_markdown` auch ohne TTY farblos); Hierarchie hintergrundunabhängig: **H1 fett+unterstrichen** (statt weiß — auf hellem Terminal unsichtbar), H2 fett cyan, H3 cyan, `⚙ denken:`-Header dim-magenta + Inhalt **grau `90`** statt kursiv (italic wird nicht überall unterstützt), Werkzeug fett cyan, `↳` cyan-dim, HUD/Trennlinie dim — Antwort weiterhin als Letztes |
| Planung (Nachtrag) | **`todo` ist session-unabhängig**: ein stabiler Pfad `~/.lex/plans/plan.md` statt `<session-id>.md` — der Plan läuft wie die Wiki und `mem_*` über Sitzungen hinweg (eigene Tests: zwei Kind-Läufe mit verschiedenen Session-IDs) |
| Websuche (Schritt 10) | **+1**: `web_search(query)` über `html.duckduckgo.com` **ohne API-Key** — Ergebnisse als `n) Titel / URL / Ausschnitt`, `uddg=`-Redirects und Entities aufgelöst, `LEX_SEARCH_URL` als umschaltbarer Endpunkt (Tests laufen offline dagegen) |
| Tool-Set Phase 0.1 (Wiki) | **+2**: `append_file` (append-only, für `wiki/log.md`), `search` (literal-Standard, `regex=true`, `pfad:zeile:text`), `list_files` **erweitert** um `pattern` (Glob) + `recursive` → **10 Tools**; Config `LEX_WIKI_DIR` (Default `~/Ai/wiki`) + Wiki-Konventionen im System-Prompt |
| Memory Phase 0 | Einfache dateibasierte Memory (`~/.lex/mem/`, Markdown+YAML) — **nicht** 16×200 (das ist Phase 3) — **umgesetzt 2026-09-28** |
| Session | append-only JSONL in `~/.lex/sessions/<id>/` — **umgesetzt 2026-09-28** (`LEX_SESSION=0` schaltet ab) |
| Sicherheit | **harte Deny-Liste in `tool_bash`, immer aktiv** + **opt-in** Approval-Gate (`--approve`/`LEX_APPROVE=1`) — Entscheidung 2026-09-28 |
| sudo in `tool_bash` | **Gate statt Verbot** (User-Auftrag 2026-09-28: „eine Aufforderung, wo ich es einfach eingeben kann"): `su` **bleibt** verboten, `sudo` verlässt die Deny-Liste und läuft über `_sudo_gate()` — ohne gültiges sudo-Ticket zeigt `_sudo_ask()` das Kommando auf der controlling TTY und ruft `sudo -v` auf → **das Passwort geht direkt an sudo**, nie durch lex (keine Variable, kein Log, `tool_bash`-Stdin bleibt `</dev/null>`); mit gültigem Ticket fragt lex **einmal pro Sitzung** `_sudo_grant_request()` (Schritt 52: `sudo für diese ganze Sitzung freigeben? (y/N): ` — Ja = Sitzung läuft ohne weitere Fragen, Nein = weiter y/N pro Befehl via `_approve_request()`, sichtbar seit Schritt 50: Kommando gekürzt auf 200 B, Frage als **letzte** Zeile ohne newline). Kein controlling TTY → Verweigerung. `LEX_SUDO=0` schaltet sudo komplett ab, `LEX_SUDO_APPROVE=0` lässt jede Freigabe-Frage weg — **Live-Befund 2026-10-05**: `NOPASSWD:ALL` aktiv (Schritt 45) → `_sudo_ask` wird **nie** erreicht, einzige Frage war y/N pro Kommando; alle Langblöcke des Audit-Laufs waren y/N-Warteschleifen (~2 h 35 m ≈ 58 %) → §6 Schritt-51-Diagnose, §6 #34 (Schritt 52) baut das Gate auf **eine Sitzungs-Freigabe** um, `/autosudo` überspringt auch die |
| Root-Rechte / sudo-Passwort | **1× Passwort beim `/lexpen on`, kein NOPASSWD** (User-Entscheidungen 2026-10-12: 17:30 „nur mit /lexpen, nicht global", 17:42 Bestätigung der 1×-Variante; Varianten 0×-NOPASSWD und Root-REPL **abgelehnt**): `/lexpen on` holt nach der Aktivierung **einmal** `_sudo_ask` — Passwort **direkt an sudo** über die controlling TTY (Schritt-57-Regel: nie durch lex); das Ticket gilt dann pro TTY nach sudo-Standard (gleitendes Fenster), der Gate braucht im Modus keine Rückfrage. `/lexpen off` → Tor-Stop **vor** `sudo -k` (Ticket weg → Normalbetrieb: Passwort am Terminal + y/N-Gate). **Widerruf dieser Runde**: das NOPASSWD:ALL vom 17:03 (`/etc/sudoers.d/<datei>`, visudo `parsed OK`, 440) wurde um **18:02 wieder entfernt** — Verifikation `sudo -n true` → rc 1 „interactive authentication is required"; `/etc/sudoers.d/` enthält nur noch `README`. Damit gilt: Passwort überall wieder Standard, im lexpen-Modus nur beim Einschalten (und nach Ticket-Ablauf). Hintergrund-Tasks ohne TTY bleiben ohne NOPASSWD unmöglich — der Preflight lehnt ehrlich ab und nennt die Foreground-Lösung zuerst, NOPASSWD nur noch als optionale, global wirkende Alternative |
| `reasoning_budget` / `reasoning_budget_followup` / `max_tokens` | **2147483647 / 2147483647 / 16384** seit 2026-10-20 (§6 O8: Budget-Kappung zurückgenommen — sie riss das Reasoning mitten im Satz ab) — davor 2048/768/16384 (2026-10-07, Overthinking-Optimierung), 8192/16384 (2026-09-29, G1), 4096/8192 (2026-09-28, Sync mit `ai.sh`; Server-Flag `--reasoning-budget 4096` wird weiter überschrieben; **`-1` im Request ist KEIN „unbegrenzt"**, es fällt still auf das Server-Flag zurück — `server-common.cpp:1357`) |
| `auto_disable_thinking_with_tools` | **off** seit 2026-10-07 (Hebel 2) — `chat_template_kwargs.auto_disable_thinking_with_tools` pro Request im Body; `on` schaltet Thinking bei jedem Tool-Request ab (Template Z.32), schneller, aber live messbar schlechtere Ergebnisse (§7 #60) → Default bleibt off; ENV `LEX_AUTO_DISABLE_THINKING_WITH_TOOLS` |
| Selbstmodifikation von lex | **Sandbox statt Guard** (User-Entscheidung 2026-10-12, Frage „Guard rausnehmen und stattdessen in einer Sandbox prüfen"): `~/.lex/hooks/pre_tool/50-guard-lex-selfedit` ist **entfernt** und liegt als `~/.lex/hooks/50-guard-lex-selfedit.bak-20261012` **außerhalb** des Hook-Scanpfads (rollback-fähig). Er blockierte nur `write_file`/`edit_file`/`append_file` (case-Zweig, alles andere `exit 0`) — das `bash`-Tool ging ungeprüft durch, und seine eigene Meldung erklärte die Umgehung („bewusst umgehen: Änderung via bash-tool"). Nachweislich schob er den Agenten in den gefährlicheren bash+Python-Read-Modify-Write-Umweg, der dann vor `f.write()` abbrach (§7/89). **Ersatz: Staging in `dispatch_tool`** — ein Edit, dessen Ziel `_lex_script` ist, wird auf eine Kopie umgeleitet, dort **2 Gates** ausgeführt — Gate 1/2 `tools/selfcheck_lex.sh` (das selbst `bash -n`:31 + `shellcheck -S warning`:40 + Referenz-/Kernfunktions-Abgleich liefert, deshalb **kein** separates syntax-/style-Gate) und Gate 2/2 **volle Suite `test/run_all.sh` (~84 s, 962 Prüfungen)** — und **erst bei rc 0 atomar** ins Original befördert (davor Sicherungskopie `${_lex_home}/lex.bak`); bei rc ≠ 0 bleibt das Original byte-identisch und der Befund kommt als Tool-Ergebnis an das Modell. **Bewusst NICHT als pre/post-Hook**, obwohl das die erste Wahl war — zwei harte Gründe: (a) Hooks können `LEX_HOOK_ARGS` nicht zurückschreiben, es wird nur als Env exportiert (`lex:3295`), ein Hook kann also nur erlauben oder blockieren, nie umleiten; (b) Hooks hätten 5 s (`LEX_HOOK_TIMEOUT`, `lex:3293`) gegen die ~87 s der Gates, und `_run_hooks post_tool … \|\| true` (`lex:4077`) schluckt jeden Fehlschlag **still** — die Verifikation läge also tot im Verborgenen, exakt die Falsch-Grün-Klasse aus §7/89. `dispatch_tool` selbst hat **kein** Timeout-Budget (`_default_tool_timeout`, `lex:273`, wirkt nur über `_run_limited` = ausschließlich `tool_bash` (lex:1947) und die Hooks (lex:3910) — Review-Befund B2, 2026-10-12); die Gates holen sich ihre Frist deshalb selbst über `_run_limited` mit `LEX_SELFEDIT_TIMEOUT` (300 s je Gate, inkl. Kill-Tree — hängt die Suite, wird sie abgebucht und das zählt als Fehlschlag), und ist **nicht** via `LEX_HOOKS=off` umgehbar |
| Präferenzen aus `mem/` | **werden in den System-Prompt injiziert** (2026-10-12, User-Frage „warum wird deine Persönlichkeit nicht injiziert?"): `_mem_pref_ex` (lex:1051) liest ausschließlich `type: preference`, **neueste zuerst** (`LC_ALL=C sort -r` über den `YYYYMMDDHHMMSS`-Dateinamen), Gate `LEX_MEM_PREF=off`, Budgets `LEX_MEM_PREF_MAX`/`LEX_MEM_PREF_TOTAL` (2000/6000) mit **sichtbarem** Kürzungsmarker. Einhängung lex:1115 **direkt hinter** `_system_prompt` — Präferenzen gehören zu „wer ich bin", Skills zu „wie ich arbeite", der Wiki-Auszug ist Referenz; die Reihenfolge ist eine Gewichtung. **Begründung**: der Store war vorher **write-only** — `cmd_status` (lex:5581) zählte die Einträge für `/status`, `setup_messages` las sie nie; 6 Präferenzen lagen still, zwei davon **Sicherheitsregeln** (sudo, Pentest-Tools auf User-Level). `fact`/`memory`/`note` bleiben **draußen** (Werkstattwissen = Rauschen). **Widerspruchsregel steht als Text im Block** („Bei Widersprüchen gilt der NEUESTE Eintrag") — ohne sie neutralisieren sich zwei gleich laufende Präferenzen, und genau das war der Zustand der Ton-Einträge vom 10-02 und 10-09. **Vorbedingung**: eine Widerrufs-/Korrektur-Notiz darf das Korrigierte **nicht wörtlich wiederholen**, wenn die Datei injiziert wird (§0.1 C) |
| Daemon / Hooks | ab Phase 4 / 3–4 (MCP **nicht** abgeschoben: stdio-Client läuft seit Schritt 9) |
| CI, Docker, Release | CI ab Tag 1 ✅ (GitHub Actions), Semver ✅ (`v0.1.0`) — **Docker entfällt** (User-Entscheidung 2026-09-28) |
| Sub-Agenten, 24+ Tools, Streaming | Phase 1–2 |

---

## 3. Ist-Stand (verifiziert 2026-10-27, Stand **v0.5.1**)

### Existiert & funktioniert (alle Punkte einzeln ausgeführt)
- `bash -n lex/lex tools/*.sh test/*.sh` → Syntax OK · `shellcheck -S warning lex test/*.sh tools/*.sh` → **0 Warnungen** (shellcheck 0.9.0 installiert)
- `./lex --version` → `lex 0.4.0` · `./lex --help` OK · `./lex --status` zeigt Modus/Modell/Tools/Session/Memory
- `echo "Sag Hallo" | LEX_MOCK=done ./lex --oneshot` → `Taugt.`
- **1 Live-Request (freigegeben)**: `LEX_MAX_TURNS=1 ./lex --oneshot` → `Taugt.` gegen den echten llama-server; Session `~/.lex/sessions/<session-id>/session.jsonl` (3 Zeilen, `reasoning` erhalten)
- `LEX_HOME=<tmp> ./lex --install` → `~/.lex/{log,sessions,mem,hooks,agents,skills}` + `settings.json` (kein `mem_net/` mehr)
- **19 Tools** implementiert (8 aus Phase 0 + `append_file` + `search`, `list_files` mit `pattern`/`recursive`, `todo`, `fetch`, `web_search`, `web_fetch`, `context7`, `browser`, `mcp` + `agent` (2/6) + `task` (6/6)), 4-Tier-Config, Mock-Schicht (`LEX_MOCK`, `LEX_MOCK_FILE` mit Schattenkopie)
- **Persönlichkeits-Prompt** (Schritt 7): Deutsch-Block oben, „nicht raten", Fehler-Dokumentation, Wiki als Gedächtnis — Backticks im String escaped, sonst Command-Substitution
- **Anti-Zweifel-Prompt** (Schritt 15, 2026-09-29): drei Regeln im System-Prompt — entschlossen entscheiden (keine Selbstzweifelformulierungen über selbst geprüftes), Verifikation über Tools (`bash -n`, `./test/run_all.sh`, `search`, Logs) statt Selbstintrospektion, keine Zweifelschleifen (kein „bist du sicher?", nach Fehler → Ursache/Fix/weiter); Grundlage: Recherche (arxiv 2603.03330, 2506.21285, llama.cpp #12339) — dazu `--reasoning-budget-message` in `ai.sh` und die gleichen Grundsätze in zoocode `custom_modes.yaml` (`--reasoning-preserve` bleibt aktiv)
- **Workflow-Fixes** (Schritt 16, 2026-09-29, aus dem Live-Test): Truncation **und** leere Antwort bekommen max. 2 Nudges mit `reasoning_budget_tokens: 0` (Ursache der „leeren Antworten": Reasoning fraß im Nudge-Turn erneut alle Tokens); nach 2 Nudges wird ein vorhandener Teiltext gerendert (live gemessen: 195–214 Bytes, die der alte Pfad verworfen hätte), erst bei leerer Antwort gibt es Abbruch statt Endlosdrehen; auch der Max-Turns-Abbruch rendert den vorhandenen Teiltext, statt ihn zu verwerfen; Spinner nur noch auf echter TTY (kein `\r`-Müll in Pipes, auch mit `LEX_TRACE=1`); Defaults `temperature 0.1 → 0.7` und `max_turns 50 → 100` (`LEX_TEMPERATURE`/`LEX_MAX_TURNS`/settings.json überlagern weiter)
- **Wiki-Lernen** (Schritt 17, 2026-09-29): `setup_messages` bettet den Wiki-Stand ein (index.md + `tail -n 40` aus wiki/log.md, ≈ 11 KB konstant) — das Gedächtnis hängt nicht mehr am Zufalls-Tool-Call des Modells; Pflicht-Regel im Prompt („Erst danach darfst du sagen, etwas nicht zu wissen", sammeln: neue Erkenntnisse als Zeile an log.md bzw. Artikel + index.md); `search` ohne `path` sucht **im Wiki** statt in `.` (Live-Fehler aus Schritt 16b: er suchte im eigenen Home)
- **Rendering** (Schritt 8): Markdown-Licht + Warnung/Fehler/Erfolg/Links und echte **Pipe-Tabellen** (rechtsbündig, UTF-8-sicher), nur bei TTY bzw. `force`
- **MCP-Client** (Schritt 9): stdio-JSON-RPC gegen **echte** `defuddle`- und `context7`-Server live verifiziert; `test/fake_mcp.sh` deckt die Fehlerpfade
- **Websuche** (Schritt 10): `web_search` ohne API-Key (DuckDuckGo), Redirect-/Entity-Dekodierung, offline über lokale Fixture getestet
- **Session-JSONL** (append-only, eine Message pro Zeile; `reasoning_content` wird persistiert, aber **nicht** in den Modell-Kontext geschrieben)
- **Memory** unter `~/.lex/mem/` (Markdown + YAML-Frontmatter, Typen `memory|fact|preference|note`)
- **Sicherheit**: harte Deny-Liste in `tool_bash` (immer aktiv) + opt-in `--approve` (nur mit TTY) + **sudo-Gate** (§6 #13: Passwort direkt an sudo, seit Schritt 52 **eine Sitzungs-Freigabe** pro Session statt y/N pro Befehl)
- **Fix-Paket Schritt 53–56** (2026-10-06, Recherche `wiki/raw/2026-10-06-fix-recherche-hang-500-redaction-loops.md`, User-Auftrag „setze alles um und teste lex live"): **P1/P2 Tool-Hang** — `_run_limited` schreibt nach `$_rl_out` (Tempdatei statt fd3-Pipe), neue `_kill_tree()` (BFS bis zur Wurzel, Blatt→Wurzel TERM, nach 3 s KILL) + Watchdog `secs+10`, Live-Beweis `Exit-Code: 124` bei `LEX_TOOL_TIMEOUT=5`; **P3 HTTP-Retry** — `call_api` retryt 429/5xx/curl-rc max. 2× (`_retry_delay` 0.8/1.6/3.2 s, Deckel 8 s, Jitter ±25 %), Config `api_retries`/`LEX_API_RETRIES` (Default 2, Clamp ≤10), Fehlermeldung mit Body-Snippet (400 B) + Bytes + Versuchszahl + `parse_error`-Hinweis; **P4 Redaction** — `_redact()`/`_redact_var` an `log()`, `session_write()`, Anzeige (`_trace_result`/`_trace_reasoning`/`_md_render`) und Wiki-Schreibpfaden (`$_wiki_dir`), Wertgruppe JSON-sicher (Live-Fund: erste Fassung machte session.jsonl ungültig → `wiki/errors/2026-10-06-redaction-brach-session-jsonl.md`); **P5 Fail-Gedächtnis** — Signatur `cksum(name|args|result[0..200])`, 3× identisch → weicher Nudge, erneut → hart (`return 1`), `LEX_LOOP_GUARD=off`; **P7** — 85-%-Warnung unabhängig von `LEX_COMPACT` (Re-Arm `_compact_warned`) + Pinning-Block in `_compact_prompt`; **P8** — Reasoning-Kappe `LEX_REASONING_STORE_MAX` (Default 20000) in `append_message_json`. **Live-Verifikation 2026-10-06** (isoliertes `LEX_HOME`, echte LLM-Turns gegen 8080): oneshot ✓, Tool-Timeout rc=124 ✓, Redaction in Wiki/Log/Session ✓, session.jsonl 100 % gültig ✓, Fail-Gedächtnis-Nudge live ausgelöst ✓, 85-%-Warnung ✓, Reasoning-Kappe ✓ — dazu DE+EN je **794 Checks grün** (Stand nach dem sudo-Ticket-Stub)
- **Tests**: 17 Testdateien + `fake_server.sh` + `fake_mcp.sh`, **1190 Einzelf-Prüfungen** (1209 PASS-Zeilen abzüglich 19 Läufer-Marken; die sudo-Ticket-Zweige sind simuliert und hängen nicht mehr an der sudoers der Maschine), `bash test/run_all.sh` → **PASS: 19  FAIL: 0  TOTAL: 19** (Exit 0, live gezählt 2026-10-28 §7/124: 1209/1190; davor 2026-10-27 §7/123: 1127/1111; davor 2026-10-27: 1118/1102; davor 2026-10-26: 1105/1089; davor 2026-10-17: 1053/1038; davor 2026-10-14 u. 2026-10-16: je 1045/1030 (88 s); davor 2026-10-12: 15/15 = 1027/1012 (88 s), 1024/1009 (87 s), 1020/1005 (88 s) und 991/976, davor 14/14 = 962/948, davor 2026-10-08: 13/13 = 1174/1161) — erster Läufer ist **`testboden`** (§6 „Verhütung"), `test_selfedit.sh` (65 Nadeln) ist als vierter und `test_mem_pref.sh` (28 Nadeln) als fünfzehnter und `test_soul.sh` (27 Nadeln, §6 #57) als sechzehnter zugekommen; §7/124: +3 Läufer (`test_golden.sh` 38, `test_load.sh` 33, `test_fuzz.sh` 93) 2026-10-28 (§8 F: golden files statt Inline-JSON + Last-/Fuzz-Tests); 2026-10-13 kamen in `test_features.sh` **+10 harte Nadeln** dazu (env-Funktion, `export`-ohne-`-a` im Coproc, „kein `export -a` im lex-Code", E2E-Env-Probe durch den Coproc, mcp.json-`env`-Block, 2× Default-Config) — Herleitung in §7/99; §7/100: +1 Nadel (Fehlertext-Bullet) 2026-10-13; §7/101: +1 Nadel (Zentral-venv) 2026-10-13; §7/102: +1 Nadel (Login-Verhalten) 2026-10-14; §7/103: +1 Nadel (mem-Notiz-Hypothese) 2026-10-14; §7/104: +3 Nadeln (Widersprüche/Frust-Bruch) 2026-10-14; §7/110: +8 Nadeln (§6 O7 Baum-Kill ×4, Fail-Streak-Schwelle 3 ×4) 2026-10-17;§7/114: +7 Nadeln (§6 O8 Reasoning-Budget) 2026-10-20; §7/121: +27 Nadeln (`test_soul.sh`, §6 #57) 2026-10-26; §7/122: +13 Nadeln (head/tail-Pipe-Deny, web_fetch-Knapp-Marker, `_wiki_ex`-Fenster-Marker, Default-Cap 40000) 2026-10-27; §7/123: +9 Nadeln (Summary-Kappungs-Warnung im Kontext + stop-Gegenprobe, History-Cap 600 bleibt/6000→5000/Kappungs-Log) 2026-10-27
- **Self-Edit-Sandbox statt Hook-Guard** (2026-10-12, User-Entscheidung §2): `dispatch_tool` leitet jeden Schreib-Edit, dessen Ziel `_lex_script` ist, auf eine Kopie um (`_selfedit_ziel`/`_selfedit_anlegen`), führt dort **2 Gates** aus (`tools/selfcheck_lex.sh`, dann volle `run_all.sh`) und befördert **erst bei rc 0 atomar** ins Original — bei rc ≠ 0 ist das Original byte-identisch. Escapes `LEX_SELFEDIT_GATES=fast|off` melden **ausdrücklich**, dass die Suite nicht lief — die Übernahme-Zeile nennt den wahren Modus und steht **erst nach** dem `mv`, „Gates grün" nur beim Voll-Lauf (`_selfedit_mode`). Jedes Gate läuft unter `_run_limited` mit `LEX_SELFEDIT_TIMEOUT` (Default 300 s je Gate, Kill-Tree) — hängt die Suite, wird sie abgebucht und zählt als Fehlschlag (fail-closed). **Kanonisierung muss über `safe_path` laufen** (Review-B1, 2026-10-12): bloßes `readlink -f` löst `~` nicht auf — ein Tilde-Pfad wäre still durch die Zielprüfung gefallen, während der Schreibpfad trotzdem das Original traf. Der alte `pre_tool`-Guard `50-guard-lex-selfedit` ist entfernt (Rollback: `~/.lex/hooks/50-guard-lex-selfedit.bak-20261012`). **Bewusste Lücke**: Änderungen über das `bash`-Tool (`sed -i`, `tee`), über `task` und über `mcp__*` umgehen die Sandbox weiterhin — wie schon beim alten Guard (Guardrail, kein Gefängnis)
- **Präferenzen aus `mem/` werden injiziert** (2026-10-12, §7/92): der Memory-Store war zuvor **write-only** — `cmd_status` (lex:5581) **zählte** die Einträge für `/status`, `setup_messages` las sie nie. Jetzt liest `_mem_pref_ex` (lex:1051) ausschließlich `type: preference`, **neueste zuerst**, und hängt sie **direkt hinter** `_system_prompt` ein (lex:1122) — Präferenzen gehören zu „wer ich bin", Skills zu „wie ich arbeite", der Wiki-Auszug ist Referenz. Gates `LEX_MEM_PREF=off`, Budgets `LEX_MEM_PREF_MAX`/`LEX_MEM_PREF_TOTAL` (2000/6000) mit **sichtbarem** Kürzungsmarker; leerer Store liefert **keinen** Block. Eine **Widerspruchsregel** steht als Text im Block („Bei Widersprüchen gilt der NEUESTE Eintrag") — ohne sie neutralisieren sich zwei gleich laufende Präferenzen, und genau das war der Zustand der Ton-Einträge. `fact`/`memory`/`note` bleiben draußen (Werkstattwissen = Rauschen). **Vorbedingung war ein Datensatz-Fix**: der Eintrag vom 10-09 begrenzte den Ton selbst auf `/lexpen` und schrieb für den Standard-Modus ausdrücklich einen trockenen, emoji-freien Ton vor — injiziert wäre es **schlimmer als heute** gewesen. Live-Effekt (echter `~/.lex/mem`-Store): Ton-, sudo- und Pentest-Regel stehen im System-Prompt, `nmap`-Facts und Randnotizen nicht
- **`soul.md` = dynamische Persönlichkeits-Datei** (2026-10-26, §6 #57): `~/.lex/soul.md` wird über `_soul_ex` (lex:1096) **bei jedem Aufruf frisch** in den System-Prompt injiziert — Edit wirkt ab der nächsten Session bzw. dem nächsten `/lexpen`-Wechsel, kein Code-Eingriff nötig. `-s`-Gate + Whitespace-Gate (fehlend/leer = Prompt unverändert), Kopf mit Pfad + Zeilenzahl, Geltungssatz „gilt in ALLEN Modi und überstimmt Stil-Konflikte der Basis-Teile". Eingehängt an **beiden** Montagestellen (`setup_messages` lex:1122 **und** `_swap_slot0` lex:5890) als **letztes** Element — Reihenfolge IST Gewichtung, die Seele hat die höchste Stil-Rang. `cmd_status` (lex:5581) meldet `soul : <pfad> (N Zeilen, dynamisch …)` bzw. `(fehlt …)`. Der Seed-Inhalt folgt der aktiven Präferenz vom 12.10. (ein Ton in ALLEN Modi) plus Begrüßungs-Regel (kontextabhängig, kein starrer Eröffner)
- **Macht-Runde 2026-10-08 (User-Auftrag: sechs Punkte nacheinander bauen und nach jedem testen)**: **1 Hooks** (`_run_hooks` vor/nach `dispatch_tool`, `hooks/pre_tool` blockiert bei rc != 0 fail-closed, `hooks/post_tool` beobachtet, Env `LEX_HOOK_EVENT/TOOL/ARGS/RC`, Gates `LEX_HOOKS=off`/`LEX_HOOK_TIMEOUT`), **2 Sub-Agenten** (`agent(task, mode)`, Tiefen-Gate, frischer Kontext über bash-dynamischen Scope), **3 Parallele Tool-Calls** (`_tool_runs_parallel`/`_pp_launch_batch`: nur zustandslose non-MCP-Tools in Hintergrund-Subshells, Einsammeln in Original-Reihenfolge, Gate `LEX_PARALLEL=off`; Messung 1398 ms statt 3511 ms), **4 MCP-Native** (Discovery-Cache `mcp.cache.json` + Schema-Einträge `mcp__Server__Tool`, `__refresh`, argv-Invalidierung), **5 Skills** (`skills/<name>/SKILL.md` wird in `setup_messages` und `_swap_slot0` in den System-Prompt injiziert, Gates `LEX_SKILLS=off`/`LEX_SKILL_MAX`/`LEX_SKILL_TOTAL`), **6 Background-Tasks** (`task(start/status/result/kill/list)` unter `~/.lex/tasks/<id>/`, eigene Sitzung, rc-Datei, gleiche Deny-/sudo-Hürden wie `bash`, Gates `LEX_TASK_MAX`/`LEX_TASK_TIMEOUT`). Werkzeug-Zähler 17 → **19**, `run_all` 1031 → **1174 [PASS] = 1161 Einzelf**, `lex` 5145 → **5995 Zeilen**. Nebenbei behoben: `exec 2>/dev/null` in `_lurk_pending_lock`/`_unlock` legte den stderr der ganzen Shell still (§6 #41, Ursache der stillen rc=1-Läufer).
- **Observability**: `span_log()` schreibt pro `dispatch_tool`-Aufruf eine Zeile nach `$_log_dir/spans.jsonl` (Default `~/.lex/log/spans.jsonl`; `ts`, `name`, `args_hash`, `duration_ms`, `ok` — jq, ohne jq TSV), dazu `cmd_eval` = `lex --eval [datei]` → Auswertung (Verdict, Pro-Tool-Sektion, letzte 10 Spans)
- **Context-Compaction + Kontext-HUD** (Schritt 42): Auto-Trigger vor `append_message user` sobald `wc -c/3`-Schätzung (Live-Messung 3.30 B/Tok) ≥ `ctx − max(max_tokens, buffer)` (Default 160224 von 180224), `/compact` als Force, jq-Pairing-Gate + G0–G8 (Fail-safe: bei leerem Summary bleibt `_messages` byte-identisch), Marker `<!--lex-compact-->` in Slot 1, Session-Record `{type:compaction}`; HUD `tokens X/Y (Z%) prompt + …`, `/status` mit `compact`-/`ctx`-Block; Config `ctx_limit`/`compact`/`compact_keep`/`compact_buffer` (Tier 2 + ENV)
- **Prompt-Modus `/lexpen` → Lex-Persona** (Schritt 43): Slash `/lexpen` tauscht Slot 0 des Kontexts gegen die Senior-Engineer-Persona aus `~/.lex/prompts/lexpen.md` (beim ersten Aufruf angelegt, XP4→Lex, danach frei editierbar), `/lex` bzw. `/lexpen off` zurück zum Original — Verlauf und Wiki-Stand bleiben erhalten (`_wiki_ex()`), Session-Record `{type:prompt_mode}`, Prompt-Marker `lex*>`, `prompt`-Zeile in `/status`, `usage()` nennt beide Slashes; Antworten im Modus: **Deutsch** (Prompt-Direktive, Nachtrag 2026-10-03), Titel-Block, „Chief", `✦ made by @Lex ✦`
- **Debug-Proxy** `tools/llama-proxy.sh` (2026-09-28): leitet Requests an den llama-Server weiter und protokolliert Request/Response (`start|stop|status|tail|show`), Logs in `.proxy/` (gitignore). Bindet **nur 127.0.0.1**, Port 8080 wird abgelehnt
- **Live-Requests (freigegeben)**: 2026-09-28 zwei (direkt `Taugt.` + über den Proxy → `reasoning_budget_tokens: 4096`, `max_tokens: 8192`, 8 Tools, `finish=stop`) sowie **25 API-Turns in 11 Sessions am 2026-09-30** (Schritt 38, Auftrag „starte den llama server und teste alles ausführlich") — Details §4 „Live-Block 2026-09-30"
- **Mutationstests**: Deny-Liste / Session / `edit_file all` je einzeln gebrochen → `test_features.sh` rot (Tests sind nicht vaku)
- **Review-Fixes (Schritt 14, 2026-09-28)**: harte Deny-Liste über **Segmente** (`rm -rf -- /`, `sudo rm -rf /`, `xargs rm -rf /`, `curl …|sh|cat`, `curl … && sh`, `su postgres -c`), `safe_path` sperrt auch **nackte Wurzeln** und **Symlink-Ziele**, ungültige API-Antworten löschen **nicht** mehr den Kontext, gestorbene MCP-Server melden „nicht startbar", Config-Werte numerisch validiert, `edit_file` behält Rechte, `dispatch_tool` verlangt JSON-Objekte, Prompt nur bei TTY, `ss`-Prüfung pipefail-sicher
- **Palette (Schritt 14)**: Farben laufen über Variablen (`_palette_init`) → `NO_COLOR`/`TERM=dumb` schalten alles ab; H1 fett+**unterstrichen** statt „weiß" (auf hellem Grund lesbar), H3 cyan, Denken-Inhalt **grau statt kursiv**
- **Git**: Repo initialisiert, Commits `46c64c0` → `1faafaf` → `9c3f4e9`, Tag **v0.1.0**, Working-Tree sauber

### Baum (Stand 2026-10-01)
```
~/Ai/lex/
├── lex                        ✅ 6048 Zeilen, shellcheck-sauber
├── LEX.md                     ✅ dieses Dokument
├── README.md                  ✅
├── CLAUDE.md                  ✅
├── CHANGELOG.md               ✅
├── LICENSE                    ✅ MIT
├── .gitignore                 ✅
├── .github/workflows/ci.yml   ✅ bash -n + shellcheck (inkl. tools/) + run_all.sh + Hygiene-Check
├── .git/                      ✅ Commits 46c64c0/1faafaf/9c3f4e9, Tag v0.1.0
├── tools/llama-proxy.sh       ✅ Debug-Proxy (start|stop|status|tail|show), nur 127.0.0.1
├── test/run_all.sh            ✅ 19 Läufer (testboden zuerst), grün
├── test/test_input.sh         ✅ 30 Prüfungen (CLI-Modi, Mock-Sequenz, /exit-REPL, Prompt-Garantie, Strg+C-Prompt/-Turn, Sitzungs-Freigabe)
├── test/test_tools.sh         ✅ 23 Prüfungen (5 Tools + safe_path + dispatch)
├── test/test_loop.sh          ✅ 34 Prüfungen (run_turn, finish_reason, max_turns, Nudge-Fälle, Fail-Gedächtnis weich/hart/off, Silent-Guard nudge/hart/reset)
├── test/test_http.sh          ✅ 10 Prüfungen (echter curl-Pfad, Fake-Server, >128 KiB, Retry bei HTTP 500 mit/ohne Budget)
├── test/test_features.sh      ✅ 542 Prüfungen (Spec, Deny, Approve, Wiki-Schritte, todo, Lesbarkeit, Review-Fixes, Arbeitsrahmen, Prompt-Modus `/lexpen`, Sitzungs-Freigabe, Fix-Paket Redaction/Retry/Compaction/Reasoning, sudo-Ticket-Stub, adaptives Reasoning-Budget, adwt-Config, Prompt-Nadeln Stopp/Belegkette, Display-voll, Werkstatt-Verfahren + Werkstatt-Index-Auto-Skript, Rechte→sudo-Brücke)
├── test/test_proxy.sh         ✅ 29 Prüfungen (Durchreichung, Protokoll, 502, 8080-Sperre)
├── test/test_sse.sh           ✅ 32 Prüfungen (Stream-Fusion, Server weg, HTTP 500 (3 Versuche), Warnungen, Nudge-Verbot, Budget 3000 Chunks, stream_options-Body, usage-HUD, adwt-Body-Kw)
├── test/test_eval.sh          ✅ 16 Prüfungen (span_log, dispatch-Spans, cmd_eval, `lex --eval`)
├── test/test_limits.sh        ✅ 17 Prüfungen (kein Abschneiden lex↔llama: Nachrichten, Spill, Server-Antwort)
├── test/test_compaction.sh    ✅ 77 Prüfungen (Compaction-Gates, Pairing, Marker, HUD)
├── test/test_repetition.sh     ✅ 20 Prüfungen (Realfall-Loop → A1/A2/A3, FP-Gates, run_turn-Integration, statische Anker)
├── test/test_golden.sh        ✅ 38 Prüfungen (Fixtures-Integrität + golden.tsv, _sse_to_response vs. golden, _md_render vs. golden; Update-Modus `LEX_GOLDEN_UPDATE=1`)
├── test/test_load.sh          ✅ 33 Prüfungen (Last: 5000 SSE-Deltas, 300 tool_calls, 480-KB-Kontext+auto-Compaction, 2-MB-Antwort, 500er-Queue, 20-Tool-Dispatch; Budgets aus Referenz, Watchdog 180 s)
├── test/test_fuzz.sh          ✅ 93 Prüfungen (deterministisch `RANDOM=42`: 40 Parser-Korpus, 18 kaputte Mock-Queue-Zeilen, 35 dispatch_tool-Argumentstrukturen)
├── test/fake_server.sh        ✅ ncat-Helfer auf hohem Port, nie 8080 (+ `.sse`- und `STATUS:`-Modus)
├── test/fake_mcp.sh           ✅ minimaler MCP-Server (stdio/JSON-RPC) für die MCP-Tests
└── Dockerfile                 ⛔ entfällt (Entscheidung 2026-09-28: lex hat nichts mit Docker zu tun)
```

**Verifiziert 2026-10-08**: `bash test/run_all.sh` → **PASS: 13  FAIL: 0  TOTAL: 13**
(1031 [PASS] = 1018 Einzelf grün, Exit 0) · `shellcheck -S warning lex test/*.sh tools/*.sh` → 0.
**Verifiziert 2026-10-20**: `bash test/run_all.sh` → **PASS: 15  FAIL: 0  TOTAL: 15** (1060 [PASS]-Zeilen = Einzelf, 0 FAIL, rc 0) · `tools/selfcheck_lex.sh` rc 0 · `bash -n` + `shellcheck -S warning` rc 0 · `wc -l lex` = **6246** (unverändert zu HEAD — §6 O8 **zeilenneutral** gebaut) · **§5-Mappe neu gezogen** (fand einen Vorzustand: seit `efce4b4` lagen 52 Zeilen +4 daneben) · alle 127 `lex:`-Ziffern gegen den Code gegengeprüft, 0 Abweichungen · End-to-End-Body-Beleg über `FAKE_BODY_LOG` (Fake-Server, kein Port 8080): `reasoning_budget_tokens=2147483647` im **ersten und im Folge-Turn**. — **Verifiziert 2026-10-17**: `bash test/run_all.sh` → **PASS: 15  FAIL: 0  TOTAL: 15** (1053 [PASS]-Zeilen = Einzelf, 0 FAIL, rc 0) · `tools/selfcheck_lex.sh` rc 0 (`bash -n` + `shellcheck -S warning` + 16 Kernfunktionen) · `wc -l lex` = 6242 (Fix §6 O7 + Fail-Streak 3 **zeilenneutral** gebaut → alle 105 `lex:`-Zitate und die §5-Tabelle bleiben gültig) · **§6 O7 behoben** (Enkel stirbt an der Frist; Negativkontrolle ohne Fix lebt er weiter) · **§9/8 entschieden: Fail-Streak 6 → 3** (Loop-/Silent-Guard unangetastet) · **Scope-Grenze: ausschließlich `~/Ai/lex`** (benutzereigene Infrastruktur außerhalb des Repos wurde in dieser Runde irrtümlich angefasst und vollständig zurückgerollt) · **alte Chat-Bezüge in `LEX.md`: 18 → 5 Treffer auf 2 Zeilen** (nur Runden-Titel und Dateipfade, Prosa ohne Chat-Werkzeug), injizierte Kanäle (`~/.lex/mem`, `wiki/log.md` tail-40) sauber — Belege `~/Ai/wiki/wiki/errors/2026-10-16-eingabe-pfad-gesund-guard-nur-nudge-und-timeout-waise.md`.


---

## 4. API-Kontrakt (LIVE verifiziert, 2026-09-27 — GOLD)

- Endpoint: `POST http://127.0.0.1:8080/v1/chat/completions`
- **`reasoning_budget_tokens`** ist **top-level** — NICHT `thinking: {budget: …}` (das war der alte Bug, ist gefixt in `lex:1307`)
- Output-Feld: **`reasoning_content`** (nicht `thinking`)
- Tool-Calls: `choices[0].message.tool_calls[].function.name` + `.arguments` (JSON-**String**)
- `tool`-Rolle erwartet: `{"role":"tool","tool_call_id":"…","content":"…"}` ✅ (so implementiert)
- Streaming (SSE): `data: {choices:[{delta:{reasoning_content:"…", content:"…"}}]}` → **Phase 1**
- Usage: `completion_tokens` / `prompt_tokens` / `total_tokens` — im Stream **nur**, wenn der Body `stream_options:{include_usage:true}` mitführt (llama-server, upstream #16052; seit 2026-10-01 Standard in lex) — sonst liefert der Server das Event nicht, und das HUD zeigt `?`
- Server-Flags: `--reasoning on|off|auto`, `--reasoning-budget 4096`; `n_ctx_slot = 262144`, 1 Slot
- **lex schickt `reasoning_budget_tokens` adaptiv: erster Turn `reasoning_budget`, Folge-Turn `reasoning_budget_followup` — beide Default unbegrenzt (`2147483647` = INT32_MAX, seit 2026-10-20 §6 O8)** + `max_tokens: 16384` als einzige harte Grenze — `settings.json` (`reasoning_budget_tokens`/`reasoning_budget_followup`) und `LEX_REASONING_BUDGET`/`LEX_REASONING_BUDGET_FOLLOWUP`/`LEX_MAX_TOKENS` überlagern weiter (Wer kappen will, tut das bewusst über Tier 2/3). **`-1` im Request darf nie als „unbegrenzt" codiert werden** — `server-common.cpp:1357` fällt still auf das Server-Flag `--reasoning-budget 4096` zurück; `_rb_override` (Nudge/Compaction: 0) schlägt beides weiterhin
- `reasoning_content` bleibt **zwischen Tool-Calls erhalten** (wichtig für Multi-Turn)

- `call_api()` liest `LEX_API_URL` **zur Laufzeit** (nicht nur beim Laden) — Doku „ENV überlagert" gilt damit auch für Wechsel nach dem Start (2026-09-28, Test-Harness braucht das)
- `reasoning_content` wird **in die Session-JSONL geschrieben, aber nie in `_messages`** (bewusster Kontextschutz: 129 Reasoning-Blöcke ≈ 65 441 Tokens würden den 262 144er-Kontext sprengen) — siehe §9 Frage 7
- **2 Live-Requests getätigt** (2026-09-28, freigegeben): 1. direkt `LEX_MAX_TURNS=1 ./lex --oneshot` → `Taugt.`; 2. über den Debug-Proxy (Port 24480) → bestätigt `reasoning_budget_tokens:4096`, `max_tokens:8192`, 8 Tools, `usage: prompt=1409 completion=69`
- **Live-Block 2026-09-30 (freigegeben: „starte den llama server und teste alles ausführlich")** — `ai.sh start` (Ternary-Bonsai-2-27B-PQ2_0, 262144 ctx, 1 Slot), **11 Sessions / 25 API-Turns / 14 Spans**:
  - **Große Daten vollständig**: User-Message **280 072 B** in Kontext *und* Session-JSONL; `read_file` der echten `log.md` (**181 728 B**) → Kontext bekommt nur den Kopf (50 150 B) + Zeiger, die Ablage hat **181 727 B** (Original minus abschließendem `\n`, das `$(…)` entfernt — bis auf dieses Byte bytegleich, sonst kein Inhaltsverlust)
  - **Zeiger wirksam bewiesen**: die Marke stand ausschließlich am Ende einer **59 989-B**-Ausgabe und war im Prompt nicht ableitbar → das Modell folgte dem Zeiger (`read_file` der Ablage) + `grep`-Rückfallebene → **korrekte Marke**; ohne Spill wäre sie abgeschnitten gewesen
  - **Werkzeuge live**: `bash`, `read_file`, `write_file` (Datei angelegt ✓), `search` im Wiki ✓, `web_search` (697 ms, echter Treffer ✓); Proxy-Durchreichung: `req=38665 B`, `max=16384`, `rb=8192`, **tools=17**, `finish=stop`
  - **Nudge-Rette**: `LEX_MAX_TOKENS=150` provoziert `finish=length` → 4 Nudges (Log `nudge 1/4 … 4/4`), Teiltext gerendert statt verworfen, rc 0
  - **Saubere Sessions**: alle JSONL gültig, **0** Kürzungs-Marker, `reasoning`-Felder gefüllt (127–1722 B), System-Prompt bewusst nicht in der Session; `lex --eval` → 14 Spans, 2 `ok=false` = `search` ohne Treffer (erwartbar)
  - **Kein Session-Continue**: jeder Lauf startet frisch (im Code kein Restore) — eine „was war die Marke?"-Frage in frischer Session scheiterte erwartbar am Turn-Limit, nicht am Code
> ⚠️ **Du und Lex teilen sich den llama-server (Port 8080). In Tests NIE echte Requests — immer `LEX_MOCK=done` oder `LEX_MOCK_FILE=<datei>` oder der eigene Fake-Server auf hohem Port.**

---

## 5. Architektur des Skripts (`lex/lex`, 6353 Zeilen, Stand 2026-10-27)

| Funktion | Zeile | Aufgabe |
|---|---|---|
| `_abs_path()` / `_run_limited()` / `_mock_shadow()` | 61/135/231 | Fallback-Ketten für `realpath`/`timeout`, Schattenkopie für `LEX_MOCK_FILE`; `cd -P` löst Symlink-Verzeichnisse auf
| `_load_settings()` | 340 | jq-Reader für ein Settings-File (inkl. `max_turns`, `tool_timeout`, `tool_max_output`, `log_dir`, **`ctx_limit`/`compact`/`compact_keep`/`compact_buffer` seit Schritt 42**, **`api_retries` seit Schritt 53**)
| `_int_or()` / `_float_or()` / `_copy_mode()` | 378/384/397 | Schritt 14: numerische Config-Werte entschärfen (sonst `(( ))`-Abbruch), Dateimodus der Vorlage auf Tempdateien übertragen
| `load_config()` | 407 | 4-Tier: Defaults → `~/.lex/settings.json` → `.lex/settings.json` (CWD) → ENV (inkl. `LEX_APPROVE/LEX_SESSION/LEX_MEM_DIR`, **`LEX_CTX_LIMIT/LEX_COMPACT/LEX_COMPACT_KEEP/LEX_COMPACT_BUFFER` seit Schritt 42**, **`LEX_API_RETRIES` seit Schritt 53** (Clamp ≤10)) **+ numerische Validierung** (`_int_or` + on/off)
| `_redact()` / `_redact_var()` | 502/558 | **Schritt 53 — der einzige Redaktor**: eigener API-Key wörtlich, Schlüssel-Wert-Paare (`password|secret|token|apikey|auth|…`, Wertgruppe **JSON-sicher**: escaptes Anführungszeichenpaar als Ganzes, offene Werte ohne `"`/`\`), `Bearer`/`Basic`, Token-Präfixe (`sk-`/`ghp-`/`xox…`), URL-Credentials; Prefilter spart den sed-Fork in der Dauerlast; `_redact_var` schreibt in die Zielvariable (Kommandosubstitution würde abschließende Newlines streichen) |
| `log()` | 567 | append-only nach `$_log_dir/lex.log`, **jede Zeile läuft vorher durch `_redact()`** (Schritt 53)
| `_ms_now()` / `span_log()` | 582/594 | **Observability**: Millisekunden-Uhr (`date +%s%N`, sonst ganze Sekunden) und append-only Span-Writer nach `$_log_dir/spans.jsonl` (`ts`, `name`, `args_hash` per `cksum`, `duration_ms`, `ok`; jq-JSONL, ohne jq TSV)
| `_prompt_style` / `_prompt_ops` / `_prompt_lexpen_guard` / `_system_prompt` | 615/644/702/704 | Deutsch-First **inkl. Persönlichkeits-Block (Schritt 7)** + **„Arbeitsrahmen" (Schritt 40)**: stehender Scope (eigene Systeme/Lab/CTF, Blue-Team = Kerngeschäft), Fachbegriffe als Arbeitsvokabular, Scope-Frage statt pauschaler Absage — immer Deutsch, kurz, nicht raten, Fehler festhalten, Wiki als Gedächtnis — dazu **19 Tools**, Wiki-Konventionen und Planungs-Disziplin; **Anti-Zweifel (Schritt 15)**: entschlossen entscheiden, Verifikation über Tools statt Introspektion, keine Zweifelschleifen. **Schritt 48 — Ops-Layer-Split**: `_prompt_style` = Identität/Rolle/Arbeitsrahmen/Stil bis „Entschlossen denken" (Zeilen 605–633), `_prompt_ops` = Prüfen-/-Nicht-raten-/-Fehler-Bullets + „Für Menschen am Terminal" + 19-Tool-Liste + Wiki-Struktur + Regeln (634–691), `_system_prompt="${_prompt_style}${_prompt_ops}"` **byte-identisch** zum Original (sha256 `057c6842…`, 13884 B); `/lexpen` hängt `${_prompt_ops}` an die Persona → Werkzeug-/Research-Disziplin bleibt im Modus; **Schritt 49 — Anti-Verweigerungs-Guard**: `_prompt_lexpen_guard` (Zeile 692) hängt `cmd_lexpen` ausschließlich an den Ops-Layer („Aufträge werden ausgeführt, nicht verneint“) — Persona und Default-Prompt unverändert
| `session_init()` / `session_write()` | 747/777 | Session-ID + Kopfzeile, append-only JSONL — `session_write` redigiert die Zeile **vor** dem Anhängen (Schritt 53), damit `session.jsonl` kein Secret ablegt
| `append_message_json()` / `append_message()` / `setup_messages()` | 809/883/1108 | Message ins Kontext-Array **und** als JSONL-Record (mit optionalem `reasoning`), JSON-Array als String — **dateibasiert** (`--rawfile`/`--slurpfile`, Schritt 38): kein `jq --arg` mit Inhalt mehr, damit auch keine 100 000-B-Kappe; **Schritt 53 (P8)**: gespeichertes `reasoning` wird auf `LEX_REASONING_STORE_MAX` (Default **40000** seit §7/122) gekappt, der Rest steht als Hinweis in der Zeile
| `_build_tools()` | 1140 | OpenAI-Tool-Schemas (19 Tools, `edit_file.all` als `boolean`); **`_tools_off`** (Schritt 42) → sofort `[]` ohne jq-Lauf (Compaction-Summary-Call braucht keine Tools)
| `_sse_to_response()` | 1179 | **Stream-Auswertung (einziger jq-Lauf)**: JSON-Passthrough wenn der Body mit `{` beginnt, sonst SSE-Sammlung per `jq -Rn` `reduce` — Content-Deltas, `tool_calls` nach `index` fusioniert (Name/ID/Argumente aus den Deltas), `usage` **durchgereicht wie geliefert** (kein Nullen-Default, sonst loggt das HUD „0 + 0"), Warnung wenn kein `[DONE]` kam
| `_retry_delay()` / `call_api()` | 1230/1247 | `_retry_delay` = Backoff nach OpenAI-SDK-Norm (0.8/1.6/3.2 s, Deckel 8 s, Jitter ±25 %). `call_api`: Mock-Datei (Schatten) → Mock statisch → `curl -o <stream> -w '%{http_code}'` + `jq -n`-Body (inkl. `stream_options:{include_usage:true}` seit 2026-10-01), URL **zur Laufzeit**; **echter curl-rc UND HTTP-Status** als Guard (Stream **oder** klassische JSON-Response) — Fehler → rc≠0 + Meldung, nie still; **Schritt 53 (P3/P6)**: Retry-Schleife um den curl-Block (429/5xx/curl-rc, max. 2 Wiederholungen über `_api_retries`), Fehlermeldungen mit Body-Snippet (400 B) + Bytes + Versuchszahl + `parse_error`-Hinweis; 3000 Chunks in 0,12 s (vorher 29 s); **`_msg_override`** (Schritt 42) erlaubt einen kompletten Nachrichten-Body für den Compaction-Summary-Call
| `safe_path()` | 1407 | Deny-Liste für `/etc /usr /bin /sbin /boot /dev /proc /sys /var /lib /lib64 /root` — **auch die nackten Wurzeln** (`/etc`, nicht nur `/etc/…`) und **Symlink-Ziele** (Schritt 14)
| `tool_read_file()` / `tool_write_file()` / `tool_edit_file()` | 1436/1452/1510 | Datei-Tools (`edit_file` mit `all`, zählt Vorkommen; Tempdatei seit Schritt 14 **im Zielverzeichnis**, Modus bleibt)
| `_bash_segments()` / `_rm_targets_catastrophic()` / `_su_is_command()` / `_bash_denied()` | 1588/1604/1655/1677 | **harte Deny-Liste** (immer aktiv): Kommando in Segmente zerlegen, rm-Ziel-Prüfung über Tokens (`rm -rf -- /`, `sudo rm -rf /`, `xargs rm -rf /`), `curl\ | sh` über **alle** Segmente (`…\ | sh\ | cat`, `… && sh`), `su` als Kommando-Wort (`su postgres -c`); dazu Blockgeräte, Fork-Bombe, Neustart, `chmod -R 777 /`, `history -c` und **seit §7/122 die Kürzungs-Pipe** (`| head`/`| tail` → „volle Ausgabe nutzen"; grep/sort/wc-Pipes und Standalone-Log-Fenster bleiben erlaubt); `sudo` läuft über `_sudo_gate()`
| `_tty_preview_text()` / `_tty_preview()` | 1758/1767 | **Schritt 50**: sichtbarer TTY-Prompt — Titel + Kommando gekürzt (200 B, `LC_ALL=C`, `…(+N bytes)`) auf `/dev/tty`; die Frage danach steht als letzte Zeile (siehe `_approve_request`) |
| `_approve_request()` | 1772 | opt-in Approval (nur mit TTY); Prompt-Format Schritt 50: `freigeben? (y/N): ` **ohne** `\n` → Cursor bleibt hinter der Frage |
| `_needs_sudo()` / `_sudo_ask()` / `_sudo_gate()` | 1804/1824/1860 | **sudo-Gate (§6 #13)**: `su`-Muster erkennen, Ticket prüfen (`sudo -n`), ohne Ticket **eine** Aufforderung auf der TTY (`sudo -v`, Passwort direkt an sudo, Kommando gekürzt + `sudo-Passwort jetzt eingeben:` als letzte lex-Zeile), mit Ticket **Sitzungs-Freigabe** (Schritt 52): `_sudo_grant_request()` (lex:1839) fragt beim ersten sudo EINMAL pro Sitzung, `_sudo_grant_state()` (lex:1852) zeigt `offen|erteilt|abgelehnt` in `/status`; Ja = danach Auto-approve, Nein = y/N pro Befehl via `_approve_request()`; Grund landet in `_sudo_gate_reason` statt auf stdout; **§7/93**: `/lexpen`-Zweig direkt nach der `LEX_SUDO=0`-Sperre — **Auto-Grant ohne y/N-/Sitzungsfrage**, Passwort-Pfad nur noch als harter Fallback (wirksam ab NOPASSWD)
| `tool_bash()` | 1922 | Deny-Liste → sudo-Gate/Approval → Ausführung mit `_run_limited` (Ausgabe nach `$_rl_out`, Kindkette über `_kill_tree`, Watchdog `secs+10` — Schritt 53; Kindkette seit §7/93 `bash -o pipefail -c` → der gemeldete **rc ist der der KETTE**, nicht von `tail`), `</dev/null`, **volle Ausgabe** (Kürzung nur noch zentral via Spill, Schritt 38) |
| `_task_sudo_preflight()` / `_task_start()` | 3545/3552 | Hintergrund-Tasks losgelöst in **eigener Sitzung ohne controlling TTY** (setsid, nohup-Fallback); **Preflight im Zielkontext** (§7/93): sudo-Tasks prüfen `setsid -w sudo -n true` VOR dem Gate → frühe, ehrliche Ablehnung („kein TTY → NOPASSWD oder Foreground") statt „A terminal is required to authenticate" erst nach ~20 min Build; dieselben Hürden wie `tool_bash` (Deny-Liste/Gate/Approve), Kindkette mit pipefail, **Plan-Erinnerung** im Start-Ergebnis solange `plans/plan.md` leer ist |
| `tool_list_files()` | 1983 | Verzeichnisinhalt
| `tool_append_file()` / `tool_search()` | 2036/2066 | Wiki-Werkbank (Schritt 1): append-only schreiben, Volltextsuche (`grep -rIn`, literal/regex, Glob, 200-Treffer-Kappe)
| `_todo_file()` / `tool_todo()` | 2113/2117 | Schritt 2 + Nachtrag: Plan unter `${_lex_home}/plans/` — **session-unabhängig** (`plan.md`), `done` idempotent, Index = Anzeige-Position
| `_hist_init()` / `_hist_add()` | 2223/2245 | Schritt 6: Readline-History `~/.lex/history` (500 Einträge), `set -o emacs` + `bind`
| `_html_to_text()` / `tool_fetch()` / `_html_decode()` | 2266/2361/2357 | Schritt 4: Ingest nach `raw/<topic>/`, HTML→Klartext per awk, Metadatenkopf, Kollisions-Suffixe
| `_mem_valid_type()` / `_mem_slug()` | 2472/2477 | Typ-Whitelist, Dateiname aus der Überschrift
| `_mcp_config()` / `_mcp_argv()` / `_mcp_wait()` / `_mcp_send()` / `_mcp_call()` | 2491/2506/2682/2729/2744 | Schritt 9: MCP-Client für **stdio** — Server aus `${LEX_HOME:-$HOME/.lex}/mcp.json` (sonst Defaults), Handshake `initialize` → `notifications/initialized` → `tools/call`, Antwort-Filterung nach `id`, Zeitüberschreitung von Verbindungsabbruch getrennt; Schritt 14: `_mcp_send()` erkennt **beim Start gestorbene Server** (Coproc-FD) und meldet „nicht startbar" statt zu scheitern
| `tool_web_fetch()` / `tool_context7()` | 2920/2948 | Schritt 9: Crawler-Auszug über defuddle (ohne Ablage) mit **sichtbarem Knapp-Marker** (§7/122: Ausgabe ≥ `max_length` → „[gekürzt: N von max M …]" ans Ende, nie still), context7 zweistufig (`resolve-library-id` → `query-docs`) inkl. Bibliotheks-Vorschlag
| `tool_browser()` | 3019 | Schritt 22: Playwright-MCP gegen System-Chrome — navigate/snapshot/click/type per ref (Accessibility statt Vision), **kein Write-Gate**, volle Ausgabe (Spill zentral)
| `tool_mcp()` | 3103 | Schritt 23: generischer MCP-Zugriff — Discovery (tools/list via _mcp_call … list) + tools/call, Server-/Tool-Fehlermeldungen, volle Ausgabe (Spill zentral)
| `_ddg_parse()` / `tool_web_search()` | 3139/3204 | Schritt 10: DuckDuckGo-Auswertung in awk (Titel/URL/Ausschnitt, `uddg=`-Dekodierung per Byte-Tabelle, Entities, max. 10 Treffer) plus `curl` mit `LEX_SEARCH_URL`
| `tool_mem_add()` / `tool_mem_list()` / `tool_mem_search()` | 3222/3252/3274 | Memory (Spec §6.4)
| `dispatch_tool()` | 3909 | case-Map Name → Tool (17 Einträge) **+ Pflicht JSON-Objekt als Argument** (sonst landet die jq-Fehlermeldung im Kontext); **instrumentiert** (`_t0` vor dem `case`, `span_log` im `*)`-Branch, `_rc=$?` nach dem `esac` → jeder Aufruf hinterlässt Span inkl. Fehlerfall)
| `_palette_init()` / `_prompt()` | 4118/4147 | **Schritt 14**: Farbpalette über Variablen (`NO_COLOR`/`TERM=dumb` → leer), Prompt `lex>` nur farbig bei TTY; **seit 43** `lex*>` solange `/lexpen` aktiv (`lexl>`-Marker entfernt mit dem Lurk-Rollback §7/87, `_prompt` jetzt **3696**)
| `_hint_args()` | 4160 | kompakter Argument-Hinweis für den Trace (70 Zeichen)
| `_spin_start()` / `_spin_stop()` | 4176/4200 | Schritt 6: `⏳ denke …`-Spinner auf stderr, erst ab 250 ms, Flag-Datei verhindert Leerraum; `trap … EXIT` (Schritt 14)
| `_trace_result()` / `_trace_reasoning()` / `_trace_rule()` / `_trace_line()` / `_trace_hud()` | 4219/4248/4270/4275/4281 | Schritt 6 + 13 + 14: Tool-Rückgabe (8 Zeilen/600 Zeichen, `↳` cyan-dim), `⚙ denken:`-Block (Header dim-magenta, Inhalt **grau `90`** + Einzug statt kursiv), Trennlinie, `⚙ tool args` (Name fett cyan), HUD — alles über die Palette; **Schritt 42**: HUD zeigt bei gesetztem `ctx_limit` `tokens X/Y (Z%) prompt + …` (Y = `_ctx_limit`, Z = Prompt-Anteil der ctx), ohne Limit die alte Formel, ohne usage `?/Y`
| `_md_render()` / `render_markdown()` | 4314/4522 | Schritt 3 + 8 + 13 + 14: Markdown-Licht (Überschriften, `**fett**`, `` `code` ``, `[[wikilinks]]`, Zitate, Warnung/Fehler/Erfolg/Links/Listenmarker, **Pipe-Tabellen**); Schritt 14: **H1 fett+unterstrichen** (statt „weiß" → auch auf hellem Grund lesbar), H2 fett cyan, H3 cyan, `NO_COLOR`/`TERM=dumb` → roh
| `_compact_threshold()` / `_compact_estimate()` / `_pairing_ok()` / `_compact_units()` / `_compact_serialize()` / `_compact_prompt()` / `_compact_run()` | 4534/4554/4567/4590/4613/4638/4681 | **Schritt 42 — Context-Compaction** (Plan: `wiki/concepts/lex-compaction-plan.md`): Schwelle `ctx − max(max_tokens, buffer)` (Default 180224 → **160224**), Schätzung `wc -c/3` über `_messages` (Live: 3.30 B/Tok, /4 lag 18 % zu tief), `_pairing_ok` als jq-Gate (Rollen/`tool_call_id`/kein offenes `tool_calls`), `_compact_units` gruppiert Forward-Edges (assistant(tool_calls)+folgende tool-Results → eine Unit, Rest = eigene Units; der Tail-Rückwärtslauf behält den jüngsten Kontext bis `keep×4` B), `_compact_serialize` → `[Nutzer]:`-Token (Kürzung > 2000 B), `_compact_prompt` = deutsches Summary-Template, `_compact_run [force]` mit Gates G0–G8 (Settings/Mock/JQ/Pairing/leeres Summary/G4-Byte-Identisch/Zuweisung), Marker `<!--lex-compact-->` in Slot 1, tail-Budget `keep*4` Bytes lazy, Summary-Call ohne Tools (`_tools_off`/`_rb_override=0`/`_max_tokens=8192`/`_msg_override`), Session-Record `{type:compaction}` + `span_log compact`; Trigger: Auto-Hook in `run_turn` vor append user + Slash `/compact` (force) in `agent_loop`+`oneshot`
| `_sigint()` / `_abort_turn_tools()` / `_abort_turn_note()` | 4983/5000/5013 | Strg+C (Schritt 51): im Turn → `_turn_aborted` + Markierungs-Antwort für alle offenen `tool_call`-IDs (Rest des Batches), hängende user-Message über die Note beantwortet; am Prompt → 1. Druck Zeile weg, 2. Druck ≤2 s `Bye!`; `_turn_active` in `agent_loop` nach jedem Turn geleert |
| `run_turn()` | 5094 | **der Loop**: user → API → parse → bei `tool_count==0` ausgeben und `return 0`, sonst Tools ausführen und weiter; **Schritt 54 (Fail-Gedächtnis)**: Signatur `cksum(name|args|result[0..200])` je Tool-Call, 3× identisch → weicher Nudge, erneut → **Graceful-End** (§7/93: erzwungene Abschluss-Runde OHNE Werkzeuge, `_guard_final` verwirft Rest-`tool_calls` protokollkonform; Sicherheitsnetz rendert den Teiltext statt totem `rc 1`), **Fehler-Serie** (§7/93: ≥6 bash-Fails rc≠0 in Folge → Anstoß „Methode wechseln", `type:fail_streak`), Auswertung erst nach der Tool-Batch, `LEX_LOOP_GUARD=off`; schreibt `reasoning` nur in die Session; Schritt 14: **Guard** bei ungültiger/leerer API-Antwort (Kontext bleibt erhalten); Schritt 38: `assistant_msg` über Tempdateien, **zentrale Grenze mit Spill** (`_tool_spill()` vor `run_turn`: Kopf + Ablagepfad statt Abschnitt); **Schritt 42**: Compaction-Hook `_compact_run` **vor** `append_message user` (auto, Schwelle) + HUD-Nachladen `_hud_reread=1`
| `_tool_spill()` | 5546 | **Schritt 38 (Truncation → Spill)**: Tool-Ergebnisse > `_tool_max_output` (Default 50 000) werden in `${_log_dir}/tool_spill/` geschrieben (mktemp in `$DIR`, umask 077, chmod 600, `_redact` vor dem Schreiben, Ordner chmod 700); Pfad + Zeilennummer + gekürzter Ausschnitt in die Antwort — keine Daten gehen verloren, keine Secrets im Log |
| `server_hint()` | 5566 | Port-Prüfung per `ss` beim REPL-Start — **kein** HTTP-Request; ss-Ausgabe erst einsammeln (pipefail/rc 141, Schritt 14)
| `cmd_status()` | 5581 | `/status`-Anzeige (Modell, API, Tools, Session, Memory, Turns, **seit 42 `compact`-Block + `ctx`-Zeile** `X/limit (%)` bzw. `~X` geschätzt, **seit 43 `prompt`-Zeile** `standard`/`lexpen`/seit 75 `lurk`) |
| `agent_loop()` | 5730 | REPL (`while [[ -t 0 ]]`), Slash-Befehle `/status`, `/server`, `/help`, `/plan`, **`/exit`/`/quit` → `break`** (seit 2026-10-01: fiel vorher zu `run_turn` → kostete einen Request und blieb offen), **`/compact` → `_compact_run force`** (Schritt 42), **`/lexpen`|`/lex` → `cmd_lexpen`** (Schritt 43, explizite Muster gegen Request-Falle), Prompt via `_prompt()` (`/lexlurk` + Lurk-Ticker entfernt §7/87, `agent_loop` jetzt **5167**) |
| `oneshot()` | 5819 | Stdin → `run_turn` (ebenfalls `/status`, `/server`, `/help`, `/plan`, `/exit`/`/quit` → rc 0 ohne Modell-Call, **`/compact`**, **`/lexpen`|`/lex`**) — `/lexlurk` entfernt §7/87, `oneshot` jetzt **5248**) |
| `install_lex()` | 5844 | `~/.lex/` anlegen (`mem/`, `prompts/`, nicht `mem_net/`) + Settings-Template |
| `_skills_ex()` / `_mem_pref_ex()` / `_soul_ex()` | 998/1051/1096 | **Prompt-Injektoren** in fester Reihenfolge (`setup_messages` lex:1108 und `_swap_slot0` lex:5877): `${_system_prompt}$(_mem_pref_ex)$(_skills_ex)$(_wiki_ex)$(_soul_ex)` — Präferenzen zuerst (gehören zu „wer ich bin"), dann Skills, dann Wiki, ganz hinten die **Seele** (höchste Stil-Rang, Geltungssatz im Blockkopf: gilt in ALLEN Modi). Alle drei mit `-s`-/Existenz-Gate und sichtbarem Kürzungsmarker. **§6 #57**: `_swap_slot0` montierte vor 2026-10-26 ohne `_mem_pref_ex` — nach `/lexpen` fielen die Präferenzen still aus dem Prompt; die Nadel in `test_soul.sh` prüft die KLASSE (alle Bausteine müssen den Wechsel überleben) |
| `_wiki_ex()` / `cmd_lexpen()` | 924/5949 | **Schritt 43 — Prompt-Modus**: `_wiki_ex()` liefert Wiki-Stand (index + `tail -40` log, **mit Fenster-Marker** §7/122: „letzte 40 von N Zeilen — vollständig unter <pfad>") gemeinsam für `setup_messages` und Modus-Wechsel; `cmd_lexpen [on|off]` (+ `/lex`) tauscht per jq nur Slot 0 (`role==system`-Gate, sonst `setup_messages`-Fallback) — Verlauf bleibt, Lazy-Create `~/.lex/prompts/lexpen.md` (Heredoc, XP4→Lex), `${_wiki_dir}`/`${_htools_dir}`-Expansion, `{type:prompt_mode}`-Record, Status-/Prompt-Marker |
| `_pending_lock()` / `_pending_unlock()` | 6133/6144 | **Audit N1** (2026-10-08; 2026-10-12 §7/87 umbenannt von `_lurk_pending_*`, die Zähler `_add`/`_drain` sind mit dem Lurk-Modus entfallen): flock-Sperre, fd im AKTUELLEN Prozess, kein `$(…)` — `_pending_lock` öffnet, `_pending_unlock` schließt; trägt heute den Mock-Konsum-Pfad (`_mock_shadow`, O3) und jeden weiteren RMW-Pfad; Fallback ohne flock vorhanden |
| `usage()` | 6154 | Hilfe inkl. Sicherheitshinweis (`--eval [datei]`, Slash-Liste `/status /server /plan /lexpen /lex /help /exit /compact`), **live „Modus gerade aktiv"** (Schritt 75), **ENV-Sektion** `LEX_CTX_LIMIT LEX_COMPACT LEX_COMPACT_KEEP LEX_COMPACT_BUFFER` (Schritt 42; LURK-ENVs entfernt §7/87)
| `cmd_eval()` | 6225 | **Auswertung der Spans**: Kopf mit Span-Datei, Anzahl + Gesamtdauer (s), Verdict (`FEHLGESCHLAGEN: n von m` bzw. `OK: n Tool-Aufrufe, 0 Fehler`), Pro-Tool-Sektion (Summe ms + Fehler je Tool), Letzte 10 Spans; fehlende Datei → Hinweis, rc 0
| `main()` | 6264 | `--oneshot --approve --status --install --eval --version --help` (Dispatch nach `--status`, optional mit Datei-Positional)
| `_wiki_dir` (`LEX_WIKI_DIR`) | 55 | Wurzel des LLM-Wikis, Default `~/Ai/wiki`, in `/status` sichtbar

**Invariante des Loops**: Der Loop wird nie umgeschrieben — Mechanismen kommen darüber (learn-claude-code s01/s02).

### Nebenwerkzeug `tools/llama-proxy.sh` (seit 2026-09-28)

Debug-Schicht zwischen lex und llama-Server — zeigt, was **rein** und **raus** geht:

```bash
LEX_PROXY_UPSTREAM=http://127.0.0.1:8080 ./tools/llama-proxy.sh start 24480
LEX_API_URL=http://127.0.0.1:24480/v1/chat/completions ./lex --oneshot   # lex damit testen
./tools/llama-proxy.sh show 1     # N-request. Request UND Response roh + pretty
./tools/llama-proxy.sh tail 20    # traffic.log
./tools/llama-proxy.sh status | stop
```

| Log-Datei | Inhalt |
|---|---|
| `.proxy/traffic.log` | eine Zeile pro Austausch: Status, Bytes, Dauer, `model/msgs/roles/max/rb/tools`, `finish/content/reasoning` |
| `.proxy/<id>-in.json` + `-pretty.json` | roher Request bzw. eingerückt |
| `.proxy/<id>-out.json` + `-pretty.json` | rohe Response bzw. eingerückt |
| `.proxy/<id>-headers.txt` / `-rsp-headers.txt` | Request-Header, Upstream-Header |
| `.proxy/handler.err` | Fehler des Pro-Request-Handlers |

Regeln: Port **nie 8080** (wird abgelehnt), Bindung **nur 127.0.0.1**, Upstream aus `LEX_PROXY_UPSTREAM` (Default `http://127.0.0.1:8080`), Zustand in `$LEX_PROXY_DIR` (Default `./.proxy`, gitignore). Ein `curl`-Fehler beim Upstream ergibt **HTTP 502** + `PROXY-FEHLER` im Log.

---

## 6. Bekannte Bugs / offene Fixes

### Blockierend für "fertig"
| # | Ort | Problem | Fix | Status |
|---|---|---|---|---|
| 1 | `test/run_all.sh:31-33` | 3 Testdateien existieren nicht → `run_all.sh` immer rot | `test_input.sh`, `test_tools.sh`, `test_loop.sh` schreiben | ✅ 2026-09-28 |
| 2 | `test/run_all.sh:36` | `printf '%s\n' "PASS: %d …"` → gibt `%d` **wörtlich** aus | `printf 'PASS: %d  FAIL: %d  TOTAL: %d\n' "$PASS" "$FAIL" "$TOTAL"` | ✅ 2026-09-28 |
| 3 | `lex:5154–5187` | **`finish_reason` wird nie geprüft** → bei `length` (Truncation) wird ein abgeschnittener Tool-Call als "fertig" behandelt → das bekannte „ich fange an … und höre auf" | `finish_reason` auswerten; bei `length` Warnung/Nudge statt `return 0` | ✅ 2026-09-28
| 4 | `lex:1332` | `curl --max-time 300` zu kurz (4096 tok @ 11–24 t/s ≈ bis 370 s) | `--max-time 900` oder aus `max_tokens`/Ctx ableiten | ✅ 2026-09-28
| 5 | `lex:249` | `max_tokens=4096` + Reasoning-Budget 1024 teilen sich das Budget → Truncation | höher setzen (z. B. 8192) oder Budget-Logik klären | ✅ 2026-09-28

### Portabilität / Korrektheit
| # | Ort | Problem | Fix | Status |
|---|---|---|---|---|
| 6 | `lex:1916` | `tool_bash` hatte **kein `</dev/null`** (Spec `ARCHITEKTUR.md` §6.3) → interaktive Kommandos hängen | `bash -c "$command" </dev/null` | ✅ 2026-09-28 (Test 17) |
| 7 | `lex:1957` | `output+="\n…"` erzeugte **literal** `\n`, kein Zeilenumbruch (mit `od` bestätigt) | `$'\n…'"${len}"' Bytes …'` | ✅ 2026-09-28 (Test 18) |
| 8 | `lex:44/63/161` | `realpath -m`, `readlink -f`, `timeout` sind **GNU-Tools** → macOS (Bash 3.2), iSH fehlen ggf. | Fallback-Ketten `_abs_path()` (realpath → readlink → `cd`-Auflösung) und `_run_limited()` (timeout → direkter Aufruf), Guard beim Skript-Pfad | ✅ 2026-09-28 (Test: 4 Prüfungen) |
| 9 | `lex:5812` | `install_lex` legte `mem_net/` an, Spec will `~/.lex/mem/` | umbenannt + Test (`install (mem/ angelegt)`, `kein mem_net/`) | ✅ 2026-09-28 |
| 10 | `lex:310/225` | `LEX_MOCK_FILE` wurde **in-place verbraucht** (zerstörte die Quelldatei) | Schattenkopie unter `~/.lex/mock/` (`_mock_shadow()`), nur erneuert wenn die Quelle neuer ist → Sequenz bleibt über Läufe erhalten, Quelle unversehrt | ✅ 2026-09-28 (Test: 3 Prüfungen) |

### Behoben 2026-09-28 — Test-Harness HTTP-Pfad (wurde nie ausgeführt)
`test_http.sh` war **nicht** in `run_all.sh` eingetragen und schlug doppelt durch. Vier Defekte, alle in dieser Aufgabe gefunden und gefixt:

| Ort | Problem | Fix |
|---|---|---|
| `test/fake_server.sh` | `ncat --listen` **ohne `-k`** akzeptiert genau EINE Verbindung und stirbt — der eigene Port-Wait (`nc -z`) verbrauchte sie → danach `curl: rc 7` | `-k` + Port-Wait-Prüfung |
| `test/fake_server.sh` | Handler arbeitet im **Line-Modus**: auch `nc -z`-Probes hätten eine Response-Zeile gezogen → Test bekam `DEFAULT` statt der geplanten Antwort | Request-Line/Header lesen, nur bei `POST` eine Zeile entnehmen |
| `test/fake_server.sh` | `echo PID; wait …` → die Befehlsersetzung `FAKE_PID="$(fake_server.sh …)"` kehrt erst bei EOF zurück → Aufrufer hängt | ncat detachen, PID ausgeben, **sofort enden**; Handler/Lock neben der Script-Datei (= im TMP des Testers) |
| `test/fake_server.sh` | **`Content-Length` in Zeichen statt Bytes** (`${#body}`) → bei `ü` war das Limit 1 Byte zu kurz, curl schnitt das JSON ab → `jq: invalid JSON text passed to --argjson` → „Leere Antwort vom Modell" | `wc -c` |
| `test/test_http.sh` | 2. Response-Zeile **ungültiges JSON** (überzähliges `}`) | korrigiert (Permutation bewiesen: `jq -e`) |
| `test/test_http.sh` | zweiter Start setzte nur `LEX_API_URL`, aber `call_api()` las das beim `source` gesetzte `_api_url` → 2. Turn sprach den alten, schon getöteten Port an (`curl: rc 7`) | `lex` liest `LEX_API_URL` **zur Laufzeit** (Doku: „ENV überlagert") |
| `test/test_http.sh` | `cleanup()` räumte `rm -rf $TMP` **vor** `kill` auf → Handler wurde gelöscht, während ncat ihn noch braucht | Reihenfolge getauscht |
| `test/run_all.sh` | `test_http.sh` fehlte in der Läuferliste | eingetragen (5. Läufer damals; **heute 6** mit `test_features.sh`) |
| — | Nebenbefund: Backtick in einem Kommentar **innerhalb des unquotierten Heredocs** → beim Schreiben des Handlers lief `nc -z` als Command-Substitution | Backticks ersetzt |

### Sicherheit (Entscheidung 2026-09-28)
| # | Problem | Entscheidung / Fix | Status |
|---|---|---|---|
| 11 | `safe_path` schützt nur die File-Tools — **`tool_bash` umgeht alles** → Sandbox kosmetisch | **harte Deny-Liste in `_bash_denied()`, IMMER aktiv** (rm -rf auf `/`/`~`/`.`, `mkfs`/`wipefs`/`of=/dev/`/`dd … of=/dev/`, Fork-Bombe, `su` (nicht mehr `sudo`, s. #13), Herunterfahren/Neustart, Systemprozesse, `chmod -R 777 /`, `history -c`, `curl\|sh` ohne Fetcher bleibt erlaubt) — 7 Patterns + End-to-End im Test | ✅ 2026-09-28 |
| 12 | **Kein Approval-Gate** (learn-claude-code s03) | **opt-in**: `--approve` bzw. `LEX_APPROVE=1` → `_approve_request()` fragt pro Kommando ab, nur mit controlling TTY (sonst Verweigerung). **Ohne Flag kein Prompt** → Tests bleiben deterministisch | ✅ 2026-09-28 |
| 13 | `sudo` stand in der Deny-Liste → der Agent konnte **nichts** mit Root-Rechten tun (User-Auftrag 2026-09-28: „eine Aufforderung, wo ich es einfach eingeben kann“) | **Gate statt Verbot**: `sudo` raus aus der Deny-Liste, `su` bleibt drin. `_sudo_gate()` (lex:1860) wird in `tool_bash` **im current shell** aufgerufen — immer **genau EINE** Aufforderung: ohne gültiges Ticket zeigt `_sudo_ask()` (lex:1824) das Kommando auf der controlling TTY und ruft `sudo -v` auf → **das Passwort geht direkt an sudo**, nie durch lex (keine Variable, kein Log, `tool_bash`-Stdin bleibt `</dev/null>`); mit gültigem Ticket fragt `_approve_request()` y/N. Kein controlling TTY → Verweigerung. `LEX_SUDO=0` sperrt sudo komplett, `LEX_SUDO_APPROVE=0` lässt die y/N-Frage bei gültigem Ticket weg | ✅ 2026-09-28 |

### Behoben 2026-09-28 — Debug-Proxy (`tools/llama-proxy.sh`)

Vier Defekte, alle beim Selbsttest (`test/test_proxy.sh`) gefunden:

| # | Symptom | Ursache | Fix |
|---|---|---|---|
| P1 | `curl: Unsupported HTTP/1 subversion` | Statuszeile doppelt: `HTTP/1.1 HTTP/1.1 200 OK` — `$status` enthält schon die Version, es kam aber `printf 'HTTP/1.1 %s'` | `printf '%s\r\n…' "$status"`; außerdem `grep '^HTTP/' \| tail -n1` (der **letzte** Status gewinnt, nicht der `100 Continue`) |
| P2 | `curl: rc 18`, 1 Byte fehlt | Body per `$(cat …)` → Kommando-Setzung schluckt das trailing `\n`, `Content-Length` war 1 zu groß | Header und Body getrennt senden, Body per `cat` |
| P3 | `traffic.log` leer / Rennen | Protokoll wurde **nach** der Antwort geschrieben, curl kehrt aber schon bei Empfang zurück | Protokoll **vor** der Antwort (dabei `rlen` nach oben, sonst `set -u`-Abbruch → „Empty reply") |
| P4 | `status` zeigte immer Upstream `8080` | `cmd_status` las die gespeicherte `proxy.upstream`-Datei nicht | Datei lesen, Port daraus prüfen; dazu: Bindung `0.0.0.0` → **`127.0.0.1`** |

Testabdeckung: `test/test_proxy.sh` = 29 Prüfungen, als 7. Läufer in `run_all.sh`; `bash -n` + shellcheck laufen in CI über `tools/*.sh`.

### Behoben 2026-09-28 — Spec-Features (ARCHITEKTUR.md §6)
| Spec | Feature | Umsetzung | Test |
|---|---|---|---|
| §6.4 | `mem_add`, `mem_list`, `mem_search` | `lex:1153/3931/658`, Schemas in `_build_tools()`, Dispatch, System-Prompt 5→8 Tools, `LEX_MEM_DIR` | `test_features.sh` (10 Prüfungen) |
| §6.5 | Session-JSONL, append-only | `lex:768/777` — Kopfzeile + eine Message pro Zeile, `reasoning_content` als Feld; **nicht** im Kontext (Kontextschutz), `LEX_SESSION=0` schaltet ab | `test_features.sh` (7 Prüfungen, inkl. „jede Zeile valides JSON") |
| §6.6 | `/status` | `lex:5758`/`lex:6275` als Slash-Befehl **und** `lex --status`; `/help`; Port-Hinweis beim Start | `test_features.sh` (6 Prüfungen) |
| §6.6 | `edit_file` Multi-Block | `all`-Argument (`boolean` im Schema), alle Vorkommen über eine literal-sichere Schleife (kein `${//}`-`&`-Problem), Rückmeldung „n von m" | `test_features.sh` (3 Prüfungen) |
| §6.3 | `tool_bash`-Schutz | `</dev/null` + Truncation + Exit-Code (2026-09-28) **+ timeout-Guard + Deny-Liste** | `test_tools.sh` + `test_features.sh` |

**Bewusst offen (Phase 1)**: `truncated`-Flag als eigenes Antwort-Feld (TIEFE-RECHERCHE §14), Landlock/Glob-Sandbox (§8 E), Bash-3.2-Baseline testen (§8 D).

---

### Behoben 2026-09-28 — Code-Review (Schritt 14, P1/P2/P3)
User-Auftrag: „optimiere es bitte und schau nochmal ganz drüber, ob du Bugs oder Stellen findest, die wir optimieren können". 15 Befunde, alle fixt; Zeilenangaben aus `lex` (2330 Zeilen).

| # | Ort | Problem | Fix |
|---|---|---|---|
| 14 | `lex:1671` `_bash_denied` | rm-Deny-Liste war Substring-basiert → **`rm -rf -- /`, `rm -Rf /`, `rm -fr --no-preserve-root /`, `sudo rm -rf /`, `xargs rm -rf /`, `timeout 5 rm -rf /` liefen durch** | segmentweise Prüfung: `_bash_segments()` (1578) + `_rm_targets_catastrophic()` (1594) vergleicht die rm-Ziel-Tokens (`/`, `/*`, `.`, `./`, `~`, `~/`, `$HOME`, echtes `$HOME`) |
| 15 | `lex:1696` | `curl …\|sh\|cat` und `curl … && sh x.sh` umgingen den Pipe-Check (geprüft wurde nur das **letzte** Segment) | alle Segmente werden geprüft; ab Segment 2 führt ein Shell-Wort (`sh/bash/zsh/…`) zum Deny; `curl …\|cat` und `curl …\|grep sh` bleiben erlaubt |
| 16 | `lex:1649` | `su postgres -c id` wurde verfehlt (nur `su -c` als Substring) | `_su_is_command()` (1645): `su` muss Kommando-Wort eines Segments sein (auch hinter `sudo`/`env`/`xargs`-Wrappern); `grep su - …` bleibt erlaubt |
| 17 | `lex:1401` `safe_path` | nackte Wurzeln (`/etc`, `/usr`, `/var`, `/proc`) und **Symlink-Ziele** (`/tmp/etclink/passwd`) liefen durch | Wurzeln in die Case-Liste, Auflösung des Symlink-Ziels, `cd -P` im Fallback von `_abs_path` |
| 18 | `lex:2477` `_mcp_config` | `cat "${LEX_HOME}/mcp.json"` ohne Fallback → `set -u`-Abbruch, wenn `LEX_HOME` fehlt | `${LEX_HOME:-$HOME/.lex}` |
| 19 | `lex:401` `load_config` | nicht-numerische Config-Werte (`LEX_MAX_TURNS=abc`) → Arithmetic-Fehler in `(( ))`, ggf. Dauerschleife | `_int_or()`/`_float_or()` (368/374) validieren nach Tier 4; `LEX_REASONING_MAX` zur Laufzeit |
| 20 | `lex:5070` `run_turn` | leere/ungültige API-Antwort wurde als „Antwort" behandelt → `_messages` darauf reduziert, **gesamter Modellkontext weg** | Guard: `.choices` muss ein Array sein, sonst rc 1 + Meldung, Kontext bleibt erhalten |
| 21 | `lex:2730` `_mcp_call` | MCP-Server stirbt beim Start → Coproc-FD weg → `printf`/`read` scheiterten mit rc 141 bzw. `set -u`-Absturz **ohne Meldung** | `_mcp_send()` (2704): PID-Check + Gruppe mit `2>/dev/null`; `_mcp_wait()` (2657) prüft den FD → klare Meldung „Server ist nicht startbar" |
| 22 | `lex:1504` `tool_edit_file` | `mktemp` in `/tmp` → `mv` cross-filesystem (nicht atomar) und Modus **600** statt der Vorlage | Tempdatei im Zielverzeichnis + `_copy_mode()` (387); auch bei `todo done` |
| 23 | `lex:3895` `dispatch_tool` | `args` wurde nicht validiert → jq-Fehlermeldung des Modells landete als Tool-Ergebnis im Kontext | Pflicht `type == "object"`, sonst Klartext-Fehler + rc 1 |
| 24 | `lex:5542` `server_hint` | `ss \| grep -q` unter `pipefail` → rc 141 → „kein Server" obwohl einer läuft | ss-Ausgabe erst einsammeln, dann prüfen |
| 25 | `lex:334` `_load_settings` | `max_turns`, `tool_timeout`, `tool_max_output`, `log_dir` wurden aus `settings.json` **nicht** gelesen | jq-Reader ergänzt |
| 26 | `lex:4119` `_prompt` | Prompt schrieb die Farbsequenz unbedingt auf stdout → landete in Pipes/Logs | nur bei TTY und ohne `NO_COLOR` |
| 27 | `lex:4152` `_spin_start` | Spinner blieb bei Exit/SIGINT im Terminal hängen | `trap '_spin_stop' EXIT` |
| 28 | `test/test_tools.sh:40` | geteilter Pfad `/tmp/safe_err` (Verstoß gegen Test-Isolation) | `$TMP/safe_err` |

**Palette (Schritt 14, daneben umgesetzt)**: alle Sequenzen laufen über `_palette_init()` (4084) → `NO_COLOR`/`TERM=dumb` ergeben leere Strings; H1 = fett+**unterstrichen** statt `1;37` (weiß ist auf hellem Grund unsichtbar), H3 = cyan statt fett, Denken-Inhalt = grau `90` statt kursiv `2;3` (italic wird nicht überall unterstützt); TTY-Demo per `script … | cat -v` verifiziert.

### Behoben 2026-09-29 — Live-Test der Integrationen (echte Umgebung, echte LLM-Turns)

| # | Ort | Problem | Lösung |
|---|---|---|---|
| L1 | `_mcp_call` / `dispatch_tool` / `run_turn` | Jede Tool-Iteration lief in Command-Substitution → eigene Subshell → die Coproc-MCP-Session starb nach jedem Call: navigate→snapshot landete auf `about:blank`, Refs waren pro Call anders („Ref not found") | neue `_mcp_out_var()` (Tempdatei statt `$(…)`), `run_turn` schreibt `dispatch_tool`-Output in Tempdatei (Redirection, keine Subshell), Keep-Alive in `_mcp_call` (Key `server|argv`, `kill -0`, Neustart bei Config-Wechsel oder Server-Tod); Nadeln: Session-Zähler über `_mcp_call` **und** `dispatch_tool` |
| L2 | `tool_browser` (Ref-Verfall) | playwright-mcp vergibt nach asynchronen Seiten-Events (Autocomplete nach `fill`, Reload nach `back`) neue Refs — alter Ref → „Ref not found" | neue Action `wait` (`browser_wait_for`, `text`=Sekunden) + Prompt-Regel: nach back/click/press(Enter) **immer erst frisches snapshot**; Schema-Enum + Description ergänzt, Stub `browser_wait_for` |
| L3 | `tool_browser` click/type | playwright-mcp ≥0.0.83 erwartet `target` (Ref-ID) zusätzlich | args `{target,ref,element[,text]}` — ref/element bleiben für ältere Versionen und den Stub |
| L4 | `call_api` | `$body` als exec-Argument sprengt ab ~128 KiB das Kernel-Limit (`E2BIG`: „Argumentliste zu lang") — Mehrfach-Turns schieben die Historie hoch (Live-Turn 3: 34 KB → 88 KB → **140.8 KB**) | Body über Tempdatei, `curl -d @file`; Nadel: 140.000-B-Body gegen Fake-Server |
| L5 | `tool_browser` / Default-Config | ohne CDP-Endpunkt startete playwright pro Lauf eigenen Browser bzw. dockte nicht an den laufenden an | `_ensure_browser()` (Chrome-Dienst 127.0.0.1:9222, PID-Datei `$LEX_HOME/browser.pid`, nur wenn Config `cdp-endpoint` enthält) + Default-Config `@playwright/mcp@0.0.83 --cdp-endpoint http://127.0.0.1:9222` |
| — | `web_search` (extern, nicht lex-seitig) | DuckDuckGo liefert Anti-Bot-Challenge-Seite → 0 Treffer, `html.duckduckgo.com` liefert `anomaly`-Challenge | offen: anderer Provider oder eigene UA — nur gemeldet, nicht gefixt |

### Behoben 2026-09-29 — Gesamtprüfung (Limits-Erhöhung + Code-Review Welle 1–4)

**G — Limits (User: „Limits erhöhen, damit der Agent bei großen Aufgaben nicht abbricht")**

| # | Ort | Problem | Lösung |
|---|---|---|---|
| G1 | Tier-1-Defaults | `max_tokens 8192` + `rb 4096` → `finish=length` bei langen Antworten; `max_turns 100`, `tool_timeout 60 s` (bei 16384 Tokens deutlich zu kurz) | Defaults **16384 / 8192 / 200 / 300 s**; Nudge-Grenze als eigener Default (`_default_max_nudges=4`, ENV `LEX_MAX_NUDGES`); curl-Zeit `LEX_API_TIMEOUT` (Default 1800 s); `--status` zeigt `nudges` |
| G2 | `call_api` | jq `--argjson m "$_messages"` als exec-Argument → E2BIG ab 131 071 B → leerer Body, „❌ API-Fehler" (mit 193 KB reproduziert) | Kontext über `--slurpfile` aus Tempdatei + rc-Guard; curl `--max-time "${LEX_API_TIMEOUT:-1800}"` |
| G3 | `append_tool_message` / `append_message` / `setup_messages` | jq-Argumente ohne E2BIG-Guard → Protokollbruch (tool_call ohne Antwort); übergroßer Wiki-/System-Prompt → leerer Startkontext | 100 000-B-Kappe vor jq + Fallback-Platzhalter; Wiki-Kappe in `setup_messages` |
| G4 | `dispatch_tool`-Ergebnis | Tool-Ausgaben ohne zentrale Kappe (mem_*, todo, list_files …) landeten ungekürzt im Kontext | zentrale Kappe via `_tool_max_output` vor `_trace_result`; Nadeln: `_max_nudges=1`-Abbruch, test_http Block6 mit 2 × 100 000 B |

**R — Code-Review (Sub-Agent, P1/P2/P3)**

| # | Ort | Problem | Lösung |
|---|---|---|---|
| R1 | `_rm_targets_catastrophic` | `rm -rf ${HOME}`, `"$HOME"/.`, `/home/…/.` liefen an den exakten Tokens vorbei → Home-Löschung möglich | Präfix-Check auf Home-Wurzel (literal **und** expandiert; gesperrt nur Wurzel + .-/..-Komponenten, Subtrees wie `~/projekt` bleiben erlaubt) |
| R2 | `_bash_denied` (Download) | `curl\|sudo sh`, `\|env sh`, `\|nohup sh`, `bash <(curl…)`, `source <(curl…)`, `eval "$(curl…)"`, `curl … & sh f.sh` umgingen den Pipe-Check | Wrapper-Skip (wie `_su_is_command`), Direktausführung/Prozess-Substitution verboten, `&` als Segment-Trenner; False-Positiv-Schutz (`diff <(…)`) |
| R3 | `tool_web_fetch` / `tool_context7` | `$( _mcp_call … )` in Subshell → Coproc-Session und NEXTID-Zähler brachen | `_mcp_out_var` (Hauptshell, Tempdatei-Redirection) |
| R4 | `tool_mem_add` | Dateiname nur Sekundenpräzision → zweiter Eintrag in derselben Sekunde überschreibt den ersten | Kollisionsschleife mit `-N`-Suffix |
| R5 | `tool_edit_file` | `$(cat)` streicht alle Trailing-Newlines, `printf '%s\n'` fügt genau eine hinzu → Dateiende verfälscht | Original-Zeilenenden zählen und originalgetreu wiederschreiben |
| R6 | `tool_write_file` | nicht atomar (Direktschreiben), neue Dateien hätten mktemp-600 behalten | Tempdatei im Zielverzeichnis + `_copy_mode` bzw. `0666 & ~umask` + `mv` |
| R7 | `main` | `--approve` funktionierte nur auf Position 1 | Flags in beliebiger Reihenfolge; zweiter Befehl → klarer Fehler |
| R8 | `safe_path` | `~/x` landete als `$PWD/~/x` (realpath kennt kein Tilde) | Tilde-Expansion vor `_abs_path` |
| R9 | `_mcp_call` | shared `mcp.err` wurde von jedem Serverstart überschrieben → Fehlermeldungen ins Leere | eigene Errdatei `mcp.<server>.err` |
| R10 | `agent_loop` | ohne TTY (`echo "Frage" \| lex`) schluckte die Eingabe tatenlos (REPL-Schleife lief nie) | non-TTY → `oneshot`-Pfad |
| R11 | `_ensure_browser` | tote PID-Datei / lebendes Chrome ohne offenen Port → Doppelstart („Profile in use") | Pid-Check: tot → Datei weg, lebend → Port-Abfrage abwarten, sonst Meldung |
| R12 | `test_*.sh` | `source lex` ohne Fehler-Guard (Syntaxfehler → Folgefehler im Unklaren); test_http Block6 deckte G2 nicht ab | `\|\| exit 1` in 4 Läufern; Block6 mit zweiter 100-kB-Message |

**TEST (+29 → 514)**, `lex` 2683 → **2884 Zeilen** — **✅ VERIFY 2026-09-29**


### Behoben 2026-09-30 — Streaming-Regression in `call_api()` (Nudge-Kette, Tool-Calls, Observability)

Ursache des Schadens: ein uncommitteter „Optimierungs"-Umbau auf Streaming hatte den
HTTP-Guard und die tool_calls-Fusion zerstört, ohne dass eine Testdatei es merkte.
Beweisführung mit Fake-SSE auf Port 24711 (`/tmp/opencode/sserepro/`), Reproduktion dann
ohne Hilfe in `test/test_sse.sh`.

| # | Befund | Wirkung | Fix |
|---|---|---|---|
| S1 | `rc=$?` **nach** `done < <(curl …)` = Status des Schleifenkörpers, **nicht** von curl | Server weg/HTTP-Fehler landeten still in der „Antwort war leer"-Nudge-Kette (4 Nudges bis „Antwort mehrfach leer — Abbruch.") | `curl -o <stream> -w '%{http_code}'` → **echter** curl-rc **und** HTTP-Code; Fehler → rc≠0 + `curl rc=…`/`Fehler: HTTP …`, nie still |
| S2 | tool_calls-Fusion `jq -s '.[0] + .[1]'` aus **zwei** Here-Strings (2. überschrieb den 1.) | nur das letzte Delta überlebte → `name: null`, Argumente ein Fragment (`}`) → `tool: null` im Session-Log | **ein** jq-Lauf `_sse_to_response()`: `jq -Rn reduce` über den Stream, `tool_calls` nach `index` fusioniert (Name/ID aus dem 1. Delta, Argumente kumuliert) |
| S3 | ~4 jq-Forks pro SSE-Zeile | 3000 Chunks = 29 s | ein Lauf über die Datei: 3000 Chunks = **0,12 s** |
| S4 | Filter verlangte `data: ` (mit Leerzeichen) | `data:` ohne Leerzeichen → still leer → Nudge-Schleife | Regex toleriert beides |
| S5 | fehlendes `[DONE]` | still rc 0, evtl. unvollständige Antwort | Warnung `⚠ kein [DONE]`, Sammlung trotzdem ausgewertet (rc 0) |
| S6 | `usage` auf `total_tokens: 10` gefälscht | HUD/Statistik falsch | echte `usage` aus dem letzten Stream-Event |
| S7 | Live-Anzeige `[[ -t 1 ]]` in `$(…)` | toter Code (Subshell) | bewusst **nicht** gebaut → §7 Schritt 36 |
| S8 | `_ms_now`/`span_log`/`--eval` weg (grep 0), `test/fake_server.sh` + `test/test_http.sh` **gelöscht**, `test_proxy.sh` schickte echte Requests an 8080 | Observability fehlte, Regel 6 verletzt, `run_all.sh` rot (referenzierte `test_http.sh`) | Observability zurückportiert, Tests aus dem HEAD wiederhergestellt, Fake-Server um `.sse`- und `STATUS:`-Modus ergänzt |
| S9 | Nudges ohne jede Diagnose; Original-Logik nudgte auch bei leerer Antwort **ohne** `finish_reason=length` | Fehlerbild nicht unterscheidbar (echtes Abschneiden vs. API-Fehler vs. nur-Reasoning) | Guard: nur `finish_reason=length` nudgt; Log-Zeile `nudge k/max finish=… content=… reasoning=…`; eigene Meldungen für nur-Reasoning/leer; `run_turn` meldet `API-Fehler (call_api rc=…)` + `log` |

Tests: **`test/test_sse.sh` (19)** — Content-Deltas, tool_calls-Fusion (6 Einzelprüfungen),
Server weg, HTTP 500, `data:` ohne Leerzeichen, Warnung ohne `[DONE]`, Body ohne
`data:`-Event, je mit „kein Nudge"-Negativprobe; **`test/test_eval.sh` (16)** — `span_log`,
`dispatch_tool`-Spans (ok wahr/falsch, `duration_ms` typzahlen), `cmd_eval` gültig/leer/fehlend,
CLI `lex --eval`.

**TEST (+37 → 551; 9 Läufer)**, `lex` 2884 → **3154 Zeilen**, §5-Mappe neu gezogen (46/46) — **✅ VERIFY 2026-09-30**

### Verhütung 2026-09-30 — drei harte Gates (gleicher Tag wie der Fund)

Aus der Ursache „ungetesteten Pfad umgebaut, Tests gelöscht/unaufgebunden,
Behauptung ohne Messung" folgen drei maschinelle Schranken (Regeln §C/§D §E
ergänzt):

| Gate | Wo | Was er bricht |
|---|---|---|
| **Testboden** | `run_all.sh`, **erster** Läufer `testboden` | (1) eine in `run_all.sh` referenzierte Testdatei fehlt oder ist nicht ausführbar, (2) eine Testdatei ist gegenüber `HEAD` gelöscht, (3) eine vorhandene `test_*.sh` läuft nicht mit (Runner-Vergesslichkeit) — alle drei Richtungen einzeln bewiesen, sonst grün |
| **Stream-Budget** | `test/test_sse.sh` Szenario 8 | 3000 Chunks müssen **unter 2000 ms** ausgewertet **und** vollständig (3000 Zeichen) ankommen — damals 29 s, heute ~0,12 s; „schnell" durch abgeschnittene Antwort schlägt über die Inhaltsprüfung fehl |
| **Regeln** | LEX.md §C (2 Zeilen), §D (3 Punkte), §E (2 Checkboxen) | Optimierung braucht Test **und** Zahl in derselben Änderung; Hot-Paths nie ohne Fixture-Test; Experimente nur auf `opt/*`-Branch, Arbeitsbaum sauber als Vorbedingung |

Negative Tests der Gates (Szenarien 2–4): gelöschte Datei, Orphan-Test,
Runner ohne Datei → jeweils rc 1, Normalfall rc 0.

**TEST (+4 → 555; 10 Läufer)** — **✅ VERIFY 2026-09-30**

### Behoben 2026-09-30 — Kürzungen an der lex↔llama-Grenze (Truncation → Spill)

**Auftrag:** „finde heraus was abgeschnitten wird — soll nicht abgeschnitten
werden, was von lex zu llama und von llama zu lex zurückkommt." Inventar und
Behebung:

| Stelle | Alt (Kappe) | Neu |
|---|---|---|
| `append_message`, `append_tool_message`, `setup_messages` | 100 000 B vor `jq --arg` (E2BIG-Guard aus Schritt 17b: 135-KB-`read_file` → Linux-Argumentlimit 128 KB) | Message/System-Prompt/Wiki laufen über Tempdatei (`--rawfile`/`--slurpfile`) — `jq` bekommt den Inhalt nie als Argument, es gibt nichts mehr zu kappen; Fallback-Platzhalter ebenfalls dateibasiert |
| `append_message_json`, Session-Record | `--arg m "$msg"` bzw. `--arg r "$reasoning"` | `--slurpfile`/`--rawfile` |
| `run_turn` `assistant_msg` | `--arg content` + `--argjson tcs` | Tempdateien, Fehler → `log` + rc 1 (sonst wäre die Antwort still weg) |
| `tool_read_file`, `tool_bash`, `tool_search` (Bytes), `tool_browser`, `tool_mcp` | eigene Kappen auf `_tool_max_output` (50 000 B, Doppelarbeit) | entfallen — volle Ausgabe, Kürzung nur noch zentral |
| zentrale Kappung in `run_turn` (`_tool_max_output`) | `${result:0:50000} … (gekürzt …)` → Daten weg, ohne dass das Modell es merkte | **Spill**: `_tool_spill()` legt das volle Ergebnis unter `${_lex_home}/toolout/<ts>-$$-<tool>.txt` ab, der Kontext bekommt Kopf + Zeiger („vollständige Ausgabe liegt unter …, mit read_file nachladen"), Aufbewahrung: jüngste 100 Ablagen, `log`-Zeile pro Spill |
| llama→lex (`_sse_to_response`) | — | blieb immer vollständig (geprüft); Kappen gibt es nur noch bei der **Anzeige** (`_trace_result`, `render_markdown`, `LEX_REASONING_MAX`) und in Fehler-Snippets (`head -c 200`) |

**Bewusst unverändert:** 200-Treffer-Marker (`search`), 500-Einträge-Grenze
(`list_files`), `web_fetch max_length` (das Modell fragt selbst), MCP-Argument
`--argjson a "$args"` (lex→MCP, außerhalb dieser Grenze), der Kontext selbst
bleibt endlich — deshalb gibt es weiterhin eine Grenze, nur eben mit Ablage
statt Abschneiden.

Diese Ersetzung löst die Zeilen **G3** und **G4** aus „Behoben 2026-09-29"
ab (damals Kappung als E2BIG-Schutz bzw. als zentrale Begrenzung gedacht).

**TEST (+18 → 573; 11 Läufer)** — neuer Läufer `test/test_limits.sh` (17
Prüfungen: 280 000-B-Nachricht in `_messages` **und** Session-JSONL,
250 000-B-System-Prompt, 60 000-B-Datei ungekürzt über `read_file`, Spill mit
60 000-B-Ablage + Zeiger im Kontext, 150 000-Zeichen-Server-Antwort
vollständig) plus zwei Alt-Tests auf den neuen Vertrag (`test_tools.sh`
#12b/#18, `test_features.sh` „Riesennachricht"), `lex` 3154 → **3199 Zeilen**,
§5-Mappe neu gezogen — **✅ VERIFY 2026-09-30**

### Behoben 2026-10-01 — `/exit` fiel ins Modell + HUD loggte erfundene Token-Nullen

**Auftrag:** User zeigte eine Live-Session (12 Turns) und fragte „siehst du das
problem?" — zwei Defekte im Trace sichtbar, beide heute gebaut:

| # | Befund | Wirkung | Fix |
|---|---|---|---|
| E1 | `/exit` (und `/quit`) existierten nicht — `case` in `agent_loop`/`oneshot` kannte nur `/status /server /help /plan`, alles andere fiel zu `run_turn` | `/exit` kostete einen kompletten Request (das Modell antwortete „Gut. …"), die REPL blieb offen; „schliese dich" landete als Turn 12 genauso im Modell; einziger Ausweg: Ctrl-D | `/exit\|/quit` → `break` (REPL, mit Abschied) bzw. `rc 0` ohne Modell-Call (oneshot/pipe); Slash-Liste in `usage()` um `/server` und `/exit` ergänzt |
| E2 | Request-Body hatte `stream:true`, aber **kein** `stream_options:{include_usage:true}` | llama-server liefert Usage im Stream nur auf Anforderung (upstream #16052) → `_sse_to_response` füllte den Nullen-Default → HUD zeigte in **jedem** Turn `tokens 0 prompt + 0 completion` | Body um `stream_options:{include_usage:true}` ergänzt; **zusätzlich** der Nullen-Default in `_sse_to_response` entfernt (`usage:.usage`) — ohne usage-Event zeigt das HUD jetzt `?` statt zu lügen |

**Warum die Suite es nicht fing:** der Mock-Response und die SSE-Fixtures
lieferten `usage` stets mit → der Live-Pfad (Server liefert keine) war nie
abgedeckt; `/exit` wurde nie als Slash-Command getestet.

**TEST (+15 → 588; 11 Läufer)**: `test_input.sh` 12 → 18 (oneshot/pipe
`/exit` und `/quit` ohne Modell-Call, Exit-Code 0, **echte REPL unter
`script`-PTY**: „Tschüss" kommt, „Taugt." des Mocks nicht), `test_sse.sh`
22 → 29 (Szenario 9:
Fake-Server schreibt den Request-Body über `FAKE_BODY_LOG` mit → `stream:true`
und `stream_options.include_usage:true` per jq geprüft; Szenario 10: usage im
Stream → HUD `tokens 1409 prompt + 69 completion`, usage-los → `?` und
Negativprobe gegen `tokens 0 prompt + 0 completion`), `test_features.sh`
434 → 436 (`/help` nennt `/exit` und `/server`), `lex` 3199 → **3206 Zeilen**,
§5-Mappe neu gezogen — **✅ VERIFY 2026-10-01**

### Offen (P3 — bewusst nicht gebaut, Reihenfolge/Scope)
| # | Ort | Problem | Einschätzung |
|---|---|---|---|
| O1 | `_md_render` | ~~Tabelle mit `\|` innerhalb von `` `code` `` bricht die Spaltenbreite~~ | **behoben 2026-10-07 (§7/65)**: `cells()` schützt `\|` vor dem Split — ✅ erledigt |
| O2 | Tools (`%.70s`, Truncation) | Byte-Kürzung kann mitten in einem Mehrbyte-Zeichen enden (locale-abhängig) | **behoben 2026-10-08 (§7/80)**: `_hint_args`/Fehlerausgabe/Trace kürzen jetzt in Zeichen (`${v:0:N}`, UTF-8-Locale); `cutv` in den Tabellen war bereits UTF-8-sicher — ✅ erledigt |
| O3 | `_mock_shadow` | Rennen, wenn zwei Läufe dieselbe `LEX_MOCK_FILE` beschreiben | **behoben 2026-10-08 (§7/80)**: Konsum-Pfad (`head`+`tail`+`mv`) unter `_lurk_pending_lock` (fd im aktuellen Prozess, Fallback ohne flock = Verhalten wie vorher); deterministischer Test — ✅ erledigt |
| O4 | `lex:25` (`set -u`) | ohne `HOME` bricht lex ab (`HOME: unbound variable`) | Absicht oder Default `$HOME`-Fallback? offene Frage an den User |
| O5 | Tool-Ausgaben (`dispatch_tool`) | `$(…)` entfernt **alle** abschließenden Zeilenende-Zeichen — eine Datei, die mit `\n` endet, landet als 181 727 statt 181 728 B im Spill (live gemessen, sonst bytegleich) | nur Zeilenende, kein Inhaltsverlust; ein Fix müsste die Ausgabe aller 19 Tools über Dateien führen und bricht Dutzende Vergleiche → bewusst nicht gebaut |
| O5b | `call_api` | ~~kein Retry bei 5xx/abgebrochener Verbindung~~ — **behoben 2026-10-06 (Schritt 53)**: Retry-Schleife (429/5xx + curl-rc, max. 2 Wiederholungen, `_retry_delay` 0.8→8 s ±25 % Jitter), Config `api_retries`/`LEX_API_RETRIES`; dazu HTTP-Fehler-Snippet mit `parse_error`-Hinweis (§6 #36) | erledigt |
| O6 | Kontext-Management | ~~kein Compaction/Summarization~~ — **behoben 2026-10-02 (Schritt 42)**: auto-Trigger über `_compact_threshold` (Default-Schwelle 160224 = `ctx − max(max_tokens, buffer)`, ctx 180224), `/compact` als Force, Schwelle/HUD/Status konfigurierbar (`ctx_limit`/`compact`/`compact_keep`/`compact_buffer`) — Details §7/42 | ~~bewusst Phase 3 (Limits-Report 2026-09-29)~~ ✅ 2026-10-02 |
| O7 | `_run_limited` (lex:135, Watchdog lex:184–195) | `timeout --foreground` (Step-51-Erbe) signalisiert **nur den direkten Kindprozess**; der Wrapper ist `bash -c ‚Befehl \| Filter‘` — stirbt dieser mit TERM, laufen die Enkel als PPID-1-Waisen weiter. Der `_kill_tree`-Watchdog (secs+10) findet sie nicht mehr (adoptiert), und offene Pipes = Klasse §6 #35. **Beleg 2026-10-16** (Session 123444): Call 13:02:44 `nmap -sT -Pn -T3 -p- --open … \| tail -5` → rc=124 um 13:07:44, nmap lebte bis **15:45:00 = 9736 s** weiter und schrieb die `-oA`-Dateien erst dann (13:15 noch 0 B; Ergebnis: keine offenen Ports). **Isoliert belegt**: `timeout --foreground 1 bash -c ‚sleep 41 \| cat‘` → rc=124 **und** `sleep 41` überlebt; ohne `--foreground` stirbt die ganze Gruppe. | **Behoben 2026-10-17** (§7/110): `_run_limited` hat eine **eigene Frist bei `secs`** — der Watchdog (lex:184–195) schläft nur noch `$secs` statt `secs+10` und tötet die Kindkette tiefste-zuerst, **solange sie noch an `pid` hängt**; GNU `timeout` ist nur noch Rückfall mit Frist `secs+10` (grace, lex:172). `--foreground` bleibt (statt `setsid`), weil `/dev/tty`-Leser (sudo, y-N) die foreground-Gruppe von lex brauchen (§6 #35). Marker `deadline` erzwingt rc=124 **seit Fix 2026-10-19 über `-e`** (zuvor `-s` auf einer mit `: >` leer angelegten Datei = nie zutreffend → toteder Code; der Rückgabecode kam vom `timeout`-Backend: uutils 0.10.0 lieferte 124, GNU wie im CI 143 — lokal grün, CI rot, §7/113). **Korrektur der ursprünglichen Aussage „+ Hinweis":** der Hinweis-Zweig und `[[ -s "$flag" ]]`/`_rl_hung` prüfen ihre Marker **nach** `rm -f "$tf" "$flag" "$dl"` und können dadurch nie feuern — beide bleiben toter Code, Aktivierung ist §7/113 offen (der Hinweis würde die partielle Ausgabe ersetzen statt sie zu ergänzen). Beleg: §6-O7-Nadeln in `test/test_features.sh` — Enkel `sleep 43` tot bei rc=124, ohne Fix lebt er weiter |
| O8 | `reasoning_budget` / `reasoning_budget_followup` (lex:256 f., `call_api`) | ~~Kappung des Reasonings auf 2048/768 Tokens~~ — **behoben 2026-10-20 (§7/114)**: beide Defaults auf **2147483647** (INT32_MAX = Obergrenze des Servers), die Budget-Message feuert nie mehr mitten im Gedanken. **Beleg** (Session `anonym`, 00:33:38): Denktext endete mit „…Cloudflare blockt." + injizierter Message „Budget erreicht - jetzt die beste Antwort geben, nicht zögern oder zweifeln." bei ~734 Tokens = am Followup-Budget 768 abgerissen; das Modell lieferte stattdessen eine kontextfremde Verbesserungs-Tabelle. **Falltrap dokumentiert**: `-1` im Request ist kein „unbegrenzt" — `server-common.cpp:1357` fällt still auf das Server-Flag `--reasoning-budget 4096` zurück. Kappung weiterhin möglich über Tier 2/3 (`settings.json`, `LEX_REASONING_BUDGET*`), `_rb_override` (Nudge/Compaction = 0) unverändert | ✅ erledigt 2026-10-20 |

### Externer Bug (nicht lex, offen) — 2026-10-02: gnome-terminal-Crash

| # | Ort | Problem | Status |
|---|---|---|---|
| X1 | `gnome-terminal-server` (Systempaket, **nicht lex**) | SIGSEGV 02.10. **00:06:31** (Journal `code=dumped, status=11/SEGV`): Use-after-free-Race in der `bg-color`-Notify-Kette (`terminal-screen.cc` → `g_object_notify` → `gtk_widget_queue_draw` auf zerstörtes Widget). Ein Server pro Session für **alle** Fenster → SIGHUP auf alle Kinder: lex-Sessions, MCP, Playwright-Chrome (Exit 00:06:34), komplett weg | offen — **bewusst nicht** an Launchpad gemeldet (User-Entscheidung 02.10.); Core `/var/crash/_usr_libexec_gnome-terminal-server.1000.crash`; Backtrace/Kaskade/Ausgrenzung: `wiki/errors/2026-10-02-gnome-terminal-segv-bg-color.md` |
| X2 | Schutz der lex-Sessions | Multiplexer (tmux/screen) überleben den Crash als Daemon — **aber auf User-Wunsch 02.10. komplett entfernt** (Pakete `apt purge`, Aliases `tlex`/`tlexkill`, 44 History-Zeilen) → lex-Sessions laufen **bewusst ungeschützt** im Terminalfenster | bewusst akzeptiert (User 02.10.); **Nachtrag 02.10. (User: „tlex soll wieder der alias sein"): User richtet tmux wieder ein, Aliases `tlex`/`tlexkill` rekonstruiert** (`tmux new -A -s lex` / `tmux kill-session -t lex` — Originaldefinition war bei der Bereinigung verloren) |

Ausgeschlossen als Ursache: OOM, dbus, Screen-Lock, GPU, Wayland-Server, lex selbst (zuletzt aktiv 00:01:35). Vermuteter Auslöser: Theme-/Dunkel-Modus-Wechsel (`color-scheme=prefer-dark`) — nicht bewiesen; Reproduktion nicht versucht (Crashtest würde alle Fenster mitnehmen).

### Behoben 2026-10-03 — REPL-Prompt verschwand nach Eingabe (Schritt 47)

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 29 | `lex:agent_loop` (`[[ -z "$input" ]] && continue`) | Bei **leerer Eingabe** (nur Enter) übersprang `continue` den `_prompt`-Aufruf — readline löscht beim Enter die Eingabezeile, danach nur noch blinkender Cursor. Eingabe funktionierte weiter (Live-Beweis: User-Eingabe um 20:37 in der promptlosen Session, `turn: 46 chars`). | `{ _spin_stop; _prompt; continue; }` — Prompt wird explizit nachgezogen | ✅ 2026-10-03 (PTY-Nachweis: 2× Enter → ≥3 `lex>`) |
| 30 | `lex:_spin_start` (Spinner-Loop `while :;`) | Ein überlebendes Spinner-Kind (`kill` griff im Live-Lauf nicht; verwaistes `bash ./lex` beobachtet) hätte weiter `\r\033[2K` repainten und die Prompt-Zeile fressen können — einziges Lösch-Konstrukt im Skript (4118/4129). | Flag-Gate `while [[ -f "$_spin_flag" ]]` → Loop endet ≤0,12 s nach `_spin_stop`; zusätzlich `_spin_stop` hart vor jedem Schleifenende-`_prompt` | ✅ 2026-10-03 (kill-Snippet + statischer Anker) |

### Behoben 2026-10-05 — y/N-Freigabe-Prompt unsichtbar (Schritt 50)

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 31 | `lex:_approve_request` / `_sudo_ask` | `printf 'Freigabe für Kommando (y/N): %s\n' "$cmd"` schrieb die Frage **vor** das Kommando — bei mehrzeiligen sudo-Befehlen (KB-groß) stand `(y/N)` ~160 Zeilen oben und scrollte aus dem Bild; der User sah nur Kommando-Ende + blinkenden Cursor und nicht, dass lex auf Bestätigung wartete (Live-Hänger 2026-10-05 im Audit-Lauf, Stopp nur per manueller Zeichen-Injektion ins Terminal; `/autosudo on` existiert als Dauerlösung, war in diesem Lauf aber nicht gesetzt) | `_tty_preview_text()`/`_tty_preview()` (lex:1767/1719): Titel + Kommando gekürzt (200 B + `…(+N bytes)`) über der Frage; `printf 'freigeben? (y/N): '` **ohne** `\n` als letzte Zeile → Cursor dahinter; `_sudo_ask` analog (`sudo-Passwort jetzt eingeben:`). Verhalten (y/j = ja), Gate und `/autosudo` unverändert | ✅ 2026-10-05 (+2 Checks → 730, 13 Läufer DE+EN) |

### Behoben 2026-10-05 — Strg+C beendete lex + Session-Rechte umask-anfällig (Schritt 51)

Auslöser: User-Auftrag nach der Auswertung eines Sicherheits-Audit-Laufs (Session `anonym`): „stoppe ihn … beides ein".

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 32 | `lex:_sigint` (neu) / `agent_loop` / `run_turn` / `_run_limited` | **Kein `trap … INT`** — ein einziger Strg+C beendete den kompletten lex-Prozess (es gab nur den Spinner-Kommentar als „trap"-Treffer); **zweiter, versteckter Defekt**: Standard-`timeout` steckt das Kind in eine eigene Process Group — der tty-INT erreichte weder Kind noch `bash -c`, die Substitution lief bis zum Ablauf weiter (gemessen **20 s statt 2 s**, `sleep 60` lief voll) und der Turn-Abbruch hing bis `tool_timeout` (300 s) | `_sigint()`-Trap (lex:4983): im Turn → `_turn_aborted=1` (Kind stirbt am tty-INT, weil `timeout --foreground` die Gruppe auflöst; Timer rc=124 weiter geprüft), am Prompt → erster Druck verwirft nur die Zeile, zweiter Druck ≤2 s → `Bye!`, EOF bleibt Strg+D (`rc>128 || _int_seen` unterscheidet INT von EOF, unabhängig von der Trap-Reihenfolge); `run_turn`-Abbruchstellen (Loop-Top, nach `call_api`, vor und nach `dispatch_tool`) — im Tool-Batch antwortet `_abort_turn_tools()` für **alle** restlichen `tool_call`-IDs mit Markierung, sonst wäre der OpenAI-Kontext defekt; hängende user-Message bekommt über `_abort_turn_note()` eine assistant-Antwort; `_turn_active` wird in `agent_loop` nach jedem Turn geleert | ✅ 2026-10-05 (+5 Checks → 735, 13 Läufer DE+EN) |
| 33 | `lex:session_init` / `install_lex` | Session-Pfade entstanden nur per `mkdir -p` + append — je nach umask des Aufrufers **775/664** (Fund: neue Session 125104 = `drwxrwxr-x`; das Hauskeeping-`chmod` hielt nicht, weil jede Session frisch angelegt wird) | `chmod 700` auf `sessions/` und Session-Ordner, `session.jsonl` wird **vor** der ersten Zeile als `: >` angelegt und auf `600` gesetzt; `install_lex` legt `sessions/` ebenfalls 700 an; bestehende Sessions nachgezogen | ✅ 2026-10-05 (+3 Checks → 738, 13 Läufer DE+EN) |

**Mit-Beantwortet (User-Frage „warum kam keine sudo-Aufforderung?")**: `sudo -k -n true` → **NOPASSWD:ALL** ist aktiv (Schritt 45), sudo fragt **nie** ein Passwort — der `_sudo_ask`-Passwort-Pfad wird gar nicht erreicht. **Stand 2026-10-06: Regel gelöscht** (User-Auftrag „Passworteingabe soll wieder sichtbar sein“) — `/etc/sudoers.d/<datei>` entfernt, `sudo -n true` scheitert wieder (`rc=1`), damit greift `_sudo_ask` (TTY-Vorschau + „sudo-Passwort jetzt eingeben:“ + `sudo -v < /dev/tty`) genau dann, wenn lex sudo braucht; ohne controlling TTY weiterhin saubere Verweigerung. Die einzige Frage ist die y/N-Freigabe. Metrik des Laufs: 122 Tool-Calls, **32 mit sudo**, **alle** Langblöcke (>30 s) sind sudo-Calls (172/554/229/83/369/92/38/126/90/53/215 s + **2 h 00 m Avahi-Stop 15:10→17:11**) ≈ **2 h 35 m reine Wartezeit** der 4 h 25 m Session (~58 %); 17:13:30 Verweigerung in 32 ms (Enter statt y) → Modell ohne sudo weiter → Anonymisierungs-Proxy nicht auflösbar (RFC 7686) → Strg+C. Echte Erfolgsblocker: Avahi hielt `0.0.0.0:5353` gegen den Anonymisierungs-Proxy, DNS-Weg über den Proxy kaputt, Client-Config unter proxychains — **nicht sudo** (alle freigegebenen sudo-Calls `ok=true`).

### Behoben 2026-10-05 — sudo blockierte pro Kommando mit y/N (Schritt 52)

Auslöser: User-Entscheidung nach Schritt 51 — „eine Sitzungs-Freigabe statt y pro Befehl" (Ablehnung soll weiter pro Befehl fragen; **neuer Default**, kein Opt-in).

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 34 | `lex:_sudo_gate` / `_approve_request` | Mit gültigem sudo-Ticket (hier immer, `NOPASSWD:ALL`) fragte das Gate **y/N pro sudo-Kommando** — 32 sudo-Calls im Audit-Lauf, jeder brauchte eine manuelle Freigabe; 58 % der Laufzeit waren Warteschleifen, eine einzige Enter-Eingabe (17:13:30) riß die Kette und der Lauf starb an fehlendem Root | **Sitzungs-Freigabe (Default)**: neuer Prozess-Zustand `_sudo_grant` (`""`→`"1"`→`"0"`, Init lex:1795) + `_sudo_grant_request()` (lex:1839: Titel/Preview wie `_approve_request`, `sudo für diese ganze Sitzung freigeben? (y/N): ` ohne `\n`, y/j=ja) + `_sudo_grant_state()` (lex:1852) für `/status grant: offen\|erteilt\|abgelehnt`; Gate-Reihenfolge: `LEX_SUDO=0` → Ticket/`_sudo_ask` → `_autosudo=1` → `approve=0` → grant=1 → Sitzungsfrage → `_approve_request`; **Nein** merkt sich `"0"` und es läuft pro Befehl weiter y/N (alter Weg), kein TTY → Frage scheitert → Ablehnung (deterministisch); `/autosudo on` und `LEX_SUDO_APPROVE=0` überspringen auch die Sitzungsfrage; Help-/Status-/`cmd_autosudo`-Texte aktualisiert | ✅ 2026-10-05 (+12 Checks → 750, 13 Läufer DE+EN) |
| 35 | Tool-Call `script -c 'timeout … <IRC-Client>' \|\| tail` (vom Modell erzeugt) + `_run_limited`/Pipe-Read | `script` legt eigene Session an, inneres `timeout` **ohne** `--foreground` (Step-51-Klasse) → das TUI liest Pty im Hintergrund → **SIGTTIN, Zustand `T`** (0 B Transkript, Timer-TERM wird nie verarbeitet); die Kette stirbt nicht, verwaiste `script`/`tail` (PPID 1) halten die Schreibseite von **lex' fd3-Lesepipe** offen → Tool-Call **17,5 min hängen** (00:34–00:51) trotz 300-s-Wrapper (rc=124 erreicht die Anzeige nicht), zweiter Fall 01:00–01:03; beide Male nur manuell per `kill -KILL` entblockt | ✅ **Schritt 53**: Ausgabe der Kindkette läuft in eine **Tempdatei** (`$_rl_out`) statt in die fd3-Pipe — der Leser kann nicht mehr an einem offenen Schreibende hängen bleiben; neue `_kill_tree()` (BFS sammelt die Kette bis zur Wurzel, Blatt→Wurzel TERM, nach 3 s KILL) tötet auch Waisen aus `script`/`tail`, Watchdog `secs+10` legt zusätzlich einen eigenen Timer über den Lauf, Zustand in `$_rl_pid`/`$_rl_hung`, `tool_bash` hängt daran. **Live 2026-10-06**: `sleep 20` bei `LEX_TOOL_TIMEOUT=5` → Tool-Ergebnis `Exit-Code: 124`, Turn läuft weiter. **Bewusst offen**: die Prompt-Regel „TUI nie in `script` mit innerem `timeout` ohne `--foreground`" (Verhalten, kein Code) | ✅ 2026-10-06 (Schritt 53, DE+EN 791 Checks) |
| 36 | `call_api` (HTTP 500) | Bei **149.520 Kontext-Tokens** (Session 201721, Aufgaben-Turn 00:16) lieferte llama ein **ungültiges Tool-Call-JSON** (`json.exception.parse_error.101 … column 54885: invalid string`, ~55-kB-String) → HTTP 500 → `run_turn: API-Fehler rc=1`, Turn tot; Compaction-Grenze `_default_ctx_limit=262144` war **nicht** erreicht → Grenze zu hoch, um Degeneration früh zu sehen; Erstlauf `022414` (1 Request, 0 Tool-Calls) passt zum Muster; Neustart in frischer Session lief stabil (19 Turns, 35 % Kontext) | ✅ **Schritt 53/55**: Retry-Schleife in `call_api` (429/5xx + curl-rc, max. 2 Wiederholungen; `_retry_delay` 0.8/1.6/3.2 s, Deckel 8 s, Jitter ±25 %), Config-Knob `api_retries`/`LEX_API_RETRIES` (Default 2 wie der OpenAI-SDK, Clamp ≤10); Fehlermeldungen nennen HTTP-Code, Body-Snippet (400 B), Byte-Anzahl, Versuchszahl und — bei `parse_error`/`invalid string` — den Hinweis auf Spezialzeichen/Größe in Tool-Argumenten; **Schritt 55**: 85-%-Warnung **unabhängig von `LEX_COMPACT`** (Re-Arm über `_compact_warned`, Warnung pro „fast voll"-Periode) **+ Pinning-Block** in `_compact_prompt` (Ziel/Plan/Entscheidungen/Pfade wandern immer in die neue Struktur). **Bewusst**: Schwelle `_default_ctx_limit` bleibt 262144, Warnmarke 85 % statt der angedachten 60 %, kein Kürzen alter Turns | ✅ 2026-10-06 (Schritte 53+55, DE+EN 791 Checks) |
| 37 | `run_turn`-Rendering (Reasoning-Block + Abschlussbericht) | Trotz explizitem Auftrag „Passwörter NIE in Ausgabe oder Log" zeigte die Reasoning-Ansicht und der Endbericht das Config-**Passwort im Klartext** (der Verneinungssatz enthielt es selbst); `lex.log` sauber, `session.jsonl` nur durch 600-Regel begrenzt | ✅ **Schritt 53**: `_redact()` als einziger Redaktor (eigener API-Key wörtlich, Schlüssel-Wert-Paare `password|secret|token|apikey|auth|…`, `Bearer`/`Basic`, Token-Präfixe `sk-`/`ghp-`/`xox…`, URL-Credentials) an **genau vier Verlass-Pfaden**: `log()`, `session_write()`, Anzeige (`_trace_result`/`_trace_reasoning`/`_md_render`) und Wiki-Schreibpfade (`tool_write_file`/`tool_append_file` unter `$_wiki_dir`). **Nicht** im Modell-Kontext (`$_messages`) und **nicht** an Config-/Script-Schreibpfaden — dort gehört der Text wörtlich weiter. Wertgruppe ist JSON-sicher (escaptes Anführungszeichenpaar als Ganzes, offene Werte ohne `"`/`\`) — **Live-Fund 2026-10-06**: der erste Entwurf fraß das `\` vor dem schließenden `"` und machte die session.jsonl-Zeile ungültig (eigener Fehler, siehe `wiki/errors/2026-10-06-redaction-brach-session-jsonl.md`); `_redact_var` hält abschließende Newlines (Zeilenzahl im Trace) | ✅ 2026-10-06 (Schritt 53, DE+EN 791 Checks) |
| 38 | `run_turn` — Tool-Wiederholungen (Fail-Gedächtnis) | Das Modell kann dieselbe Tool-Argumentation beliebig oft neu anstoßen (Re-Issue-Loop): identische Argumente **und** identisches Ergebnis, kein Fortschritt — lex lief weiter bis `max_turns` und verbrannte Kontext/Tokens; die sichtbare Text-Loop-Erkennung (Schritt 46) sieht Tool-Läufe nicht (Scope-Regel: nur sichtbarer Assistenten-Text) | ✅ **Schritt 54**: Signatur `cksum(name|args|result[0..200])` je Tool-Call, Zähler in `run_turn` (Lokals, nur pro Turn), Auswertung **nach** der Tool-Batch (mitten drin eine user-Message zu injizieren bricht das Protokoll); Schwelle 3 → **weicher Nudge** („Fail-Gedächtnis … dreimal identisch", Antwort-Pflicht „Methode ändern oder in einem Satz abschließen", danach Zähler reset) → zweiter Fund → **hart** (`return 1`, Meldung „erneut identisch"); Ergebnis-Bytes im Hash, damit ein wachsendes Ergebnis (Datei wächst, Status kippt) den Zähler zurücksetzt — damit bleibt legitimes Polling möglich; `LEX_LOOP_GUARD=off` schaltet es ab; Session-Records `{type:loop_guard}` (nudge/abort) | ✅ 2026-10-06 (Schritt 54, DE+EN 791 Checks) |
| 39 | `lex:_prompt` (Z. 2872) / REPL-Eingabe (`read -e` im Loop, Z. 4246) | User-Report 2026-10-08: „längerer Prompt, am Zeilenende wird der vorherige Text überschrieben — in jeder Fenstergröße, gnome-terminal/`TERM=xterm-256color`/Bash 5.3.9". Ursache: der Prompt wurde per `printf` auf fd1 gedruckt, `read -e` kannte seine Länge **nicht** („prompt-blind": strace zeigt `write(1,"lex> ")` + `write(2,"ESC[?2004h")`, **kein** DSR `ESC[6n`) → readline rechnete den Spaltenoffset falsch und redete die Eingabezeile beim Zeilenumbruch weg. `\[..\]`-Masken halfen nicht (werden literal ausgegeben); Variante mit rohen Farbescapes in `read -p` bewiesen korrekt | ✅ Prompt wanderte als readline-Argument in den Read: `IFS= read -e -p "$(_prompt)" input` (Z. 4246 — readline kennt Länge + Farben jetzt, rohe ESCs sind ok, bash maskiert intern); `_prompt`-Aufrufe aus dem Loop entfernt (^C-/leer-/Schleifenende bringen den Prompt nicht mehr selbst), nicht-TTY-Prompt bleibt über `[[ -t 0 ]] \|\| _prompt` vor dem Read (Tests rufen `_prompt` weiter direkt auf); statischer Anker `test_input.sh:147` festgeschrieben (continue-Pfad ohne `_prompt` **+** `read -p`-Zeile) | ✅ 2026-10-08 (`run_all` 13/13 = 852 [PASS] = 839 Einzelf, lint sauber, Live-PTY: Umbruch/Backspace/leerer Enter/Strg+C grün; `lex` 4696 → 4700 Zeilen) |
| 40 | `tool_bash` (keine Brücke Rechte→sudo) / `_sudo_gate` (Ablehnung ohne Handlungsanweisung) / bash-Tool-Description (Z. 619) | User-Frage 2026-10-08 nach Auswertung Session `anonym`: „warum benutzt lex kein sudo oder fragt nicht danach, obwohl er ‚Keine Berechtigung‘ sieht?" — Fundkette: (1) `_needs_sudo` fragt nur bei `sudo `-Wort im Kommando, bei Permission-denied **ohne** sudo-Wort kam **kein** Ask und kein Hinweis → 10× tshark „Keine Berechtigung" und `ls /var/lib/libvirt/images` liefen ohne jede Rückfrage weiter; (2) als Ask dann kam (2×, Ticket zwischenzeitlich abgelaufen nach ~35 min), schlug die Eingabe 3× fehl („maximum 3 incorrect authentication attempts") → „Abgelehnt: sudo — sudo-Ticket nicht geholt" gab dem Modell **nur den Grund, keine Handlung** → es meidete sudo seither (`sudo -n … \|\| ohne-Root`-Fallbacks) und das `chmod 644` der pcap-Datei wurde nie ausgeführt — das Gate fragte nie wieder, der User nie wieder; (3) Prompt-Regel sagte nur „sag das dann so zurück" — kein „erneut versuchen, User erinnern". Seiteneffund: die tshark-Serie war **AppArmor-Profil `tshark`** (kein sudo-Fall, `~/.config/wireshark/preferences` nicht im Profil), nicht Root-Rechte | ✅ **Drei Bausteine**: (1) `tool_bash`-Nudge bei Rechte-Fehlschlag ohne sudo-Wort im Kommando (case `Permission denied`/`Keine Berechtigung`/`not permitted`/`zugriff verweigert` → hängt „↳ fehlende Rechte: wenn Root hilft, wiederhole den Befehl mit „sudo …" — die Freigabe/Passwortfrage erscheint am Terminal des Users" an das Ergebnis); (2) `_sudo_gate_reason` um Handlungsanweisung ergänzt („— Tippe das Passwort in der sudo-Prompt am Terminal und lasse den Befehl danach erneut mit sudo laufen"); (3) bash-Tool-Description (Z. 619): „Aufgabe deshalb NICHT aufgeben: bei sudo-Ablehnung … oder Rechte-Fehlern den Befehl erneut mit sudo anfordern und dem Menschen sagen, was in der sudo-Prompt am Terminal zu tippen ist" | ✅ 2026-10-08 (**TEST +3 → `test_features` 564**, `run_all` 13/13 = **855 [PASS] = 842 Einzelf**, lint sauber, `lex` 4700 → **4711 Zeilen**) |
### Behoben 2026-10-08 — `exec 2>/dev/null` legte den stderr der GANZEN Shell still (Runde 3/6)

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 41 | `lex:_lurk_pending_lock` / `_lurk_pending_unlock` | `exec {_lp_fd}>"$1.lock" 2>/dev/null` und `exec {_lp_fd}>&- 2>/dev/null` sind `exec`-Umleitungen **OHNE Befehl** — solche Umleitungen gelten für die **ganze Shell**, nicht nur für den einen fd. Nach dem ersten Lock bzw. Unlock war fd2 dauerhaft auf `/dev/null` gerichtet. Folge im Testpfad: `test_features.sh` hält die Mock-Sperre ab Zeile 406 (O3-Rennentest) im Hauptprozess → **jede spätere `[FAIL]`-Meldung war unsichtbar**, der Läufer endete stumm mit rc 1 (damit ist die „stumme rc=1 ohne FAIL-Zeile“ vom 2026-10-08 erklärt — in run_all nicht aufgefallen, weil dort nur gezählt wird); in der REPL wären Trace, HUD und Fehlermeldungen nach dem ersten pending-Drain verschwunden | Umleitung in eine Gruppe: `{ exec {_lp_fd}>…; } 2>/dev/null` — die Gruppen-Umleitung gilt nur währenddessen, der fd bleibt der Shell erhalten (geprüft: `flock -x $fd` greift danach weiter, Schließen analog in `_lurk_pending_unlock`); Verdacht vor dem Fix per Minimal-Repro bestätigt (`exec {fd}>f 2>/dev/null; echo x >&2` → nichts) | ✅ 2026-10-08 (Runde 3/6, lint sauber, `run_all` 13/13 = **1090 [PASS]**) |

### Behoben 2026-10-10 — `/lexpen` rief `_tor_stealth_start` auf, die Funktion gab es nicht (Tor-Stealth halb eingebaut)

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 44 | `lex:cmd_lexpen` — on-Branch (`_tor_stealth_start`, damals Zeile 5525) und off-Branch (kein Stop) | Der Tor-Stealth-Bau der Session 2026-10-10 landete nur als **Aufruf**: der Python-Ersatz-Lauf fand den on-Branch-Text nicht („ALTEN ON-END NICHT GEFUNDEN") und brach mit `exit(1)` ab, **bevor** die Datei geschrieben wurde — die beiden Funktionsdefinitionen waren damit nie im Skript; anschließend schob nur noch ein `sed` den Aufruf nach, und der `_tor_stealth_stop`-Aufruf im off-Branch fehlte ganz. **Symptom (User-Report)**: `lex: Zeile 5525: _tor_stealth_start: Kommando nicht gefunden`, Moduswechsel selbst lief trotzdem weiter. **Zweiter, stiller Defekt der Rohfassung**: Exit-IP per `curl https://ifconfig.co/ip` **ohne Proxy** → hätte die echte IP als „verschleiert“ ausgegeben | Definitionen von `_tor_stealth_start`/`_tor_stealth_stop` direkt vor `cmd_lexpen`; kein Nachbau, sondern **das bereits gebaute** `stealth-observe.sh --start`/`--stop` (privates Werkzeug-Verzeichnis, Exit-Check läuft dort über `proxychains4`); Stop nur wenn `pgrep -x tor` trifft (sonst kein sudo-Prompt beim `/lexpen off`); Gates `LEX_TOR=0` und `LEX_MOCK` (sonst würden Tests beim Moduswechsel Netzzugriffe/sudo auslösen); fehlendes Skript → Warnung, kein Abbruch. **+10 Prüfungen** in `test/test_features.sh` (beide Definitionen definiert, off-Branch ruft Stop, E2E `/lexpen` ohne „Kommando nicht gefunden“ und ohne Stub-Aufruf, `--start` am Stub, beide Gates, fehlende Skript-Warnung) | ✅ 2026-10-10 (Live: `/lexpen` → Exit-Check: Exit-IP ≠ eigene öffentliche IP, rc 0; lint rc 0, `run_all` 13/13) |

### Behoben 2026-10-10 — aus der lex-REPL heraus fielen die ^C-Tests ohne Defekt rot (SIGINT-Erbgut)

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 45 | `test/test_input.sh` (5f/5g) über `test/run_all.sh`, ausgelöst von `lex:tool_bash` | **User-Report**: „wenn lex den selfcheck ausführt, bekommt er immer ein Fail — weil lex läuft und Ctrl+C nicht getestet werden kann“. Reproduziert: `test_input.sh` direkt **grün**, aus jedem Hintergrund-Job **3× FAIL** (`kein ^C im Transkript`, `rc=0 dauer=8s`, `Markierung fehlt`) — und genau so startet lex Tests (`tool_bash` → `_run_limited … &`). **Root Cause**: Bash setzt für Hintergrund-Jobs SIGINT/SIGQUIT auf „ignorieren“; die Disposition wird an `script`-PTY und getestete REPL vererbt (`SigIgn` im Kind `0x06` vs. `0x00` direkt), ein `trap` auf geerbt-ignore-Signalen ist wirkungslos → kein `^C`-Echo, keine Abbruch-Markierung. Kein Code-Defekt, `tools/selfcheck_lex.sh` selbst war rot-frei | **Reset in den Tests, nicht im Produktivcode**: beide Einstiege (`test_input.sh`, `run_all.sh`) führen `exec env --default-signal=INT bash "$0" "$@"` aus — nur wenn `/proc/$$/status`-`SigIgn` Bit 2 wirklich gesetzt ist (dadurch kein Endlos-Reset), GNU-`env`-/`/proc`-Fehlen → Verhalten wie vorher. `_run_limited` bleibt unangetastet (Schritt-51-`--foreground`-Lösung ist für den Turn-Abbruch da, nicht für Tests). Anker-Nadel: beide Einstiege müssen den Reset behalten. **Zweitfund aus derselben Reproduktion**: die Suite aus der REPL erbt `LEX_MOCK` → `test_features`-Nadel „--status (Modus=live)“ und zwei Tor-Gate-Nadeln wurden rot, weil sie den geerbten Mock sahen (nicht weil etwas defekt war) — isoliert per `env -u LEX_MOCK -u LEX_MOCK_FILE` bzw. explizitem `LEX_MOCK=""`-Prefix | ✅ 2026-10-10 (Hintergrund-Job 3× FAIL → **31 PASS/0 FAIL**; **Suite über `tool_bash` mit geerbtem Mock 13/13**; direkt ohne und mit Mock je **13/13 = 896 [PASS]**; lint + selfcheck rc 0) |

### Behoben 2026-10-12 — Sicherheits-Audit-Lauf: Gate-Kontext ≠ Ausführungskontext, totes Loop-Ende, lügende Exit-Codes, Plan ohne VERIFY (Fix-Paket §7/93)

Auslöser: User-Auftrag nach der Analyse des festgefahrenen Audit-Laufs (Session `anonym`, loop-guard hart 15:12:44, 8× identischer Hex-Dump, kein VERIFY, 1,4 GB Build-Müll): „alle lücken beheben, /lexpen root rechte für alles".

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 46 | `_task_start`: Gate im Foreground (TTY) vs. Kindkette in `setsid` | sudo speichert Tickets pro TTY (`sudoers_timestamp(5)`, `timestamp_type=tty`) — das am Terminal geholte Ticket galt in der Task-Shell **nicht**: `sudo: A terminal is required to authenticate` in t6 erst nach ~20 min Build, obwohl der Foreground-Gate längst durchgegangen war (zwei verschiedene Sicherheitskontexte) | **Preflight `_task_sudo_preflight()` IM Zielkontext** (`setsid -w sudo -n true`) VOR dem Gate: scheitert er, sofort die ehrliche Ablehnung mit Lösung (NOPASSWD eintragen oder im Foreground ausführen) statt eines späten Auth-Fehlers; kein Passwort wird für den wertlosen Kontext geholt; ohne setsid/sudo entfällt der Check | ✅ 2026-10-12 (beide Fälle im Test mit Fake-sudo) |
| 47 | `_sudo_gate` / `cmd_lexpen` | `/lexpen` hatte **keine** sudo-Kopplung — im Root-Modus liefen y/N-Freigabe, Sitzungsfrage und Passwort-Pfad normal weiter (User-Auftrag: „im lexpen-modus kein sudo mehr gebraucht") | Auto-Grant-Zweig direkt nach der `LEX_SUDO=0`-Sperre: Ticket gültig oder Passwort-Pfad als harter Fallback, **ohne** y/N, **ohne** Sitzungsfrage; wirksam ab NOPASSWD (§2) — **Phase E: Ticket wird beim `/lexpen on` einmal geholt, NOPASSWD entfernt**; `LEX_SUDO=0` bleibt harte Sperre | ✅ 2026-10-12 (Gate-Test mit Grant-/Approve-Sentinels, ohne TTY; Live-Beleg 18:02) |
| 48 | `run_turn`: Loop-/Silent-Guard hart | Beide hart-Abbrüche warfen `return 1` **ohne eine einzige Antwortzeile** — der User sah nur stderr und nichts zum Stand (Dead End; genau der Zustand nach 15:12:44) | **Graceful-End**: erster hart → erzwungene Abschluss-Runde OHNE Werkzeuge (`_guard_final`; Rest-`tool_calls` werden vor dem Message-Bau verworfen → protokollkonform), Leer-Antwort → bestehende Nudge-Kette; zweiter hart → `break` + **Sicherheitsnetz rendert den Teiltext** statt blankem `rc 1`. Zusätzlich **Fehler-Serie**: ≥6 bash-Aufrufe in Folge mit rc≠0 bei wechselnden Args (der Fall, den die exakte Signatur nicht trifft) → weicher Anstoß „Methode wechseln", Session-Record `type:fail_streak` | ✅ 2026-10-12 |
| 49 | `tool_bash` / Task-Runner | `\| tail` lieferte den rc von `tail` (immer 0) → Modell sah „Exit-Code: 0" und schrieb trotz gescheitertem Zeek-Build „=== ZEEK INSTALLIERT ===" — ein Verifikat, das nie verifiziert war | Kindkette **beider** Ausführungspfade mit `bash -o pipefail -c` — der gemeldete rc ist der der Kette; die Bash-Tool-Beschreibung sagt es dem Modell jetzt vorab | ✅ 2026-10-12 (+2 Checks) |
| 50 | `_prompt_ops` / `task start` | Der Audit-Auftrag sprang ohne Plan und ohne Verifikationsziel ans Bauen — die Prompt-Regel allein griff nicht (die Baseline `Baseline/<netztest-baselines/ssh_cut.log` wurde nie geöffnet, VERIFY nie erfüllt) | **Verifikationsziel-Pflicht** im Ops-Layer (gilt auch in `/lexpen`): vor dem ersten Schritt ein Satz „fertig = <messbares Kriterium>", ohne erfülltes Ziel keine Fertig-Meldung; dazu **weiche** Erinnerung im `task start`-Ergebnis, solange `plans/plan.md` leer ist. Bewusst KEIN hartes Gate (würde auch Klein-Tasks wie `nmap -T0` blockieren) | ✅ 2026-10-12 |

| 51 | `/etc/sudoers.d/<datei>` + `_sudo_gate`/`cmd_lexpen` | NOPASSWD:ALL war **global** aktiv (User-Auftrag „/lexpen root rechte für alles" war als „nur mit /lexpen, nicht global" gemeint): sudo fragte nie ein Passwort — auch für andere Prozesse, auch mit `/lexpen off` | **Scope-Korrektur (Phase E)**: Datei um 18:02 entfernt (`sudo -n true` → rc 1 bestätigt, Verzeichnis nur noch `README`); `/lexpen on` holt das Ticket **einmal** via `_sudo_ask` (Passwort direkt an sudo), `/lexpen off` wischt es (`sudo -k`, bewusst **nach** dem Tor-Stop, weil `stealth-observe.sh --stop` selbst `sudo systemctl stop tor` braucht); `LEX_MOCK`-Guard schützt Tests vor hängenden Passwortzeilen; Gate-/Preflight-/Task-Texte: Foreground zuerst, NOPASSWD nur noch als optionale, global wirkende Alternative | ✅ 2026-10-12 (15/15 = 1024 [PASS]; Live: Passwortfrage bei `/lexpen on`, Ctrl-C → Hinweis, `/lexpen off` → „✓ Original wieder aktiv") |

**Tests**: +33 Checks (991 → **1024** = 1009 Einzelf), 15 Läufer grün, 87 s — neu/geändert: `test_loop` (Graceful-End rc=0 + `action:final` + Turn-Start-Reset + Sicherheitsnetz-Anker + fail-streak), `test_features` (lexpen-Gate mit Sentinels, Preflight beider Fälle mit Fake-sudo inkl. Flag-Filter, Plan-Erinnerung mit/ohne Plan, Prompt-/Schema-Nadeln, **Phase E: +4 statische lexpen-Nadeln**), `test_tools` (pipefail: rc der Kette + Erfolg rc-frei).

### Behoben 2026-10-13 — MCP-Env-Erbe (`export -a`) und zerfallener `_mcp_config()`-Fallback (Fix-Paket §7/99)

Auslöser: Session-Audit `anonym` (User-Symptom „handshake version conflict", User-Auftrag „alle 3 Befunde fixen"). Die Handshake-Erklärung steht in §7/99 — dort steht auch, dass der gemeldete Konflikt nicht existiert.

| # | Ort | Problem | Fix | Status |
|---|-----|---------|-----|--------|
| 52 | `coproc MCPSRV { export -a … }` | `export -a K=V` legt eine **Array-Variable** `K` an, keine skalare Umgebungsvariable — die Kind-Shell bekam `COMPUTER_USE_LINUX_ENABLE_SHELL` nie mit. Beweis: `bash -c 'export -a FOO=bar; exec env' \| grep -c '^FOO='` → **0** (ohne `-a` → 1); E2E durch den echten Coproc: mit `-a` fehlte `run_shell` im `tools/list`, ohne `-a` war es da (Index 12). Der `env`-Block wirkte also nie — `desktop.env` in der mcp.json sah korrekt aus, kam aber nicht an | `export "${_env_vars[@]}"` (lex:2795, mit Kommentar, Vorzeichen-Beweis im Klartext) | ✅ 2026-10-13 |
| 53 | `_mcp_config()` (Fallback ohne jq) | Fallback-JQ-Programm **ohne** `env`-Slot und mit `($HOME)`-Variable, die es nicht gab: duplizierte Server-Keys (18 statt 5 eindeutige) **und** fehlendes Komma → der Fallback hätte gar keinen gültigen `mcp.json` schreiben können, obwohl ein `env`-Block existierte; die Duplicate hätten rmcp/`jq`-Ladefehler provoziert | `($HOME)` → `\($h)`, ein `env`-Slot je Server, Deduplizierung auf 5 Server (lex:2481–2506) | ✅ 2026-10-13 |
| 54 | **Klasse: Pipe-Kürzung/-Filter unter `pipefail`** — Prompt-Regel `lex:641` lehrte `<Befehl> --help \| head -30 && <Befehl> <flags>` | **Vierter Fund derselben Klasse** (§6 #24 `ss \| grep -q` → rc 141 „kein Server"; `lex:327` zweiter rc-141-Fund; `lex:1943` `make \| tail -3` → rc 0 trotz gescheitertem Build; heute `ffuf \| head -30` → EPIPE/Hang, weil ffuf Fortschritt puffert und weiterschreibt, nachdem `head` die Pipe schloss). **Zwei Widersprüche in einem Bullet**: (a) unter `bash -o pipefail` (`lex:1947`) liefert die Pipe-Kürzung rc 141 → `&&` bricht ab → der zweite Befehl läuft **nie**, die Regel erzeugt also genau den Turnverlust, den sie verhindern soll; (b) die Kürzung läuft seit 2026-09-30 **zentral via Spill** (§0.1 C) — Pipe-Kürzung ist redundant, und die einzige Stelle, die sie noch lehrte, war der eigene System-Prompt. Nicht das Modell hat das Muster erfunden, die Architektur hat es vorgeschrieben | Prompt-Bullet `lex:641` (kein Zeilen-Shift): Hilfe ungeschnitten ausgeben (Kürzung übernimmt zentral der Spill), **nie in die Pipe eines laufenden Tools kürzen** — Verweis auf diese Klasse; Nadeln „Nicht raten, nachschlagen"/`<Befehl> --help` bleiben (`test_features.sh:1726–1727`) | ✅ 2026-10-20 |
| 55 | **Globale Frist als Zeitplan für unschätzbare Läufe** — `tool_bash` kannte nur den globalen `_tool_timeout` | Die Laufzeit eines Recon-Laufs hängt von Zielgeschwindigkeit, Rate-Limit und Paketverlust ab — **nicht schätzbar**; ein globaler Fristsetzer zwingt das Modell also zu einer Schätzung, die immer falsch ist (zu kurz tötet legitime Läufe, zu lang blockiert). Die Architektur verwechselte zwei Dinge: **Frist ≠ Aufsicht** — `_run_limited` ist das Sicherheitsnetz gegen echte Hänger (§6 O7, nmap 9736 s), kein Zeitplan | **Frist gehört ins Werkzeug** (`-maxtime` ffuf, `--host-timeout` nmap, wo der Lauf sauber abbricht: rc + volle Ausgabe) und für Werkzeuge ohne eigene Frist ein **pro-Call-`timeout`-Parameter** (Sekunden) in `tool_bash` + bash-Schema; Regel in Prompt-Bullet `lex:641` („Nicht raten" gilt auch für Laufzeiten) + `scan-flags`-Skill; Werte <1/nicht-ganzzahlig → stiller Rückfall auf den Default | ✅ 2026-10-20 |
| 56 | **`_run_limited`: Frist-Hinweis war toter Code** (durch die neue §6 #55-Nadel sichtbar gemacht — genau der Effekt des Prinzips §0.1 A.8) | Zeilenfolge `rm -f "$tf" "$flag" "$dl"` **vor** der Prüfung `[[ -s "$dl" ]]` → die Prüfung traf **nie** zu, der „Hinweis: Zeitlimit erreicht"-Text und der `log`-Aufruf liefen nie; dazu `-s` statt `-e` (der Watchdog legt `$dl` per `: >` **leer** an — dieselbe Halb-Korrektur wie CI 2026-10-19, die nur die erste Prüfung in `[[ -e "$dl" ]]` für rc=124 fixte). Und latent zweitens: `out=$'\n'…` **überschrieb** den Werkzeug-Output statt anzuhängen → bei jedem abgelaufenen Lauf wäre die komplette Ausgabe weggefallen und das Modell hätte nur „Exit-Code: 124" ohne jede Erklärung gesehen | Prüfung **vor** dem `rm`, `-s`→`-e`, `out+=` statt `out=` (Werkzeug-Output bleibt, Hinweis wird angehängt); 2 Nadeln: Frist-Meldung erscheint **und** Vorher-Output bleibt erhalten | ✅ 2026-10-20 |
| 57 | **Slot-0-Montage vergaß Präferenzen; `soul.md` war ein totes Phantom** (Session-Audit `anonym`, User-GO „ja fixe es und warum funktioniert soul.md nicht") — **zwei Defekte, eine Klasse** (§0.1 A.8: Prompt-Bausteine ohne gemeinsame Montage-Stelle) | (a) **`_swap_slot0` baute Slot 0 ohne `$(_mem_pref_ex)`** — nur `${_system_prompt}$(_skills_ex)$(_wiki_ex)`. Die Präferenzen lagen im Prompt, wenn die Session per `setup_messages` startete, und **fielen still raus, sobald `/lexpen` den Slot neu montierte**. Beweis: Session `prompt_mode=lexpen` 07:29:12, danach lief die ganze Session ohne Ton-Präferenz — Lex' Selbstdiagnose „Regel ist da, ich habe sie verletzt" war damit **halb falsch**: die Regel existierte (`mem/20261012105558-ton`, type: preference), war aber physisch nicht mehr im Kontext. (b) **`_soul_ex` existierte nirgends im File** — `~/.lex/soul.md` (2026-10-10 angelegt) und der Wiki-Eintrag behaupteten im Kopf, lex läde sie; `grep -c _soul_ex lex` = **0**. Forensik: die Funktion war 2026-10-10 nur im EN-Spiegel (englisches Auslieferungs-Repo) gebaut worden, im DE-Working-Tree nie committet und dann verloren; alle DE-Commits durchsucht (`git log --all`), EN-History gepurgt, `lex.bak` vom 13.10. enthielt sie auch nicht. Zusätzlich widersprach der alte soul-Inhalt der aktiven Präferenz vom 12.10. (ein Ton in ALLEN Modi) — er hätte nach der Wiederbelebung den falschen Ton injiziert | **Klassen-Fix statt Zwei-Instanzen-Fix**: `_soul_ex()` wiederhergestellt (lex:1096, `-s`-Gate + Whitespace-Gate, Kopf mit Pfad/Zeilenzahl, Geltungssatz „gilt in ALLEN Modi") und — anders als der 2026-10-10er Bau — an **BEIDEN** Montagestellen eingehängt; `_swap_slot0` (lex:5877) montiert jetzt **byte-identisch** zu `setup_messages` (lex:1108): `${_system_prompt}$(_mem_pref_ex)$(_skills_ex)$(_wiki_ex)$(_soul_ex)` — Reihenfolge IST Gewichtung, Seele ganz hinten = höchste Stil-Rang; `cmd_status` (lex:5581) zeigt `soul : <pfad> (N Zeilen, dynamisch …)` bzw. `(fehlt …)`; `~/.lex/soul.md` neu geschrieben auf Stand 12.10. + Begrüßungs-Regel (kontextabhängig, kein starrer Eröffner) | **Klassen-Nadel** in `test/test_soul.sh` (27 Nadeln): Slot 0 startet **minimal** (`NUR_BASIS_PROMPT`), `_swap_slot0 default` MUSS Präferenz **und** Skill **und** Seele hinzufügen — prüft die KLASSE, nicht nur einen Fall; dazu Gate-/Kopf-/Rang-/status-Nadeln. **Negative Probe** (Kopie mit aufgerissener swap-Kette) → 8× [FAIL]; feinere Probe (nur `_swap_slot0` gebrochen, `setup_messages` heil) → genau die 3 swap-Nadeln fallen, die setup-Nadeln bleiben grün | ✅ 2026-10-26 |

| 58 | **Bestehende Kürzungs-Regeln griffen codeseitig nie** (5. Kürzungs-Fund §0.1 A.8 → Klasseneintrag; User-Vorgabe „es darf nichts abgeschnitten werden"; Session-Messung 2026-10-27: 1240/2145 bash-Calls pipeten nach head/tail, u.a. die Windows-Fehlersession, wo ein head-Schnitt mitten im fertigen Report den `.21`-Eintrag fraß; Prompt und `/help` behaupteten eine Pipe-Deny, der Code kannte nur das Download-Muster) | **§7/122 — vier Fixes**: (a) `_bash_denied` (lex:1677) lehnt Kürzungs-Pipes `| head`/`| tail` hart ab (Meldung mit Handlungsalternative `wc -l`); erlaubt bleiben Filter-Pipes (grep/sort/wc/jq — keine Kürzung) und Standalone-Log-Fenster `tail -n N log` (61 legitime Funde); (b) Prompt-Bullet, `/help` und bash-Schema nennen die Kürzungs-Pipes jetzt korrekt; (c) sichtbare Marker statt stiller Kürzung: `tool_web_fetch` (lex:2920) hängt „[gekürzt: N von max M …]" an (A3-Messung: 13/13 gekürzte Antworten ohne Marker), `_wiki_ex` (lex:924) nennt Fenster und vollständigen Pfad („letzte 40 von N Zeilen — vollständig unter …"); (d) `LEX_REASONING_STORE_MAX` 20000 → 40000 (41 Kappungen, Originallängen median 31 238 / max 33 971 — 40000 deckt 41/41) | ✅ 2026-10-27 |

**Tests**: +10 Nadeln in `test_features.sh` (Einzelf 1012 → **1022**, 15/15 = **1037** [PASS], 89 s, rc 0): 2× `_mcp_env_vars` funktional (array+export), `env`-Funktion liefert Werte, Coproc ohne `-a` im Quelltext, **kein `export -a` irgendwo im lex-Code**, **E2E durch den Coproc** (Probe-Server schreibt `${COMPUTER_USE_LINUX_ENABLE_SHELL:-unset}` nach `$TMP/env_probe.txt`, Nadeln sind `=1`), mcp.json-`env`-Block an beiden Ableitungspfaden, 2× Default-Config. **Negative Probe**: Kopie mit wieder eingebautem `export -a` → **3× [FAIL]** inkl. der E2E-Nadel (die Nadeln beißen wirklich). Zuvor entbehrlich gewordene weiche Nadeln wurden ersetzt, nicht entfernt.

**Tests zu §6 #57** (2026-10-26): neues `test/test_soul.sh` mit **27 Nadeln** (Gate fehlend/leer/Whitespace, Blockkopf + Geltungssatz, `setup_messages`-Integration inkl. Rang-Offsets, **Klassen-Nadel `_swap_slot0`**, `--status` in beiden Zuständen, Slot-0-Rollen-Integrität) — in `run_all.sh` registriert (`run_test "soul"`), sonst testboden-Orphan-Fail. **Negative Probe** (Kopie mit aufgerissener Montage-Kette) → 8× [FAIL]; **feinere Probe** (nur `_swap_slot0` gebrochen) → genau die 3 swap-Nadeln fallen, die setup-Nadeln bleiben grün. Gesamt: **16/16 = 1105 [PASS], 0 FAIL**, `bash -n` + `shellcheck -S warning` + `selfcheck` rc 0, `wc -l lex` = **6313**.

**Tests zu §6 #58** (2026-10-27): +13 Nadeln in `test_features.sh` (Einzelf 1089 → **1102**, 16/16 = **1118 [PASS]**, 0 FAIL): 5× head/tail-Pipe-Deny (inkl. `| HEAD` in Großschrift, `nmap …| head`, `head` ohne Argument), 3× erlaubt-Bleiben (grep-Pipe = Filter, wc-Pipe = Zählung, Standalone-Log-Fenster `tail -n N log`), 2× web_fetch-Knapp-Marker (Grenze erreicht → Marker da / ohne Kürzung → keiner), 2× `_wiki_ex`-Fenster-Marker (Zeilenzahl + vollständiger Pfad), 1× Default-Cap 40000 (30000-Zeichen-Reasoning unkappt — unter altem Default wäre es gekappt). **Negative Probe** (Kopie mit allen vier Defekten) → alle vier Nadeln-Gruppen fallen. `bash -n` + `shellcheck -S warning` + `selfcheck` rc 0, `wc -l lex` = **6342**.

## 7. Nächste Schritte (Reihenfolge)

> **Diese Fassung enthält keinen Betriebslog.** Der vollständige Schritt-Verlauf
> (§7/1 … §7/124) liegt in der privaten Arbeitskopie und wird hier nicht
> mitgeliefert. Gleiches gilt für den privaten Wissens-Log (`wiki/log.md`) —
> diese Auslieferung bringt `wiki/` als leeres Skelett mit, das eigene Wissen
> wächst ab dem ersten Schritt selbst.

So arbeitest du hier weiter:

1. **Stand prüfen** (30 Sekunden): `bash -n ~/Ai/lex/lex` und
   `LEX_MOCK=done bash ~/Ai/lex/test/run_all.sh` — 19 Läufer müssen grün sein.
   `ai status` zeigt Server, Modell und VRAM.
2. **Nächste Aufgabe** aus §8 (Recherche-Agenda), §9 (offene Fragen) oder
   §10 (Roadmap) wählen — eine in-flight-Aufgabe maximal, nicht springen
   (§0.1 A.3).
3. **Arbeiten nach §0.1**: SIT → ENTSCHEIDUNG (Zeile in §2 oder §6) → PLAN →
   BUILD → VERIFY → LOG → SYNC → REVIEW. Definition of Done in §0.1 E.
4. **Neuen Schritt anhängen** — Format wie bisher: Nummer, Titel, Datum,
   Auftrag, Belege mit `datei:zeile`, VERIFY-Ergebnis mit Zahlen.
5. **Kein Commit, kein Push ohne Freigabe** (§12). Öffentliche Auslieferung
   geht ausschließlich über das dafür vorgesehene Repo.

---

## 8. Recherche-Agenda (priorisiert, Stand 2026-09-28)

### A. Modell-Fähigkeit — GRÖSSTES RISIKO
**✅ erledigt 2026-10-07 (§7/66) — Befund: Modell behalten, Harness weiterbauen.** 20 Läufe (4 Szenarien × 5, seriell, echtes Modell, isoliertes `LEX_HOME` pro Lauf); zweite Instanz auf 8081 (Plan-Zweig B) scheiterte an VRAM (15,25/17,16 GiB belegt, `cudaMalloc failed`) → geteilter 8080 (Zweig A). **Zahlen: 20/20 rc=0, 100 % valider `tool_calls`-JSON** (0 invalid, 0 HTTP-Fehler, 0 Leer-Antwort-Abbrüche), **Parallel-Calls 5/5 in EINER Message** (maxpar=2, Antworten korrekt), Multi-Turn mit `role:tool` stabil (2–3 Calls, Stichprobe korrekt), `finish_reason=length` → **16 Nudge-Ereignisse, 5/5 sauber fertiggeschrieben (rc=0)**; Ø 12–19 s je Lauf. Anomalie: 1 Hänger >5 min im ersten (gekillten) Durchgang, nicht reproduziert → Lauf-`timeout 300` bleibt Pflicht. Artefakte: `~/Ai/test-szenarien/benchmark/adherence/` (`run_bench.sh`, `results.csv`, `runs/`, `report.md`). Ursprüngliche Fragen (Stand 2026-09-28):
- Wie oft valider `tool_calls`-JSON? Werden **Parallel**-Calls emittiert? Verhalten bei `finish_reason=length`?
- Tool-Call-Stabilität über Multi-Turn mit `role:tool`-Rückgaben
- Ergebnis entscheidet: Harness weiterbauen, Modell wechseln (z. B. Qwen3-Coder) oder Scaffolding anpassen

### B. Wettbewerb — Lücken-Claim ist überholt
**✅ neu bewertet 2026-10-07 (§7/68).** „Lex ist der einzige lokal-first" ist endgültig tot — Local-first ist commodity (opencode selbst: 195k★, lokale Modelle inkl.). **Feld-Update Stand 2026-10-07:**
- **apogee** (Go, `airiclenz/apogee`, v0.22.6, aktiv) — der schärfste direkte Konkurrent: jeder OpenAI-kompatible Endpunkt, **OS-Fencing Landlock/Seatbelt/Windows-Token**, „seven always-on guards", gated mechanisms (context compression, tool-call validation + auto-retry, behavioural nudges, cross-session learning Library) = lex' Mechanismen 1:1, dazu MCP, sub-agents, skills, eval-bench (`apogee-sim`), headless/daemon, single binary
- **whet** (Rust, `kuroko1t/whet`) nachweislich live; **VTCode** (Rust, defense-in-depth, Skills/MCP/subagents), **ZAP** (Rust, AST-Index, SLM-first-class), **sandbase-harness** (674★, Runtime), **landstrip** (73★, OS-Sandbox-Layer mit opencode-Plugin), `dvalincode`, `lutelute/local-cli` (Python, zero-dep), `LocalCode` (Node, LSP), `llmcode`/`llmc-code` (Python, local-model-first)
- **Bash-Zeitgenosse**: `andyk/shellm` (13★, „of bash, by bash") — **anderes Paradigma** (LLM schreibt ausführbare Bash-Snippets statt strukturiertem Tool-Loop), kein Session/Compaction/Guard-Äquivalent; dessen `mem` (md + YAML-Frontmatter) zeigt: **der md-Memory-Ansatz ist nicht mehr einzigartig**
- **Deutsch**: **kein einziger deutschsprachiger Coding-Agent im Feld gefunden** — dieser Differentiator hält.

**Bewertung — was bleibt real different:** (1) **reines Bash, eine Datei, 5134 Zeilen, auditierbar, null Toolchain** bei vollem Feature-Set (Session/Compaction/Memory/17 Tools/Guards) — im Feld nach wie vor einzigartig; (2) **Deutsch-first** (Prompt/Persona/Doku/Wiki) — einzigartig, aber internationaler Nischenwert (EN-Antwort: das englische Auslieferungs-Repo). **Was verloren geht:** „local-first" selbst und die Sandbox als Verkaufsargument — Landlock ist bei apogee/landstrip/VTCode **Standard** geworden → §8 E/Phase 5 bleibt **Sicherheits-Pflicht**, verliert aber Differenzierungswert.

**Konsequenz für §9/Phase 6:** HN-Winkel = „the auditable one-file bash agent" (Komplexität/Audit vs. 195k★-Ökosystem), **nicht** „local-first"; Deutsch nur als Nebennotiz; Name-Verfügbarkeit (§9/1) vor Release klären.

### C. Name & Recht
**✅ geprüft 2026-10-07 (§7/69).**
- **flex-Kollision (theoretisch, praktisch entwärmt)**: Debian/OpenBSD-`flex` legt `/usr/bin/lex` an; lex hat **keinen System-Installationspfad** (`install_lex` erzeugt nur `~/.lex/*`, kein Kopieren nach `/usr/local/bin`), Betrieb läuft über den Symlink `~/.local/bin/lex` → in `PATH` **vor** `/usr/bin` (Position 3 vs. 8). Selbst `/usr/local/bin/lex` stünde vor `/usr/bin`. **Empfehlung: Installation ausschließlich nach `~/.local/bin`** (EN-`install.sh` macht genau das; kein sudo, kein `/usr/local`).
- **GitHub**: privates DE-Repo hat **keinen remote** (kein Namenskonflikt möglich); EN-Release = `<github-owner>/Lex-Bash-Agent`; `<github-owner>/lex` ist **frei** (API-404). Globale Namensfülle (`lexical`, `doctrine/lexer`, `lexbor` …) ist unkritisch — Repo-Namen sind nur beim Owner eindeutig.
- **Homebrew**: Formel `lex` **frei** (formulae.brew.sh 404) — `flex` heißt `flex`, also keine Formel-Kollision; eigene Formel erst nach Release (Phase 6) einreichen.
- **Domain**: `lex.dev` / `lex.sh` / `lex.ai` / `lex.tools` / `lex.run` **alle auflösend = belegt** → lex.* als Release-Argument entfällt; HN-Winkel braucht keine Domain (§8 B).
- ~~Apache-2.0-Datei anlegen~~ → **MIT gewählt** (2026-09-28, `LICENSE` vorhanden, Copyright „lex-Mitwirkende")
- → **Fakten-Input für §9/1 (Endentscheidung Name/Repo/Formel bleibt offen).**

### D. Portabilitäts-Baseline
Welche GNU-Tools garantiert auf macOS 14 / Termux / iSH / Pi? Bash 3.2-Kompatibilität entscheiden (feature-gated) oder Mindestversion 4 explizit machen **und testen**.
→ **✅ entschieden 2026-10-07 (§7/70): Mindestversion Bash 4, explizit erzwungen.** **Befund**: die Behauptung „keine Bash-4-only-Konstrukte" (Stand 2026-09-28) war **falsch** — `coproc MCPSRV { … }` in der MCP-Session-Funktion (`lex`, Session-Wiederverwendung) ist ein **Bash-4.0-Reserviertes Wort**; auf 3.2 (macOS-Systembash) scheitert das Parsen der Datei. Statischer Scan über `lex` + `tools/*.sh` nach `declare -A/-n/-g`, `mapfile`/`readarray`, `${v,,}`/`${v^^}`, `&>>`, `|&`, `[[ -v ]]`, `;;&`, `wait -n`, `read -N/-i`, `exec {fd}`, `${v@Q}`, `coproc`: **genau ein Treffer = coproc** (die `[-1]`-Treffer sind jq-Code, kein Bash). **Warum nicht 3.2-Umbau**: coproc ist für die bidirektionale MCP-stdio-Session strukturell richtig; FIFO-Ersatz würde eine lauffähige Kernfunktion (Schritt 9/23, Session-Reuse) riskieren, ohne realistische Zielgruppe — Linux-Feld hat Bash ≥ 4 (Ubuntu 20.04+/Debian 10+/Termux/RPi = 5). **Gebaut**: Versions-Guard im Dateikopf (`(( BASH_VERSINFO[0] < 4 ))` → klare Meldung + `exit 1`, läuft **vor** dem coproc-Block statt Syntaxfehler; `BASH_VERSINFO` ist readonly → Verhaltens-Test nicht möglich, statische Anker stattdessen) + README-Voraussetzungstabelle korrigiert. `realpath`/`readlink -f`/`timeout`-Fallbacks bleiben. **Nachgeholt 2026-10-07 (User-Freigabe, `docker pull bash:3.2`)** — Doppelbeweis: (1) `bash -n /lex/lex` auf 3.2 → Syntaxfehler **exakt bei `coproc`** (Z.2253, rc 2) belegt die Bruchstelle; (2) `bash /lex/lex --version` auf 3.2 → Guard-Meldung `braucht Bash >= 4 (gefunden 3.2) — macOS: brew install bash …` + **rc 1** statt Parser-Crash. **Weiter offen**: tatsächliches Testen auf macOS/Termux/iSH.

### E. Sicherheitsmodell
allow/deny-Globs (grok-`Bash(...)`-Syntax), Approval-Gate, Landlock (`eugene1g/agent-safehouse`). Bedrohungsmodell schreiben: was darf `bash` grundsätzlich nicht.
→ **✅ Bedrohungsmodell geschrieben 2026-10-07 (§7/71)**: `wiki/concepts/sicherheitsmodell.md` (+ index.md-Zeile). **Kern**: Vertrauensmodell „Verbote richten sich gegen das Modell, nicht gegen den User" (LLM = unzuverlässiger Akteur, Prompt-Injection möglich); Schutzobjekte (System, User-Daten, Sekrete, Audit, Netz); **10 harte Verbote** exakt aus dem Code (rm-Wurzeln, Blockgeräte, Fork-Bombe, shutdown, System-Kills, Rechte aufweichen, History-Wisch, `su`, curl-Direktausführung — segmentweise Deny-Liste, immer aktiv); sudo als 4-Stufen-Gate (Sperre → Passwort-Ticket hart → y/N/`/autosudo` → Sitzungs-Freigabe, kein TTY = Ablehnung); Defense-in-Depth-Tabelle; **ehrliche Lückenliste** (Blacklist statt Whitelist = bewusst, Prompt-Injection nur per Gate/Audit abgefedert, Landlock fehlt → Phase 5, Shared-Server nur per Config/Prompt). **Weiter offen**: Glob-Syntax für erlaubte Pfade/Muster (Whitelist-Ausbau), **Landlock-Sandbox** (§8 B: im Feld Standard geworden → Pflicht, aber kein Differenzierer mehr), Security-Kurzfassung ins README bei Release.~~Stand 2026-09-28: harte Deny-Liste + opt-in Approval gebaut~~ (ist enthalten).

### F. Teststrategie
~~Der Mock umgeht `curl` vollständig → der HTTP-Pfad ist ungetestet.~~ **✅ 2026-09-28 abgeschlossen**: Fake-Server über `ncat` (`test/fake_server.sh`), `test_http.sh` in `run_all.sh`, dazu Golden-File-Assertions via `LEX_MOCK_FILE`. ✅ 2026-10-28 erledigt (#124)**: golden files (`test/fixtures/` + `test_golden.sh`), Lasttests (`test_load.sh`), Fuzzing (`test_fuzz.sh`).

### G. Kontext/Token
Wie zählt Bash Tokens (kein Tokenizer)? ~~Wann greift Compaction?~~ **✅ 2026-10-02 (Schritt 42) beantwortet und gebaut:** lex schätzt über `wc -c/3` (bewusst kein Tokenizer; Live-Messung 3.30 B/Tok, `/4` lag 18 % zu tief), greift ab `ctx − max(max_tokens, buffer)` (Default 160224 von 180224); HUD zeigt die Auslastung als `X/Y (%)`. **Schätzer-Güte live vermessen 2026-10-02** (57396 B ⇔ 17408 Token): Divisor 3, Tool-Schemas (~5–6k Tokens) fehlen in der Nachrichtenschätzung und sind in der Marge mitabgedeckt.

---

## 9. Offene Fragen (einmal, nicht viermal)

1. **Name/Repo**: `lex`? `project-lex`? (siehe §8 C — `lex` ist belegt)
2. **LLM-Backend**: nur lokal oder auch Cloud?
3. ~~**CI**: GitHub Actions oder self-hosted?~~ → **veraltet (2026-10-28)**: kein öffentliches Repo, kein CI-Bedarf — vor §10 Phase 6 neu bewerten (19 Läufer laufen lokal grün)
4. ~~**Release-Timing**: v0.1.0 nach Fundament oder erst nach Phase 1?~~ → **veraltet (2026-10-28)**: Test-Paket deutlich über dem damaligen Ziel (19 Läufer inkl. Golden/Load/Fuzz, §7/124) — HN-/Release-Timing gehört in §10 Phase 6
5. **Plugin-Architektur**: wie `wedow/harness` (Tools/Hooks als Exekutables, jede Sprache) oder fixed wie bashagt?
6. **Persistent Agency / Multi-player**: nein (fokussiert, Single-User) — nur dokumentieren, nicht neu diskutieren
7. ~~**`reasoning_budget`**: lex 1024 vs. `ai.sh --reasoning-budget 4096`?~~ → **ENTSCHEIDEN 2026-09-28: 4096.** Das Request-Feld gewinnt, lex hat damit das Server-Flag überschrieben; jetzt synchron. `max_tokens=8192` bleibt (§6 #5). **Nicht live verifiziert** — der einzige freigegebene Live-Request lief noch mit 1024; nächster Live-Test prüft es. → **erledigt (live bestätigt 4096 am 2026-09-28); 2026-09-29 auf 8192/16384 angehoben** (Gesamtprüfung G1, §2/§4 aktualisiert).

8. ~~**Guard-Schwellen (Fail-Streak 6, Silent 12)**~~ → **ENTSCHEIDEN 2026-10-17 (User-Auftrag): Fail-Streak 6 → 3**, Silent-Guard (12 stille Turns) und Loop-Guard unangetastet. Session 20261016 rutschte 4× hintereinander in dieselbe psql-Katalog-Raten (13:16:17–13:16:44) und wechselte erst beim 5. Versuch auf `\d findings` — die alte Grenze 6 wurde **nicht** erreicht, und der Silent-Guard bestraft „kein sichtbarer Text“, nicht „falsches Werkzeug“. Gebaut + belegt in §7/110 (Nadeln in **beide** Richtungen: 3 Fehlschläge → Anstoß, 2 → keiner; Meldungstext auf „Drei bash-Aufrufe“ umgestellt). Weitere Senkung nur mit neuer Begründung.

---

## 10. Roadmap (Kurzfassung)

| Phase | Ziel |
|---|---|
| **0 (ABGESCHLOSSEN 2026-09-28)** | Loop + 8 Tools + Session/Memory + Sicherheit + 6 Testläufer + CI + Doku + **v0.1.0** (Docker entfällt) |
| 1 | ~~SSE-Streaming, `finish_reason`-safeguards, Zero-Fork-Hot-Path, Readline, Plugin-Struktur, `todo_write`~~ **✅ 2026-10-07 konsolidiert (§7/67)**: SSE-Streaming (`stream:true` + `stream_options.include_usage`, `_sse_to_response` ein jq-Lauf — live verifiziert Benchmark §7/66; Live-Anzeige während Generierung bewusst nicht, Schritt 36), `finish_reason`-safeguards (Nudge-Kette mit Diagnose, live 16/16 im Benchmark; Silent-Guard #62, Retry §6 O5b), Readline (`set -o emacs` + History 500 + Default-Bindings), `todo_write` = `tool_todo` (`~/.lex/plans/plan.md`, add/done/list + `/plan`) — **erledigt**; **Zero-Fork-Hot-Path bewusst gestrichen** (gemessen 2026-10-07: Start 0,103 s, Turn-Dauer zu 99 % vom Modell, 70–120 s — Fork-Ersparnis unsichtbar); **offen: Plugin-Struktur** (Tools/Hooks als eigene Exekutables — MCP-Tool ist der Auslauf, §9/5) |
| 2 | 24+ Tools, ~~Sub-Agenten (explore/plan/review/summarize)~~ **✅ Runde 2026-10-08 (2/6)**, Read-Only-Modus, ~~Parallel-Tool-Calls~~ **✅ Runde 2026-10-08 (3/6)**, ~~Skills~~ **✅ Runde 2026-10-08 (5/6)** |
| 3 | ~~Context-Compaction~~ (**✅ Schritt 42**), 3-Typ-Memory (semantic/episodic/procedural + Gate + Pass), Task-System, ~~Hooks~~ **✅ Runde 2026-10-08 (1/6)** |
| 4 | HTTP-Daemon (9655), Headless `lex -p --output-format json`, MCP-Client, ~~Background-Tasks~~ **✅ Runde 2026-10-08 (6/6, `task`)**, `stop.md` |
| 5 | Session-Commands (`/resume /rewind` ~~`/compact`~~ **(✅ Schritt 42)** `/fork`), Sandbox (Landlock), Eval-Modus, Trace/Undo |
| 6 | HN-Show-Post, brew/pkg, Community, v1.0.0 |

**Referenz-Mechanismen** (learn-claude-code s01–s17): Loop bleibt konstant, alles andere ist darauf gesetzt.

---

## 11. Datei-Mappe

### Dieses Verzeichnis `~/Ai/lex/`
| Pfad | Inhalt |
|---|---|
| `LEX.md` | **diese Datei — einzige Wahrheit** |
| `lex/lex` | das Skript (6048 Zeilen, 19 Tools) |
| `README.md` / `CLAUDE.md` / `CHANGELOG.md` / `LICENSE` | Doku + MIT-Lizenz (2026-09-28) |
| `.github/workflows/ci.yml` | CI: `bash -n` + shellcheck + `run_all.sh` + Hygiene |
| `.git/` | Vollständige Commit-Historie der lokalen Entwicklung (Schritte 1–104, v0.1.0–v0.5.1). **Wird nicht mitgeliefert** — diese Auslieferung hat eine eigene, frische Historie. |
| `tools/llama-proxy.sh` | **Debug-Proxy** (`start\|stop\|status\|tail\|show`), Logs in `.proxy/` |
| `test/run_all.sh` | Test-Läufer (**19 Läufer**: testboden/syntax/input/tools/selfedit/loop/http/features/mem_pref/soul/proxy/sse/**golden/load/fuzz**/eval/limits/compaction/repetition, grün) |
| `test/test_*.sh` | 17 Testdateien, **1209 [PASS] = 1190 Einzelf** (1190 + 19 Läufer-Marken), live gezählt 2026-10-28 §7/124 |
| `test/fake_mcp.sh` | minimaler MCP-Server (stdio/JSON-RPC) für Schritt 9 + 22 + 23 + 24 + 25 |
| `test/fake_server.sh` | Fake-Server (ncat, hoher Port) für den curl-Pfad + SSE-Endung `.sse` + `STATUS:`-Kopfzeile |
| `archiv/` | die 7 abgelösten MD-Dateien (Referenz, nicht pflegen) |

### `archiv/` (nur nachschlagen)
`Project-Lex.md` (alter Master-Plan), `IDENTITAET.md` (Motivation), `ARCHITEKTUR.md` (Optionsbewertungen + §6 Spec), `UBERSICHT.md` (altes Handover), `TIEFE-RECHERCHE.md` (20+ Projekte, headlong/llama.cpp/grok-build/Ökosystem — **§14, §15, §16, §19 sind wertvoll**), `WETTBEWERB-TABELLE.md` (11 Projekte), `PHASE-0-STATUS.md` (altes Status-Handover).

### Wissens-Basis `~/Ai/wiki/` (Obsidian-Vault) — Stand 2026-09-28 repariert
```
~/Ai/wiki/              ← Vault-Root (.obsidian/, conventions.md = Pfad- und Log-Regeln)
├── raw/                ← unveränderliche Quellen (8 Dateien, NUR LESEN)
└── wiki/               ← kompilierte Artikel (Skill `karpathy-llm-wiki`)
    ├── index.md        ✅ sauber (2 tote bashagt-Zeilen entfernt)
    ├── log.md          Append-only Ops-Log (34 KB) — hier wird protokolliert
    ├── analyses/lex-architektur.md     (Stand 2026-09-25, historisch)
    ├── concepts/pure-bash-agent-loop.md ✅ toter Link repariert
    ├── errors/         Fehler-Learning (Schema: conventions.md §Error-Learning)
    ├── entities/       leer — laut conventions.md legitimer Ordner
    └── sources/        leer — laut conventions.md legitimer Ordner
```
- **Link-Status**: `wiki/` = 0 defekt. `raw/` = 7 tote Links → **bewusst unangetastet** (raw ist immutable, `conventions.md`).
- **Pfad-Regel**: Projekt-Root ist `~/Ai/wiki/`, also `raw/…` + `wiki/…`. Relativ von `wiki/<topic>/` aus: `../../raw/…`.
- **`AGENTS.md`** (`~/Ai/AGENTS.md`) ist korrekt (`~/Ai/wiki/`, Log `~/Ai/wiki/wiki/log.md`).
- **`~/wiki/`** (falsch angelegter Ableger) existiert nicht mehr.
- **Bashagt** = nur noch Raw-Information, kein Wiki-Artikel und kein Linkziel mehr.

---

## 12. Regeln (immer gelten)

Die Bauweise steht in **§0.1** — dort ist sie verbindlich. Nur die Ergänzungen, die nicht dort stehen:

1. **Wiki = Gedankstütze, `LEX.md` = Projektdokument.** `archiv/` ist nur zum Nachschlagen.
2. **Keine Halluzinationen** — nur was belegt ist (`datei:zeile` oder ausgeführter Befehl).
3. **Fehler werden dokumentiert, nicht versteckt** → `~/Ai/wiki/wiki/errors/` (Schema siehe `~/Ai/wiki/conventions.md`).
4. **Bashagt ist nur noch Information** (Raw-Quellen in `~/Ai/wiki/raw/`), kein Vorbild und kein Linkziel mehr.
5. **Zeilennummern-Zitate (`lex:NNNN`) sind Stand des letzten Code-Commits.** Wer `lex` ändert, zieht die Zitate der betroffenen Region mit (`grep -n` gegen den neuen Stand; Nachweis-Scan 2026-10-13: alle 95 Zitate geprüft, 94+2 nachgezogen). Zitate ohne `lex:`-Präfix (z. B. `(1613)` hinter `` `_su_is_command()` ``) zählen mit. Bei Massenersetzungen **rückwärts** pro Fundstelle setzen oder atomar pro Datei — vorwärts iterierende Offsets zerstören die Folgestellen (Fehlerseite `wiki/errors/2026-10-13-massenersatz-offset.md`). **Zweiter Lauf = erst Snapshot** (2026-10-27): `map()` rechnet von HEAD aus und ist nur idempotent, solange die Eingabe HEAD-Werte sind — ein zweiter Shift-Lauf ohne Zwischenspeicherung zieht bereits verschobene Zitate ein zweites Mal über (§7/123-Fund: `928` statt `924`, `2949` statt `2920`, Mappe `887` statt `883`). Vor jedem erneuten Lauf Kopie des Dokuments anlegen — oder besser gegen HEAD rekonstruieren statt verschieben (Skript `/tmp/opencode/zitat-rebuild-123.py`, Fehlerseite `wiki/errors/2026-10-27-zitat-doppel-shift-und-mappe-rebuild-regression.md`). Zitat-Prüfung am Ende **semantisch**: benachbarte `name()`-Definition gegen `grep -n`/Span testen, nicht nur „Zahl existiert" — §7/123-Scan fand so 29 schon bei HEAD veraltete Zitate (28+1 korrigiert, 0 Rest).
6. **Spiegel-Regel GitHub**: `~/Ai/lex` ist das **lokale Original** — nicht kürzen, nicht löschen, bleibt vollständig (`LEX.md`/`CLAUDE.md` liegen nur dort). Der **Spiegel, der allein auf GitHub geht**, ist ein eigenständiges, bereinigtes Auslieferungs-Repo: **null private Infos** online; Aufräumen (Alt-Blobs, Alt-Branches, Alt-Tags) passiert **nur** im Spiegel. Verifikation nach jedem Push: 14-Muster-Privat-Scan **und** Sonde `https://github.com/<owner>/<repo>/archive/<altsha>.tar.gz` → muss **404** liefern (nur `refs` zu ersetzen reicht nicht, GitHub lagert unrefrenzierte Blobs weiter).

---

## 13. Restore-Hinweis (Rückgängig-Machen)

Falls die Archivierung falsch war:
```bash
mv ~/Ai/lex/archiv/*.md ~/Ai/lex/
rm ~/Ai/lex/LEX.md
```
