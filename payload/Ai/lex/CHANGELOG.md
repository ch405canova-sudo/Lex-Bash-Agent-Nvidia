# Changelog

Alle bemerkenswerten Änderungen an lex.
Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung: [Semantic Versioning](https://semver.org/lang/de/).

### Geändert 2026-10-28 — §8 F abgeschlossen: golden files, Last- und Fuzz-Tests (§7/124)

- **Golden files statt Inline-JSON**: neue `test/fixtures/` (12 `*.jsonl`, `golden.tsv`, `sse/` mit
  `.golden.json`/`.golden.err`, `md/` mit `.golden.out`) + `test/test_golden.sh` (**38 PASS**),
  Update-Modus `LEX_GOLDEN_UPDATE=1`. Fixtures werden per `cp` in `$TMP` kopiert, nie direkt als
  `_mock_file` gesetzt (sonst frisst `call_api` die Quelle). `test_loop.sh`/`test_input.sh`/
  `test_compaction.sh` auf Fixture-`cp` umgestellt.
- **Lasttests** `test/test_load.sh` (**33 PASS**, 6 Fälle: sse5000, tools300, ctx4001 inkl. auto-Compaction,
  answer2mb, queue500, tools20). Budgets `max(4 × Referenz, 5000 ms)` aus REF-Tabelle; Nachmessung ohne
  Rot über `LEX_LOAD_MEASURE=1`; Watchdog 180 s je Lauf.
- **Fuzzing** `test/test_fuzz.sh` (**93 deterministische Fälle**, `RANDOM=42`): A Parser 40,
  B call_api-Queue 18, C dispatch_tool 35. Fuzz-Imports verboten — kein `bash`/`mcp`/`web_*`/`browser`/
  `agent`/`task` (führen aus). Invarianten: kein Hang, rc im erlaubten Bereich, bei rc 0 gültiges JSON.
- **VERIFY**: Voll-`run_all.sh` → **19 Läufer, 1209 [PASS] = 1190 Einzelf, 0 FAIL, rc 0** (Vorstand
  16/16 = 1127/1111); `bash -n` + `shellcheck -S warning` sauber; `wc -l lex` = **6353** (unverändert — nur Tests/Doku).
- **Geklärte Messbefunde (keine lex-Defekte)**: jq 1.8 `error()` → rc 5; `_sse_to_response` liefert
  pretty-printed JSON (Feldzugriff per jq, nicht String-Match); `head -c 1` frisst an Pipes ein Byte
  (Parser-Input als Datei); L3-Kontext lag über der Schwelle (auto-Compaction auf 497 Einträge);
  20 Tool-Calls = 1 assistant-Message + 20 tool-Results = 24 Kontext-Einträge.
- **Doku-Nachzügler**: §8 F aus §7-„nächster Schritt" raus, §8-F-Status ✅, §9/3 (CI) + §9/4 (Release-Timing)
  als veraltet markiert, §0.1-Statuszeile + §11-Mappe auf 19 Läufer/17 Testdateien gezogen.
- **Lektion**: Helfer-Semantik auseinanderhalten (`assert` erwartet/ist vs. `check` 1=Bedingung erfüllt) —
  erste `test_load.sh`-Fassung erzeugte 19 Falsch-FAILs; Lasttexte müssen `_rep_detect` unauffällig sein.

### Geändert 2026-10-27 — Zwei stille Kappungen sichtbar: Summary-Warnung im Kontext, History-Cap 5000 (§7/123)

- **F4 `_compact_run`** (lex:4681): abgeschnittene Compaction-Summary (`finish_reason=length`) trägt jetzt
  einen Warnhinweis **im Kontext** („⚠️ ZUSAMMENFASSUNG UNVOLLSTÄNDIG: … finish_reason=length …")
  statt nur einer Log-Zeile — ohne Marker galt die Folge-Session eine unvollständige Summary für vollständig.
  Gegenprobe `finish=stop` bleibt ohne Hinweis (Nadel + Live-Messung `summary_chars` 252 vs. 64).
- **F5 `_hist_init`** (lex:2223): History-Cap `tail -n 500` → **5000** (506 Einträge → vorher still 6 weg)
  + Pflicht-Log-Zeile „history: N Einträge > Cap 5000 — älteste gekappt". Kein Marker in der Datei
  (würde als Verlaufskommando im Prompt auftauchen); `usage` nennt 5000 (lex:6215).
- **Tests +9** (`test_compaction.sh` +6, `test_features.sh` +3): summary-length-Block inkl. stop-Gegenprobe,
  History 600 bleibt / 6000→5000 / Kappungs-Log.
- **VERIFY**: `bash -n` + `shellcheck -S warning` + `selfcheck` rc 0; `run_all.sh` **16/16 = 1127 [PASS],
  0 FAIL** (Vorstand 1118), Einzelf 1111; `wc -l lex` = **6353**. Live-Gegenprüfung (isoliertes `LEX_HOME`,
  nur `LEX_MOCK_FILE`): L1 length → `summary_chars:252` + Log · L2 stop → `64`, kein Log · L3 6001→5000
  (Kopf 1002) + Log, echte `~/.lex/history` unangetastet.
- **Zitat-Reparatur nach Doppel-Shift**: Der zweite Shift-Lauf ohne Snapshot zog bereits verschobene
  Zitate ein zweites Mal über (`928` statt `924`, `2949` statt `2920`). HEAD-Wiederaufbau für
  LEX.md/CHANGELOG/test_selfedit, §5-Mappe 55 Zellzeilen neu (109 Zellen gegen Code geprüft),
  semantisches Audit korrigierte 29 schon bei HEAD veraltete Zitate. §12 #5: Snapshot-Pflicht vor
  Zweit-Läufen. Fehlerseite `wiki/errors/2026-10-27-zitat-doppel-shift-und-mappe-rebuild-regression.md`.
- **Kein Commit** (Regel 7 — Freigabe wartet auf den User, umfasst §7/122 + §7/123).

### Geändert 2026-10-27 — Kürzungs-Fixpaket: head/tail-Pipe-Deny, sichtbare Kürzungs-Marker, Reasoning-Cap 40000 (§7/122)

- **Kontext**: User-Vorgabe „es darf nichts abgeschnitten werden" — die Verbote bestanden (Prompt, §6 #54, §7/38) und waren codeseitig nie erzwungen (5. Kürzungs-Fund → §6 #58, Klasse). Session-Messung 2026-10-27: **1240/2145** bash-Calls pipeten nach head/tail; die Windows-Fehlersession verlor über `cat …| head -40` den `.21`-Eintrag mitten im fertigen Report.
- **F2 `_bash_denied`** (lex:1677): Pipe-zu-head/tail wird hart abgelehnt (Regex über `tr`-normalisierten String mit `${c,,}` — deckt auch `| HEAD`), Meldung nennt die Alternative (`wc -l`). **Erlaubt bleiben** grep/sort/wc/jq-Pipes (Filter, keine Kürzung) und Standalone-Log-Fenster `tail -n N log`.
- **F1 `tool_web_fetch`** (lex:2920): sichtbarer Knapp-Marker „[gekürzt: N von max M …]" sobald die Ausgabe `max_length` erreicht — vorher kürzte der Crawler still (13/13 ohne Marker).
- **F3 `_wiki_ex`** (lex:924): Fenster-Marker „letzte 40 von N Zeilen — vollständig unter <pfad>" statt still.
- **A4**: `LEX_REASONING_STORE_MAX` 20000 → **40000** (41 Kappungen, Originallängen median 31 238 / max 33 971 — deckt 41/41, alter Default 15/41).
- Prompt-Bullets (lex:647/661), `/help` (lex:6183), bash-Schema (lex:1153) auf die Kürzungs-Pipes korrigiert — die Prompt-Fassung behauptete eine Pipe-Deny, die es im Code nicht gab.
- **VERIFY**: `bash -n` + `shellcheck -S warning` + `selfcheck` rc 0; `run_all.sh` **16/16 = 1118 [PASS], 0 FAIL** (+13 Nadeln in `test_features.sh`, Einzelf 1089 → 1102). Negative Probe: Kopie mit allen vier Defekten → alle vier Nadeln-Gruppen fallen. **Zitat-Shift** nach §12 #5: 92 Einzel + 3 Ranges in LEX.md, 9 + 1 in `CHANGELOG.md`/`test_selfedit.sh`, 89 Mappe-Zeilen; erster Anlauf übersah bei Einfügungs-Hunk ein Delta → zurückgesetzt und korrekt gezogen (`wiki/errors/2026-10-27-zitat-shift-einfuegungs-hunk.md`).

### Geändert 2026-10-17 — Over-Shoot-Guard (Phase 3), ub/lm-Messung, lexpen-Live-Test (§7/112)

- `lex`: zweite `_compact_run`-Aufrufstelle als Over-Shoot-Guard direkt nach dem
  Tool-`done` (alle Tool-Paare geschlossen) — Tool-Turns überschreiten die
  Compaction-Schwelle sonst ungeprüft bis zum Server-Limit; zeilenneutral
  (6242), alle Zitate stabil; `run_all` 15/15 grün inkl. Nadel P7b.
- llama-bench `-r 1` pp32768: ub1024+auto **465,8** / +dio 465,2 / ub512 456,4 t/s
  (tg128 ~45,5) → `-lm dio` ≈ Rauschen, `-ub 512` −2 % → Produktions-Defaults
  bleiben, keine ai.sh-Änderung (`archiv/ub-lm-ab-20261017.txt`).
- `/lexpen`-Live-Test mit sudo + echter passiver Recon (Ziel-Name entfernt,
  Cloudflare-Infrastruktur AS13335, TLSv1.3): Ticket beim `/lexpen on`,
  auto-grant ohne Rückfrage, 0 Mutationen → offene Beobachtung §7/106 geschlossen.
- Server auf Normalbetrieb (lv 3, PID 236537); Belege `archiv/ub-lm-ab-20261017.txt`
  und `~/.lex/log/lex.log`.

### Geändert 2026-10-17 — Hebel-Recherche, Live-Fire-Beweis, C1/C2 dauerhaft (§7/111)
- `~/.lex/settings.json`: `ctx_limit: 120000` + `tool_max_output: 20000` gesetzt
  (Bestand unverändert, Backup `settings.json.bak-20261017`) — Compaction-Schwelle
  100 000, 85 %-Warnung 102 000, Tool-Kappung 20 000 ab dem nächsten Start dauerhaft
  aktiv (verifiziert via `lex --status`).
- Live-Fire bewiesen (7-Zeilen-`script`-Sitzung, 17:05–17:24): Warnung `pct=91
  est=109359 thr=100000`, **Auto-Fire `force=auto`: `~109359 → ~20244 Token`**,
  Kosten 68 s, Turn 5 setzte nach dem Schnitt sauber fort.
- Kalibrierung: Die Schwelle prüft nur die Messages-Schätzung; System (~34,4k) +
  Tool-Schemas (~5,6k) fehlen → realer Peak `prompt_eval 139403 = 116 %` bei
  est 109 359; TTFT-Deckel mit ctx 120000 real **~70 s** (Zyklus 58k↔139k), nicht ~55 s.
- Hebel-Recherche (punktuell): PR ggml-org#26856 (`merged:false` 16.08.2026),
  rocWMMA-Option entfallen (FA+q4_0-Fused-Kernel aber aktiv), Modell-Swap-A/B tot
  (Bonsai 625,8 pp512 / 44,9 t/s ggü. Qwen IQ3 567,6 / 24,3) — serverseitig nichts
  mehr; Backlog: Phase-3-Over-Shoot-Guard, `-ub 512`, `--load-mode direct`.
- `lex` unverändert (6242 Zeilen, kein Shift); Belege in `archiv/livefire-20261017-*`
  und `archiv/llama-bench-ab-20261017.txt`.

### Geändert 2026-10-14 — Amnesie-Test-Skript `tools/amnesie_test_setup.sh` (§7/107)

  - **User-Auftrag**: „baue 2. ein" (Empfehlung aus §7/106: Amnesie-Tests automatisieren statt manuell)
  - **Warum**: lex zieht Gedächtnis aus4 Quellen — `~/.lex/mem`, `~/.lex/sessions`, gemeinsames Wiki (`${_ai_dir}/wiki` inkl. opencode-`log.md`), KV-Cache des llama-servers; §7/106-Lauf2 zeigte die Kontamination über wiki/log.md
  - **Das Skript**: Keyword-Suche (default `honeypot|dnat`) in mem+Sessions → sichern+verschieben nach `/tmp/opencode/amnesie-<ts>/` (nie löschen); Kontroll-Grep; leeres Wiki + `LEX_WIKI_DIR`-Hinweis; optional `--restart` (Server-Neustart per /proc-cmdline, leert Cache); `--dry-run`, `--keyword`, `--help`
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` rc 0, `selfcheck` rc 0; Dry-Run `honeypot|dnat` → 0/0, Positiv-Dry-Run `sudo` →2 Notizen + Sessions gefunden (nichts verschoben); `lex` unverändert (6241, 1044 grün)
  - **Nutzung**: `tools/amnesie_test_setup.sh --restart` → `export LEX_WIKI_DIR=<Backup>/wiki` → `lex`

### Geändert 2026-10-14 — Widerlegungs-Regel für mem-Notizen (§7/108)

  - **User-Auftrag**: „baue die Widerlegungs-Regel ... und teste es live im Anschluss ob es funktioniert mit einem anderen Aufgaben-Szenario"
  - **Regel** (Inkrement `lex:641`, Nadel „Widerlegte Notizen bleiben stehen"): Repro beweist Notiz als falsch → `append_file`-Zeile «Widerlegt YYYY-MM-DD: …» an DIESE Notiz-Datei — nicht löschen, nicht mem_add-Zweitnotiz (Incident: prio-1-Notiz überlebte den Reboot); mem_search matcht Phrasen → bei Fehlschlag breiter suchen/grep
  - **Live-Test** (fail2ban-Szenario, gepflanzte Falschnotiz „bantime 7200" vs. Live 604800): Lauf1 fand die Notiz nur per grep, nicht gelöscht, aber mem_add-Umweg → Präzisierung; Lauf2 zitierte die Regel, bot nur an; Lauf3 führte aus (Widerlegungs-Zeile an der Original-Datei + Log + Live-Verifikation ohne sudo)
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` rc 0, `selfcheck` rc 0, `run_all` **1045 [PASS] = 1030 Einzelf**, 0 FAIL, 89 s; `lex` 6241 (kein Shift)

### Geändert 2026-10-14 — Gegenprüfung-Verlängerung: lexpen-Modus, Amnesie-Setup, Kontaminationsquelle (§7/106)

  - **User-Frage**: „aber /lexpen on ist weiterhin in der Architektur richtig?" — nach §7/105 (Default-Lauf) fehlte die Probe unter lexpen-Guard-Druck (die Urheber-Nacht lief in lexpen)
  - **Lauf2 (lexpen via script-PTY)**: `prompt_mode lexpen` verifiziert, Workflow diszipliniert (Live-Checks, ehrliche Klärung,0 Mutationen) — **aber kontaminiert** (zitierte Session130050 trotz Server-Neustart)
  - **Kontaminations-Quelle**: gemeinsames Wiki `${_ai_dir}/wiki` — der §7/105-Eintrag in `wiki/log.md` (13:15 geschrieben) enthielt ID, „0 Mutationen\", „6 Minuten\",2223-Lösung; Beweis in Lauf3: erster Zugriff `read_file wiki/log.md` → „Datei nicht gefunden\" (leeres `LEX_WIKI_DIR`). **§7/103 gilt auch für das opencode-wiki-Log**
  - **Lauf3 (vollständig amnestisch)**:0×130050, lexpen-Persona („✦ made by @Lex ✦\", englisches Reasoning), **eigener Repro** (Python-Socket-Bind-Test), **DNAT22→2222 selbst verworfen („destructive\" — deckt sich mit der User-Analyse)**, Systemdienste unangetastet,10 Live-Befehle,0 Mutationen,0 Notizen
  - **Fazit**: `/lexpen on` ist architektonisch richtig — der Guard überstimmt die §7/104-Checks nicht; Urheber-Kaskade in lexpen nicht mehr reproduzierbar (4-fach geprüft). Offene Punkte: sudo-Gate-Kommunikation unter lexpen ungetestet (LEX_SUDO=0), Freigabe-Frage im Guard-Grenzbereich (als kündbare Umsetzung bewertet)

### Geändert 2026-10-14 — Gegenprüfung: Honeypot-Wiederholung mit gelöschtem Gedächtnis (§7/105)

  - **User-Auftrag**: „lösche alle seine Erinnerungen bzgl. Honeypot-DNAT, gib ihm die selbe Aufgabe erneut ohne zu sagen was er machen soll, beobachte seinen Workflow" — Gegenprüfung, ob die §7/104-Optimierung greift
  - **Setup**: 1 mem-Notiz + 25 Honeypot/DNAT-Sessions entfernt (alle gesichert in einem temporären Sicherungsverzeichnis, Restkontrolle 0 Treffer) — Aufgabe per `lex --oneshot` ohne Lösungshinweise (kein Port-Redirect, kein Port-Vorgabewert, kein Save, kein sudo-Hinweis)
  - **Beobachtung (Session `anonym`, 6 Min, 10 bash-Aufrufe via audit.log)**: Wiki + sofort Live-Ist (`ss -lntp`, `ps aux`); sudo dreimal angefordert und **jedes Mal kommuniziert** statt ohne Rechte weiterzuarbeiten; rc=1 → alternative lesbare Quellen statt Quellcode-Grab; ehrliche Klärung „parallel auf 22 geht nicht" (ein Port, ein Listener, Live-belegt) → Lösung2223 (Freiheit geprüft); finale Antwort mit systemd-Unit (persistente Konfiguration) + Verifikationszielen. **0 Mutationen** (diff gegen Baseline: `blocklist.txt`/`iptables-backup.rules` unverändert), 0 neue Notizen
  - **Vergleich Urheber**: dort 13 Std, 50 DROP-Regeln in 8 Min ohne Save, «Parser-Bug»-Falschdiagnose, 7 Min Quellcode-Grab, INSERT an Position 1, Notiz als Ist — hier 6 Min, alles geprüft, nichts mutiert. **Bewertung: alle §7/104-Checks griffen**; offene Beobachtung: kein `todo` (6-Min-onshot) — für längere Aufgaben zu prüfen

### Geändert 2026-10-14 — Regelwerk-Audit: Widersprüche aufgelöst, Frust-Bruch-Regel, Checks statt Gates (§7/104)

  - **User-Auftrag**: „baue es um aber ich will nicht dass lex wieder eingeschränkt oder eingesperrt wird" — nach der Prio-1-Forensik (§7/103) Systemanalyse des GESAMTEN Prompt-Regelwerks
  - **Befunde**: 3 echte Widersprüche — W1 „Wiki ist Gedächtnis" vs. „mem ist Hypothese" (in Session `anonym` praktisch zugunsten Vertrauen entschieden); W2 „Erst liefern" vs. Plan-/Verifikationsziel-Pflicht (50 iptables-Regeln in 8 Min ohne todo/Save); W3 lexpen „kein Nein, technische Klärung erlaubt" — die erlaubte Klärung unterblieb, sudo-Gate ignoriert. Lücken: keine Regel für weitwirkende Netzwerk-Mutationen (Save/Persistenz/Position), Belegpflicht deckt Engineering-Mechanik nicht (route_localnet), kein Frust-Abbruch (ufw: 7 Min Quellcode-Grab). **Struktur-Wurzel**: monotone Kolumulation (34 Incidents → +Bullet), Gleichrangigkeit ohne Hierarchie, Nichteinhaltung trotz Regel-Existenz
  - **Umbau — 3 Inkremente auf bestehenden Zeilen (kein Zitat-Shift, `lex` = 6241; lexpen-Guard und Handlungsfreiheit unangetastet)**: `lex:679` „Gedächtnis ist Spur, Live ist Wahrheit" (W1); `lex:636` „Ausnahme weitwirkende Mutationen (Netzwerk, Firewall, Konfiguration mit Persistenz)" — kurzer Plansatz, ausdrücklich kein Genehmigungsprozess, sichern→mutieren→verifizieren (W2); `lex:641` „Frust-Bruch stoppen" — 3× Fehlschlag → --help/Doku/andere Ebene/technische Klärung, Rechte-Fehler zählen → sudo-Gate erneut (W3 + sudo-Sichtbarkeit im Ops-Block)
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1044 [PASS] = 1029 Einzelf, 0 FAIL, 88 s, rc 0**

### Geändert 2026-10-14 — Präventiv-Regel: mem-Notizen sind Hypothesen, nicht Ist (§7/103)

  - **Auslöser**: User-Auftrag „prüf das mal gegen ob Lex recht hat" — Gegenprüfung der Honeypot-DNAT-Statusanalyse aus Session `anonym`, forensisch nur lesend (Session-JSONL, mem-Notiz, Wiki, Prompt-Regeln)
  - **Befund**: die Session zitierte die mem-Notiz `prio-1-nach-neustart` (10:01, geschrieben von Session `anonym`) als ✅-Ist, obwohl `iptables -L` ohne sudo Exit-Code 1 lieferte (eigene Shell-Zeile wörtlich „(ohne sudo)") und ihr backup-Grep die echte `/24`-Struktur zeigte — Notiz-Wissen schlug Eigenevidenz (Anchoring). Notiz-Fehler: „25 IPs" (Blockliste ≠ Regeln: 3× `/24` + ~28× `/32`), `<ip>` fehlt in `blocklist.txt`, „DROP vor DNAT" technisch schief (nat-PREROUTING läuft vor filter-INPUT), `route_localnet=0` und fehlende ACCEPT für dport 2222. **Wiki-Injektion ausgeschlossen** (`search …/Ai/wiki` = „Keine Treffer"); verletzt war `lex:651` (sudo-Gate), `lex:638`/`671` formal erfüllt (Notiz = „Quelle") — es fehlte die Verifikationsregel
  - **Regel**: Prompt-Bullet `lex:641` Inhalts-Erweiterung (**kein** Zeilen-Shift): leeres Ergebnis ohne sudo-Rechte = „nicht prüfbar", nicht „✓ vorhanden", sudo-Gate erneut anwenden; `~/.lex/mem`-Notizen sind Hypothesen früherer Sessions — jede Status-/✓-Aussage erst gegen den Live-Zustand nachweisen (Repro); Nadel `contains "prompt (mem-Notiz ist Hypothese, nicht Ist)"` → **1041. Prüfung**
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1041 [PASS] = 1026 Einzelf, 0 FAIL, 89 s, rc 0** — `lex` = 6241 Zeilen (unverändert)

### Behoben 2026-10-14 — Incident: lex schaltete Autologin ein → Chrome fragte das Keyring-Passwort (§7/102)

  - **User-Report** „warum fragt Chrome beim Öffnen nach einem Passwort?" — Forensik (nur lesend) fand: `/etc/gdm3/custom.conf` geschrieben am **13.10. 09:43** von **lex selbst** (Journal: `sudo … COMMAND=/usr/bin/bash /tmp/opencode/gdm-autologin.sh`, PWD=`~/Ai/lex`, danach GDM-Restart) in Session `anonym`; Sicherung `custom.conf.bak-20261013` (Original vom 22.06.) lag noch da.
  - **Wirkung**: Autologin → PAM bekommt kein Passwort → `login.keyring` (angelegt 11.10.) bleibt versiegelte Collection (`…/secrets/collections/login` existiert nicht) → Chrome (Auslöser: **155**-Update heute 06:38 via unattended-upgrades) braucht beim Start Cookies/Passwörter → Keyring-Passwort-Abfrage bei **jedem** Start.
  - **Reparatur**: Backup per User-Terminal zurückgespielt (`sudo cp -a …custom.conf.bak-20261013 custom.conf`) + Reboot; Keyring-Inhalte erhalten. sudo-Passwort nötig, da der blanket-NOPASSWD-Sudoers `<datei>` seit 12.10. 22:49 entfernt war (Härtung bleibt).
  - **Regel**: §0.1 #7 + Prompt-Bullet (`lex:642`, Inhalts-Erweiterung — kein Zeilen-Shift): **Login- und Sitzungsverhalten ist unantastbar** (gdm3/custom.conf/Autologin, AccountsService, PAM, Greeter) — Autologin ist nie nötig und wird nie eingerichtet. Nadel `contains "prompt (Login-Verhalten unantastbar)"` → 1040. Prüfung. Fehlerseite `wiki/errors/2026-10-14-gdm-autologin-keyring.md`.
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1040 [PASS] = 1025 Einzelf, 0 FAIL, rc 0**. Kein Commit (Regel 7 — Freigabe ausstehend).

### Geändert 2026-10-13 — Zentral-venv `~/.lex/werkstatt/.venv`: Python-Werkstatt vereinheitlicht (§7/101)

  - **User-Auftrag** „alle Python-Tools und Abhängigkeiten IMMER im zentralen venv, lex hardcoded darüber": EIN venv (Python 3.14.7, 646 MB) statt drei Einzel-venvs (`python-envs/user-scanner` 104 MB, `python-envs/osint` [sherlock/holehe], `theHarvester/.venv` 276 MB) + System-`python3`-Aufrufen; Altvencs nach bestandenen Tests entfernt (~380 MB frei).
  - **Drin & getestet** (absolute Pfade, End-zu-Ende `-h`/`--version`/Usage): user-scanner 1.5.2.2, theHarvester 5.0.0, sherlock-project 0.16.2, holehe 1.61, Spiderfoot-Stack (CherryPy 18.10, lxml 6.1.3, cryptography 50, netaddr 1.3.0, requests 2.34 …); `osint_db.py` ohne Treiber (Stdlib + `psql`-Subprocess).
  - **Entscheidungen**: Spiderfoot-Pins `lxml`/`cryptography`/`pyOpenSSL` gelockert (keine 3.14-Wheels in den alten Versionen — `lxml<5` scheiterte am fehlenden libxml2-Quellbau); `netaddr` einheitlich 1.3.0 (theHarvester-Pin durchgesetzt, spiderfoot-kompatibel: nur `IPNetwork`/`IPSet` genutzt); `pygexf` (Py2-Relikt, impliziter Relative-Import) und `sherlock` 0.4.1 (fremdes Alt-Paket ohne Funktion) entfernt.
  - **lex-Hardcoding**: Werkstatt-Verfahren-Bullet (`lex:683`, reine Inhalts-Erweiterung — **kein** Zeilen-Shift, dadurch kein Zitat-Nachzug nötig): Aufrufe nur `~/.lex/werkstatt/.venv/bin/python …` bzw. `~/.lex/werkstatt/.venv/bin/<tool>` mit **absoluten** Pfaden (Relativwege erzeugen `sys.prefix`-Warnungen), `pip install` ausschließlich in diese venv, nie System-`python3`, nie pro-Tool-venvs. Nadel `contains "prompt (Zentral-venv Werkstatt)"` → 1039. Prüfung.
  - **Nebenbei**: `osint-pipeline.sh`-Defaults (`THEHARV`/`SHERLOCK`/`HOLEHE`) auf `$HTOOLS/.venv/bin/…` (`bash -n` ok); `WERKSTATT.md`: Venv-Regel-Sektion, Aufruf-Spalten auf absolute venv-Pfade, Struktur-Abschnitt ohne `python-envs/`, Stand 2026-10-13.
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1039 [PASS] = 1024 Einzelf, 0 FAIL, rc 0**. Kein Commit (Regel 7 — Freigabe ausstehend).

### Geändert 2026-10-13 — neue Ops-Bullet „Fehlertexte sind Zitate, keine Diagnosen" (§7/100) + Zitat-Shift +1

  - **Herkunft** Session-Audit-Wellen 2+3 (`anonym`, Analyse im Chat geliefert): lex produzierte den gemeldeten „handshake version conflict" selbst (17 printf-Repros sandten ein zweites `initialize` statt `notifications/initialized` — rmcp echoet im „expect initialized" immer das gespeicherte initialize) und wertete ihn trotz funktionierendem MCP-Flow der laufenden Session als Server-Bug → 4-h-Schleife bis zur User-Übernahme.
  - **Ops-Bullet in `_prompt_ops`** (`lex:644`): Fehlertexte beschreiben Empfang/Abweisung, nicht die Ursache — vor jeder Server-/Tool-Fehler-Diagnose die Negativkontrolle (funktioniert der laufende Flow, kann es nicht am Server liegen); Repros zeilenweise mit Antwort-Wartung, nie mehrere Nachrichten auf einmal. Harte Nadel in `test_features.sh` (enthält-Prüfung gegen `$_system_prompt`).
  - **Zitat-Shift nach §12 #5**: Bullet = einzige Code-Änderung (`lex` 6240 → **6241**), alles ab alter 641 um +1 — 58 Zitat-Zeilen in `LEX.md`/`CHANGELOG.md`/`test_selfedit.sh` maschinell, §5-Tabelle re-gepullt (45 Rows), Klammer-Zitate hand-gezogen; Streuner `(2471/2491)` (§6 Row 30, zeigte auf MCP-Cache) → `(4118/4129)` (Spinner-Löschkonstrukt). Historische Beispiele `lex:5266`/`lex:1027` in §7/99 blieben stehen.
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1038 [PASS] = 1023 Einzelf, 0 FAIL, 89 s, rc 0**. Kein Commit (Regel 7 — Freigabe ausstehend).

### Geändert 2026-10-13 — alle 95 `lex:NNNN`-Zitate auf den aktuellen Code gezogen (§7/99 Nachtrag)

  - **Auftrag** „alles korrigieren" (User-Entscheidung): Bestandsaufnahme aller Zeilennummern-Zitate in `LEX.md` (85), `CHANGELOG.md` (9) und `test/test_selfedit.sh` (1) gegen den Stand `cdeea43` — mit Nachbar-Key-Heuristik, Stufen-Bewertung (def/assign/call/hit) und manueller Verifikation jeder nicht eindeutigen Fundstelle.
  - **94 Stellen nachgezogen** (inkl. Slash-Listen `30/42/59`→`44/63/161`, Bereichen `376-383`→`5087–5091`, Klammern-Zitaten `_su_is_command()` (558)→(1612), Prompt-Bereichen (327–352)/(354–402)→(605–633)/(634–690)) + 2 Bereichs-/Prompt-Zeilen; **9 bewusst unverändert** (7 bereits korrekt, 2 historische Beispiele in §7/99a). Danach: **95/95 im Re-Scan bewertet, 81 direkt als „Schlüssel steht in der zitierten Zeile" bestätigt**.
  - **Regel §12 #5 neu**: Zeilennummern-Zitate gelten als Stand des letzten Code-Commits und werden beim Code-Change mitgezogen; Massenersetzer rückwärts anwenden (Incident: vorwärts laufende Offsets → `lex:17715`, sofort aus Sicherungskopien zurückgesetzt; Fehlerseite `wiki/errors/2026-10-13-massenersatz-offset.md`).
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1037 [PASS] = 1022 Einzelf, 0 FAIL, 88 s, rc 0**. Kein Commit (Regel 7 — Freigabe ausstehend).

### Behoben 2026-10-13 — MCP-Env-Erbe (`export -a`), zerfallener `_mcp_config()`-Fallback, tote Nadeln (§7/99)

  - **Session-Audit** `anonym`: das gemeldete „handshake version conflict" **existiert nicht** — rmcp verlangt als 2. Nachricht `notifications/initialized`, die Repros sandten ein zweites `initialize`/`tools/list`; Gegenbeweise: nur `initialize` → rc 0 (`protocolVersion 2024-11-05`), voller lex-Flow → 64 KB/ids 1+2/rc 0, lex' Coproc 1:1 → 18 Tools/leerer stderr. Die „connection closed"-Belege stammen aus `mcp desktop __tools` ohne stdin (Test-Artefakt).
  - **Behoben `export -a` im Coproc** (§6 #52): `export -a K=V` legte eine Array-Variable statt eines Umgebungswerts an — die Kind-Shell bekam `COMPUTER_USE_LINUX_ENABLE_SHELL` nie. Beweis: `bash -c 'export -a FOO=bar; exec env' | grep -c '^FOO='` → 0 (ohne `-a` → 1); E2E: mit `-a` fehlte `run_shell` im `tools/list`, ohne `-a` war es da. Fix: `export "${_env_vars[@]}"` (lex:2791).
  - **Behoben `_mcp_config()`-Fallback** (§6 #53): jq-Programm ohne `env`-Slot und mit nicht definerter `($HOME)`-Variable → duplizierte Server-Keys (18 statt 5) + fehlendes Komma → der Fallback konnte gar keinen gültigen `mcp.json` schreiben. Fix: `\($h)`, ein `env`-Slot je Server, 5 Server (lex:2477–2502).
  - **+10 harte Nadeln** in `test_features.sh` (Einzelf 1012 → 1022): `_mcp_env_vars` funktional, `env`-Funktion, Coproc ohne `-a`, „kein `export -a` im lex-Code", **E2E durch den Coproc** (Probe-Server schreibt die Env-Var nach `$TMP/env_probe.txt`), mcp.json-`env`-Block, 2× Default-Config. Negative Probe (Kopie mit wieder eingebautem `export -a`) → **3× [FAIL]**.
  - **VERIFY**: `bash -n` ok, `shellcheck -S warning` 0, `selfcheck` rc 0, `run_all.sh` **15/15 = 1037 [PASS] = 1022 Einzelf, 0 FAIL, 89 s, rc 0**, `wc -l lex` = 6240; §5 Zeilen-Mappe neu gezogen (44 Zeilen). Offen: ~40 historische `lex:NNNN`-Zitate treffen den Code nicht mehr. Kein Commit (Regel 7).

### Geändert 2026-10-13 — „Entfessele dich": run_shell-Freigabe + Compositor-Verbot (§7/98)

  - **Punkt 1 (tesseract) erledigt** — `tesseract 5.5.0` installiert (sudo apt-get), `--list-langs` OK.
  - **Punkt 2 gescheitert** — `pkill gnome-shell` tötete den Wayland-Compositor, Desktop + REPL tot. **Neue harte Regel §0.1 #7**: Compositor & Systemdienste (gnome-shell, mutter, gdm, display-manager, getty) **niemals** per kill/pkill/restart/reload/stop/start berühren — auch nicht als „Reload"; `backend: unavailable` ist kein Fehler. Fehlerseite `wiki/errors/2026-10-13-compositor-kill.md` + index-Zeile.
  - **Punkt 3 (run_shell-Freigabe)** — `computer-use-linux` registriert `run_shell` nur mit Env `COMPUTER_USE_LINUX_ENABLE_SHELL=1` beim Server-Start (README §Server runtime). **Fix**: (a) `mcp.json` `desktop.env.COMPUTER_USE_LINUX_ENABLE_SHELL=1`; (b) `lex` `_mcp_env_vars()` (lex:2512) + `coproc MCPSRV { env "${_env_vars[@]}" exec ... }` (lex:2791); (c) mcp-Tool-Beschreibung um env/run_shell-Hinweis erweitert; (d) Test-Nadel in `test/test_features.sh`. **VERIFY**: `bash -n` + `shellcheck -S warning` + `selfcheck` rc 0; `run_all.sh` **15/15** grün; env-Pfad mit Fake-Server nachgewiesen (Var erreicht den Prozess). `run_shell` wird nach neuem `lex`-Start im Cache sichtbar (laufende Session lädt alten Code).

## [Unreleased]

### Geändert 2026-10-12 — Zwei Ops-Regeln: „Vorhandenes vor Neubau" + „Erst liefern, dann verfeinern" (§7/96)

- **Vorhandenes vor Neubau** (eingehängt nach „Fehler sind Material"): vor
  jedem Bauen, Klonen, Installieren oder Herunterladen den vorhandenen
  Bestand checken — Wiki-`search`, `wiki/index.md`, `WERKSTATT.md` /
  `pentest-tools-katalog.md`, laufender Plan, bereits geklontes Repo. Kein
  Quellbau, wo ein fertiges Image, Repo oder Wrapper existiert. Auslöser:
  lex' eigene Meta-Analyse der Audit-Läufe 1–3 (2× Zeek-Quellbau statt
  `zeek/zeek:latest`, doppelte Todo-Zeile) samt Gegenbeweis aus Lauf 3
  (Zustandscheck → `git pull --ff-only` statt Neubau).
- **Erst liefern, dann verfeinern** (eingehängt nach „Denken hat ein
  Ende"): Kern-Deliverable (Skill, Playbook, Patch, Antwort) zuerst, Reste
  als offene Punkte benennen statt im Schweif zu verfeinern; bei Token-HUD
  >80 % oder Budget-Meldungen verdoppelt sich die Regel. Auslöser: Lauf-2-
  Limit-Schweife (53 min am Feld-Parser, Skill/finale Antwort fehlten).
- **Gilt in beiden Modi** (Default + `/lexpen` — `_prompt_ops` ist
  Bestandteil beider Prompts, bewiesen durch neue lexpen-Quelltextnadel).
- **Tests**: +3 Nadeln → 15/15 = 1027 [PASS] = 1012 Einzelf, 0 FAIL, 88 s.

### Geändert 2026-10-12 — sudo-Scope korrigiert: nur `/lexpen`, 1× beim Einschalten (§7/94)

- **`/etc/sudoers.d/<datei>` entfernt** (18:02): das `NOPASSWD:ALL` vom 17:03
  war global (galt auch für andere Prozesse und mit `/lexpen off`) — sudo
  fragt jetzt wieder Passwort (`sudo -n true` → rc 1 „interactive
  authentication is required" bestätigt, Verzeichnis nur noch `README`).
- **`cmd_lexpen on`**: holt nach der Aktivierung **einmal** `_sudo_ask`
  (Passwort direkt an sudo über die controlling TTY — Schritt-57-Regel, nie
  durch lex); ohne TTY oder abgebrochen bleibt lexpen aktiv und der Gate
  fragt beim ersten Root-Befehl ehrlich nach. `LEX_MOCK`-Guard, damit Tests
  nie an einer Passwortzeile hängen.
- **`cmd_lexpen off`**: wischt das Ticket mit `sudo -k` — bewusst **nach**
  dem Tor-Stop, weil `stealth-observe.sh --stop` selbst `sudo systemctl stop
  tor` braucht (Tor-Stop lebt vom Ticket des Modus).
- **Texte ohne NOPASSWD-Empfehlung**: Gate-Grund, Preflight-Meldung und
  Task-Description nennen die Foreground-Lösung zuerst; NOPASSWD erscheint
  nur noch als optionale, global wirkende Alternative (die Test-Nadeln auf
  das Wort bleiben absichtlich bedient).
- **Wiederholungslauf (Phase D)**: Original-Auftrag der 14:30-Runde in tmux
  wörtlich wiederholt — 53 min, 76 Tool-Calls, **0** identische
  Doppelungen, **0** Guard-/Fail-Records (erster Lauf: 42 min bis totem
  Ende, 7 Doppelungen, 2 loop_guard), Ziel-Hash `c4fd9343…` verifiziert,
  Wrapper-Skript in der Werkstatt gebaut; Skill/Playbook + finale Antwort blieben
  am gesetzten Limit offen. Ein Ctrl-C beendete den Turn sauber
  („REPL bleibt offen — Session gespeichert").
- **Tests**: +4 statische lexpen-Nadeln (Ticket-Einmalholen, Mock-Guard,
  `sudo -k`) → 15/15 = 1024 [PASS] = 1009 Einzelf, 0 FAIL, 87 s, rc 0.

### Geändert 2026-10-12 — Fix-Paket aus der Audit-Live-Beobachtung (§7/93)

- **sudo-Kontext-Split**: Hintergrund-Tasks prüfen sudo jetzt **im Zielkontext**
  (`_task_sudo_preflight`: `setsid -w sudo -n true` vor dem Gate) — frühe,
  ehrliche Ablehnung statt „A terminal is required to authenticate" erst nach
  ~20 min Build (sudo-Tickets sind pro TTY, Gate-TTY ≠ setsid-Kind).
- **`/lexpen` = Root ohne Rückfragen**: Auto-Grant in `_sudo_gate` — kein y/N,
  keine Sitzungsfrage; Passwort-Pfad nur als Fallback (wirksam ab NOPASSWD).
- **Loop-Guard Graceful-End**: der harte Abbruch endet nicht mehr mit blankem
  rc 1 — erzwungene Abschluss-Runde ohne Werkzeuge, Sicherheitsnetz rendert
  den Teiltext; dazu Fehler-Serie-Erkennung (≥6 bash-Fails rc≠0 in Folge →
  Anstoß „Methode wechseln").
- **Ehrliche Exit-Codes**: beide Kindketten laufen mit `bash -o pipefail -c`
  — `cmd | tail` meldet den rc der Kette, nicht den von `tail`.
- **Plan/VERIFY**: Verifikationsziel-Pflicht im Ops-Layer + weiche
  Plan-Erinnerung im `task start`-Ergebnis.
- **Tests**: +29 Checks → 15/15 = 1020 [PASS] = 1005 Einzelf, 0 FAIL, 88 s.

### Geändert 2026-10-12 — Präferenzen aus `mem/` werden injiziert (der Memory-Store war write-only)

- **Auslöser**: der User fragte in der lex-REPL, warum die von ihm gewünschte
  Persönlichkeit („du kannst gerne humorvoll und auch mal mit lustigen
  Emojis antworten") nicht in den Prompt kommt. Die Analyse durch lex selbst
  wurde von mir **unabhängig nachgeprüft** — alle vier Behauptungen hielten.
- **Befund (Klasse, nicht Einzelfall)**: der Memory-Store war **write-only**.
  `setup_messages` baute den System-Prompt nur aus `_system_prompt` +
  `_skills_ex` + `_wiki_ex`; `_mem_dir` erschien ausschließlich in der
  Definition, in den drei `mem`-Tools und in `cmd_status`, wo es die Einträge
  für `/status` **zählte** — und trotzdem nie las. Es lagen **6 Präferenzen**
  still, zwei davon **Sicherheitsregeln** (`sudo-regel--2026-10-03`,
  `pentest-tool-installation--immer-user-level`), dazu Arbeitsweiseregeln.
  Der Ton war nur der auffälligste von sechs toten Präferenzen.
- **Verworfen**: Ton in `_prompt_style` (hardcodiert eine änderbare Präferenz
  in die feste Identität), Skill-Datei (dupliziert den Zustand und lässt die
  anderen fünf Präferenzen tot), alle `mem/`-Typen injizieren (`fact`/`memory`/
  `note` sind Werkstattwissen und würden als Rauschen injiziert).
- **Vorbedingung vor jedem Lex-Code**: `20261009081714-lexpen-modus--humorvoll-antworten.md`
  begrenzte den Ton selbst auf `/lexpen` und schrieb für den Standard-Modus
  ausdrücklich einen trockenen, emoji-freien Ton vor — injiziert wäre es
  **schlimmer als heute** gewesen, der Widerspruch hätte den Ton aktiv
  unterdrückt. Satz entfernt (Tatsache bleibt als Verlauf), neue Leitpräferenz
  `ton--geltung--alle-modi`.
- **Gebaut**: `_mem_pref_ex` (lex:1051) nach dem Vorbild `_skills_ex` — Gate
  `LEX_MEM_PREF=off`, Budgets `LEX_MEM_PREF_MAX`/`LEX_MEM_PREF_TOTAL`
  (2000/6000) mit **sichtbarem** Kürzungsmarker (nie still abgeschnitten),
  ausschließlich `type: preference`, Reihenfolge `LC_ALL=C sort -r` (der
  Dateiname trägt `YYYYMMDDHHMMSS` → neueste zuerst, ohne das Frontmatter
  parsen zu müssen), leerer Store liefert **keinen** Block. Einhängung lex:1111
  **direkt hinter** `_system_prompt` — Präferenzen gehören zu „wer ich bin",
  Skills zu „wie ich arbeite"; die Reihenfolge ist eine Gewichtung.
  **Widerspruchsregel als Text im Block** („Bei Widersprüchen gilt der NEUESTE
  Eintrag") — ohne sie neutralisieren sich zwei gleich laufende Präferenzen,
  und genau das war der Zustand der Ton-Einträge vom 10-02 und 10-09.
- **Zwei eigene Fehler im Bauen, beide in derselben Klasse**: meine erste
  Supersedenz-Notiz **zitierte** das Verbot wörtlich (die Datei enthielt
  weiterhin die Verbotsformel), und die neue Leitpräferenz wiederholte
  denselben Fehler in Negationsform. Beides erst durch eine Endkontrolle über
  alle mem-Dateien gefunden — die Nadel prüft den injizierten Block, nicht die
  Einzelnotiz. Deshalb jetzt Regel in LEX.md §0.1 C: **eine Widerrufs-Notiz
  darf das Korrigierte nicht wörtlich wiederholen, wenn eine Datei injiziert
  wird**.
- **Dritter Anlauf, andere Kanalstellung** — deshalb die Regel breiter gefasst:
  der erste Entwurf des Log-Eintrags zitierte das Verbot erneut, und
  `wiki/log.md` läuft über `_wiki_ex` (**`tail -n 40`**) in den System-Prompt.
  Der Satz lag im injizierten Fenster und stand im Live-Prompt, während `mem/`
  bereits sauber war — der Fehler pflanzte sich in sein eigenes Gegenmittel
  fort. Vor jedem injizierbaren Dokument die Frage, ob sein Pfad überhaupt in
  den Prompt läuft; `wiki/errors/` tut das nicht, der Wiki-Log-Auszug sehr wohl.
- **Tests**: `test/test_mem_pref.sh` (**28 Nadeln**, 15. Läufer) inkl.
  Integration (`setup_messages` → System-Prompt über `jq`) — **8/8 Mutationen
  aufgedeckt**, jede Änderung vorher auf eindeutigen Anker geprüft.
- **Verify**: `bash -n` + `shellcheck -S warning` rc 0 · selfcheck ok ·
  `run_all.sh` **15/15 = 991 [PASS] = 976 Einzelf, 0 FAIL, 84 s** · E2E mit
  dem **echten** `~/.lex/mem`-Store: Ton-, sudo- und Pentest-Regel im
  System-Prompt, `nmap`-Facts und das entfernte Verbot dort **nicht**.
- **Nebenbefund**: der `/exit`-Fehler nach der Sandbox-Bau-Runde ist **kein
  lex-Defekt**. Mechanismus in zwei Varianten reproduziert — ein laufendes
  `bash` liest das Skript in Blöcken und setzt nach `/exit` an seinem
  gespeicherten Datei-Offset fort; ich hatte `lex` **in place** editiert,
  während eine REPL lief. In-Place-Rewrite bricht den Leser, Rename (`mv`)
  nicht — genau das leistet die Self-Edit-Sandbox mit ihrem atomaren `mv`.

### Geändert 2026-10-12 — Self-Edit-Sandbox statt Hook-Guard (Prüfen statt Verboten)

- **Auslöser**: die User-Frage, ob der Guard `~/.lex/hooks/pre_tool/50-guard-lex-selfedit`,
  der lex vor Selbstreparatur schützen soll, ersetzt werden könne — „bevor er
  die Änderung tatsächlich übernimmt, erst in einer Sandbox prüfen und dann
  einbauen".
- **Befund**: der Guard hatte die falsche Kategorie — er wollte eine Änderung
  *verhindern*, obwohl das Risiko ist, dass sie *angewendet wird, aber kaputt
  ist*. Der case-Zweig sperrte nur `write_file`/`edit_file`/`append_file`;
  das `bash`-Tool (`tee`, `sed -i`, python) lief mit `exit 0` ungeprüft
  durch, und die eigene Meldung erklärte die Umgehung („bewusst umgehen:
  Änderung via bash-tool"). Nachweislicher Schaden (§7/89): er schob den
  Agenten in den bash+Python-Read-Modify-Write-Umweg, der vor `f.write()`
  abbrach — der Guard war der **Auslöser, nicht die Ursache**.
- **Entscheidung (§2)**: echte Sandbox vorher + volle Suite vor Übernahme,
  Ort `dispatch_tool`. Zwei harte Gründe gegen die zuerst gewählte
  pre/post-Hook-Variante: (a) `LEX_HOOK_ARGS` wird nur als Env exportiert,
  `_run_hooks` liest nichts zurück → ein Hook **kann** die Pfade nicht
  umschreiben, nur erlauben oder blockieren; (b) Hooks hätten 5 s
  (`LEX_HOOK_TIMEOUT`) gegen ~87 s der Gates, und
  `_run_hooks post_tool … || true` schluckt jeden Fehlschlag still — die
  Verifikation wäre tot im Verborgenen gestorben, dieselbe
  Falsch-Grün-Klasse wie §7/89. `dispatch_tool` ist nicht via
  `LEX_HOOKS=off` umgehbar — hat aber selbst **kein** Timeout-Budget
  (`_default_tool_timeout` wirkt nur über `_run_limited` = `tool_bash`
  und Hooks; Review-B2 2026-10-12). Die Gates holen sich ihre Frist
  deshalb selbst über `_run_limited` mit `LEX_SELFEDIT_TIMEOUT`
  (300 s je Gate, Kill-Tree); hängt die Suite, wird sie abgebucht und
  zählt als Fehlschlag → fail-closed.
- **Geändert**: vier Helfer in `lex` (`_selfedit_ziel`, `_selfedit_anlegen`,
  `_selfedit_pruefen`, `_selfedit_uebernehmen`) + genau zwei Einhängestellen
  in `dispatch_tool` (vor dem `case`: Zielprüfung und `jq`-Umschreibung des
  `path` auf die Kopie; nach `_rc=$?`: Gates, dann fördern oder verwerfen,
  immer `rm -rf` der Sandbox). **2 statt 4 Gates** — `selfcheck_lex.sh`
  führt `bash -n` und `shellcheck -S warning` bereits intern aus, ein
  eigenes Gate wäre Dopplung (~4,9 s). Sicherung `${_lex_home}/lex.bak`
  vor dem atomaren `mv` (Rename im selben Verzeichnis; der laufende Prozess
  behält seinen alten Inode). Escapes `LEX_SELFEDIT_GATES=fast|off`
  melden **ausdrücklich**, dass die Suite nicht lief — nie ein stilles
  „grün“. **Bewusste Lücke** wie schon beim alten Guard: `bash`-,
  `task`- und `mcp__*`-Änderungen umgehen die Sandbox (Guardrail, kein
  Gefängnis).
- **Review (unabhängiger Sub-Agent, gleiche Tags)**: zwei Blocker, beide
  behoben. **B1 — Tilde-Pfad umging die Sandbox still**: `_selfedit_ziel`
  kanonisierte mit bloßem `readlink -f`, `safe_path` expandiert `~` aber
  selbst; belegt mit isoliertem `$HOME` war die Zielprüfung rc 1 (keine
  Gates, kein `lex.bak`) und `tool_write_file` schrieb danach **direkt auf
  das Original**. Fix: `safe_path` **vor** `readlink -f` — dieselbe
  Canonicalisierung, die auch der Schreibpfad benutzt. **B2 —
  „`dispatch_tool` hat 300 s" war falsch**: `_default_tool_timeout` wird
  nur über `_run_limited` wirksam, das rufen ausschließlich `tool_bash`
  und die Hooks auf; die Gates liefen also ohne jede Frist. Fix: eigene
  Frist je Gate über `_run_limited` (`LEX_SELFEDIT_TIMEOUT`, 300 s,
  Kill-Tree) **und** die Behauptung an allen vier Stellen ersetzt.
  Dazu behoben: bei `fast`/`off` wurde „Gates grün" behauptet (jetzt
  trennt `pruefen` die Prüfung und `uebernehmen` meldet erst nach dem `mv`
  den wahren Modus), und eine exportierte `LEX_SELFEDIT_GATES` hätte den
  Test-Runner falsch rot laufen lassen (unset am Anfang).
- **Entfernt**: `50-guard-lex-selfedit` aus `pre_tool/` — Rollback liegt als
  `~/.lex/hooks/50-guard-lex-selfedit.bak-20261012` (sha `9ea14a2a…`,
  außerhalb des Hook-Scanpfads). `post_tool/` unberührt (2 Hooks).
- **Behoben (Nebenbei, gleiche Fehlerklasse)**: `tools/selfcheck_lex.sh`
  meldete eine Log-Zeile `log "… $_sbx (Ziel …)"` als „aufgerufen, aber nie
  definiert" — **Falschnadel**. `refs_a` traf `$_sbx (`, eine Variable vor
  der Klammer. Der Autor hatte diese Klasse für Kommentare abgedeft
  („…sonst melden Kommentar-Hinweise eine Falschnadel"), in
  String-Literalen aber übersehen. Fix: `$` aus der negierten Zeichenklasse
  (`[^A-Za-z0-9_$]`); `$_name(` kann in Bash nie ein Aufruf sein.
- **Tests**: `test/test_selfedit.sh` (**65 Nadeln**, 14. Läufer) — Zielprüfung,
  Anlegen, grüner Weg mit Gate-Reihenfolge, **zwei** rote Wege mit
  byte-identischem Original, Negativ-Gate (fremdes Ziel → keine Sandbox,
  kein Gate), beide Escapes samt S4-Widerspruchs-Nadeln, Abschnitt am
  echten Repo-Baum, **Regression `~`-Pfad**, `_rc != 0`-Zweig (Edit scheitert
  → keine Gates, Original byte-identisch), Anlegen-Fehler, Übernahme-Fehler.
  Gates im Fixtur-Baum durch Stubs ersetzt, die ihre Benennung aufzeichnen —
  belegt die **Verdrahtung** ohne ~84 s pro Lauf.
- **Verifikation**: `bash -n` + `shellcheck -S warning` (inkl. Test und
  `selfcheck_lex.sh`) + selfcheck rc 0 ·
  `run_all.sh` **14/14 = 962 [PASS] = 948 Einzelf, 0 FAIL, rc 0** ·
  **8/8 Mutationen aufgedeckt** (dazu Tilde-Umgehung, „immer Gates grün",
  `_rc!=0`-Schutz entfällt) · E2E mit den **echten** Gates beidseitig:
  grün beförderte nach 14/14 der Suite (88–90 s, nach dem Fristen-Umbau
  erneut gefahren), rot blieb bei absichtlich kaputter Änderung
  byte-identisch (rc 1 in 5 s) ·
  Präzisionsabgleich gegen `git archive HEAD`: alle 11 bestehenden Runner
  diff 0.

### Behoben 2026-10-10 — ^C-Tests fielen aus der lex-REPL heraus ohne Defekt rot (SIGINT-/Mock-Erbgut)

- **User-Report**: „wenn lex den selfcheck ausführt, bekommt er immer ein
  Fail — weil lex läuft und Ctrl+C nicht getestet werden kann“.
- **Befund**: der Selfcheck selbst war rot-frei; rot fiel `run_all` — und
  **nur** aus dem Kontext lex: `test_input.sh` direkt grün, aus jedem
  Hintergrund-Job 3× FAIL (Reproduktion ohne lex:
  `bash -c 'bash test/test_input.sh' &`).
- **Root Cause**: Bash setzt für Hintergrund-Jobs SIGINT/SIGQUIT auf
  „ignorieren“; `tool_bash` → `_run_limited … &` vererbt das an
  `script`-PTY und getestete REPL (`SigIgn 0x06` vs. `0x00`) — ein `trap`
  auf geerbt-ignore-Signalen ist wirkungslos. Zweitfund: geerbtes
  `LEX_MOCK` machte drei `test_features`-Nadeln rot (live-Status + zwei
  Tor-Gates).
- **Fix**: einmaliger `exec env --default-signal=INT bash "$0" "$@"` in
  beiden Test-Einstiegen (`test_input.sh`, `run_all.sh`, nur bei gesetztem
  `SigIgn`-Bit 2 → kein Endlos-Reset) + Isolation der betroffenen Nadeln
  (`env -u LEX_MOCK -u LEX_MOCK_FILE`, `LEX_MOCK=""`-Prefix). Produktivcode
  `_run_limited` bleibt unangetastet (Schritt-51-`--foreground`).
- **Verifikation**: Hintergrund-Job 31/0 (vorher 27/3) · Suite über
  `tool_bash` mit geerbtem Mock **13/13** · direkt ohne und mit Mock je
  13/13 = **896 [PASS]** · lint + selfcheck rc 0.

### Hinzugefügt 2026-10-10 — `tools/selfcheck_lex.sh`: Selbstcheck nach jeder Selbstmodifikation

- **Auslöser**: die User-Frage, ob der Self-Edit-Guard (`50-guard-lex-selfedit`)
  am Tor-Stealth-Defekt schuld war — **Auslöser ja, Ursache nein**: der Guard
  zwang den Ersatz-Lauf auf bash+Python, dieser brach vor dem Schreiben ab.
  Die eigentliche Lücke: `bash -n` und `shellcheck` melden „aufgerufen, aber
  nie definierte Funktion“ nicht — der Fehler kam erst zur Laufzeit.
- **`tools/selfcheck_lex.sh`**: `bash -n` + `shellcheck -S warning` +
  Referenz-gegen-Definitions-Abgleich (interne `_name(`-Aufrufe, Kommentare
  ausgeblendet) + Soll-Liste von 16 Kernfunktionen gegen halbgeschriebene
  bzw. beschädigte Skripte. rc 0 = sauber, rc 1 = Befund mit Namen.
- **Guard-Meldung** (`~/.lex/hooks/pre_tool/50-guard-lex-selfedit`) nennt
  jetzt die Nachpflicht nach jeder — auch bash-basierten — Änderung:
  syntax → selfcheck → `run_all` → Testbeleg statt Behauptung.
- **Regeln**: `LEX.md` §0.1 C (Selbstmodifikation/Read-Modify-Write),
  §0.1 D (Selfcheck-Pflicht), §0.1 E (DoD-Checkbox), §7/89.
- **Tests**: +8 Nadeln in `test_features.sh` (Selfcheck auf `lex` ok,
  beide Bruchformen rc 1 mit Namen, E2E `/lexpen on→off` ohne
  „Kommando nicht gefunden“) → `test_features` 560, `run_all`
  **13/13 grün**.

### Behoben 2026-10-10 — `/lexpen` startete Tor über eine Funktion, die es nicht gab

- **Symptom (User-Report)**: `lex: Zeile 5525: _tor_stealth_start: Kommando
  nicht gefunden` bei jedem Wechsel auf `/lexpen` — der Moduswechsel selbst
  lief trotzdem durch.
- **Ursache**: halber Einbau der Tor-Stealth-Runde — der Python-Ersatz-Lauf
  brach beim on-Branch mit `exit(1)` aus, **bevor** die Datei geschrieben
  wurde; die zwei Funktionsdefinitionen erreichten `lex` nie, ein nachfolgender
  `sed` schob nur den Aufruf nach. `_tor_stealth_stop` fehlte im off-Branch
  ganz. Details: `wiki/errors/2026-10-10-tor-stealth-aufruf-ohne-funktionsdefinition.md`.
- **Fix**: `_tor_stealth_start`/`_tor_stealth_stop` vor `cmd_lexpen`
  definiert und auf das gebaute Werkstatt-Skript `stealth-observe.sh --start`/`--stop`
  geroutet (Exit-Check über `proxychains` statt des curl-Wegs der Rohfassung,
  der die **echte** IP als verschleiert gemeldet hätte); `--stop` nur bei
  laufendem Tor (kein sudo-Prompt ohne Bedarf); Gates `LEX_TOR=0` + `LEX_MOCK`
  halten den Testpfad ohne Netz/sudo.
- **Tests**: +10 Nadeln in `test/test_features.sh` (beide Definitionen, der
  Stop-Aufruf im off-Branch, E2E `/lexpen` ohne „Kommando nicht gefunden“,
  Stub-Aufruf, beide Gates, Warnung bei fehlendem Skript) — `test_features`
  552, `run_all` **13/13 grün** · `bash -n` + `shellcheck -S warning` rc 0.

### Entfernt 2026-10-10 — Prompt-Modus `/lexlurk` und Wächter `lurk_watch.sh` komplett

- User: „/lexlurk ist auch very buggy. baue diese auch komplett auch lex
  zurück … auch was in der Werkstatt mit lexlurk in verbindung steht löschen“.
- **Aus `lex`** (5996 → 5717 Zeilen): Slash `/lexlurk` (REPL + oneshot),
  `cmd_lexlurk` samt Lazy-Create-Prompt, Ticker (`_lurk_ticker_*`,
  `_lurk_tick`, `_lurk_interval`), pending-Zähler (`_lurk_pending_add/drain/flush`),
  Prompt-Marker `lexl>`/`lexl!N>`, `/status`-Zweig, usage-Slash + LURK-ENVs.
  **Behalten**: `_pending_lock`/`_pending_unlock` — der flock-Helfer (N1) war
  historisch lurk-benannt, dient aber dem allgemeinen Mock-Konsum-Pfad.
- **Gelöscht**: `tools/lurk_watch.sh`, `~/.lex/lurk/`, `~/.lex/prompts/lexlurk.md`.
  In der Werkstatt gab es nichts lurk-spezifisches.
- **Tests**: lurk-Zone in `test_features.sh` raus — `test_features` 542,
  `run_all` **13/13 = 877 [PASS]** · `shellcheck` rc 0.

### Entfernt 2026-10-10 — kompletter Rollback des Chat-Integrations-Builds (User-Auftrag)

- User: „egal stop mache alles rückgängig — /lexchat raus, Pipeline
  löschen, Netz-Brücke wiederherstellen — das ist mir zu fragile“.
- **Zurückgebaut auf den Vorkommen-Stand**: `/lexchat`-Modus in `lex`
  (`git checkout`), Test-Erweiterungen, `tools/lurk_watch.sh`.
- **Gelöscht**: Werkstatt-Pipeline-Skript, Terminal-Bridge-Modul, FIFO und
  Logs im damaligen Chat-Client-Verzeichnis.
- Das private Netz-Werkzeug (kein Git-Repo) wurde manuell auf den direkten
  Default zurückgebaut: kein tmux, kein `pipe-pane`-Log — wieder direkter
  Terminal-Betrieb. Der Config-Backtick-Fix (`` `networks` `` im Here-Doc
  wurde als Command-Substitution ausgeführt) bleibt erhalten.
- **VERIFY**: `shellcheck -S warning` rc 0 · `git status` leer ·
  `./test/run_all.sh` **13/13 grün**.

### Behoben 2026-10-09 — Pfad-Wahrheit: der System-Prompt nannte die Projekt-Wurzel nicht

- Der System-Prompt sagt jetzt „Dein Projekt liegt AUSSCHLIESSLICH in
  <Repo-Verzeichnis>“ (dynamisch aus dem Skript-Pfad, `lex:639`, gilt in
  beiden Prompt-Modi); `CLAUDE.md` bekommt die Regel „Pfad-Wahrheit (ohne
  Ausnahme)“ — `~/Ai/<repo-name>` ist ausschließlich die GitHub-Push-Kopie
  (EN-Port) ohne Betriebsbedeutung, `~/Ai/wiki` nur Gedächtnis/Log.
  LEX.md §5-Repo-Tabelle auf 1174/1161 nachgezogen. Ursache war die
  Pfadhysterie im Live-Chat-Test 2026-10-09 (Modell suchte unter
  `~/Ai/`). Außerdem: MCP-Discovery-Cache für die echten Server
  gebaut — 5 Server, 48 Tools in `~/.lex/mcp.cache.json`, Schema 19+48=67.

### Hinzugefügt 2026-10-08 — Macht-Runde (sechs Bausteine, jeder einzeln verifiziert)

- **Hooks**: `hooks/pre_tool/` und `hooks/post_tool/` (executable Dateien);
  `pre_tool` mit rc != 0 blockiert den Tool-Aufruf fail-closed (auch bei
  Timeout), `post_tool` beobachtet `LEX_HOOK_EVENT/TOOL/ARGS/RC` und bleibt
  unsichtbar am Ergebnis. Gates: `LEX_HOOKS=off`, `LEX_HOOK_TIMEOUT` (5 s).
- **Sub-Agenten**: `agent(task, mode ∈ explore|plan|review|summarize)` —
  eigener, frischer Kontext, Tiefen-Gate (kein Sub-Sub-Agent), Turn-Limit
  `LEX_AGENT_MAX_TURNS`, Ergebnis ist reine Textausgabe.
- **Parallele Tool-Calls**: aufeinanderfolgende zustandslose Tools
  (`read_file`, `list_files`, `search`, `mem_list`, `mem_search`) laufen in
  Hintergrund-Subshells, eingesammelt wird in Original-Reihenfolge — MCP,
  `agent`, `bash` und schreibende Tools bleiben serial. Gate
  `LEX_PARALLEL=off`. Messung (3 Calls + 0,5-s-Hook): 1,4 s statt 3,5 s.
- **MCP-Native**: Discovery-Cache `~/.lex/mcp.cache.json` mit den
  `inputSchema` der Server; daraus eigene Schema-Einträge
  `mcp__Server__Tool`, direkt aufrufbar. `mcp(server, "__refresh")` baut den
  Cache für alle Server neu, geänderte argv in `mcp.json` invalidiert die
  Einträge automatisch, `LEX_MCP=0` schaltet sie ab.
- **Skills**: `~/.lex/skills/<name>/SKILL.md` (Frontmatter `name`/
  `description` + Body) wird automatisch in den System-Prompt injiziert —
  auch beim Prompt-Moduswechsel (`/lexpen`, `/lexlurk`). Gates
  `LEX_SKILLS=off`, `LEX_SKILL_MAX` (6000 Zeichen je Datei),
  `LEX_SKILL_TOTAL` (40000 Zeichen insgesamt).
- **Background-Tasks**: 19. Werkzeug `task(action, command?, id?, name?,
  tail?)` mit `start|list|status|result|kill` — Befehle laufen in eigener
  Sitzung losgelöst weiter, Ausgabe und Rückgabe liegen unter
  `~/.lex/tasks/<id>/` und bleiben nach Ende von lex lesbar. Gleiche
  Deny-/sudo-/approve-Hürden wie `bash`, `LEX_TASK_MAX` (5 gleichzeitig),
  `LEX_TASK_TIMEOUT` (→ rc 124), `--status` nennt die Task-Zeile.
- Werkzeug-Zähler **17 → 19** (Prompt, Schema, Tests, README, CLAUDE).
- `run_all` 1031 → **1174 [PASS] = 1161 Einzelf**, `lex` 5145 → **5995
  Zeilen**.

### Behoben 2026-10-08 — `exec 2>/dev/null` legte den stderr der ganzen Shell still

- `_lurk_pending_lock`/`_lurk_pending_unlock` nutzten
  `exec {fd}>… 2>/dev/null`; `exec` ohne Befehl leitet Umleitungen auf die
  **ganze Shell** um — nach dem ersten Lock/Unlock war fd2 dauerhaft auf
  `/dev/null`. Im Testpfad verschwanden dadurch ab test_features:406 alle
  `[FAIL]`-Meldungen (das ist die Ursache der stillen rc=1-Läufer vom
  2026-10-08). Fix: Umleitung in eine Gruppe `{ exec {fd}>…; } 2>/dev/null`
  — gilt nur währenddessen, der fd bleibt offen. Details: `LEX.md` §6 #41
  und `~/Ai/wiki/wiki/errors/2026-10-08-exec-2-dev-null-totete-shell-stderr.md`.


### Behoben 2026-10-08 — Restliche Audit-Testlücken §6 (§7/80)

- **browser `back`/`tabs`/`close`**: die Mapung auf `browser_navigate_back`/
  `browser_tabs`/`browser_close` und die index-Validierung waren nie geprüft;
  `test/fake_mcp.sh` kannte die drei MCP-Tools nicht → erweitert (list/
  select); **+6** `test_features`.
- **fake_mcp-JSON-RPC-Kontrakt**: `notifications/cancelled` ohne id → keine
  Antwort, unbekannte Methode → `-32601`, Server danach noch ansprechbar —
  vorher nur in der `fake_mcp.sh` selbst; **+3** per Pipe.
- **`_tools_off`-Body** (`test_compaction`): vorher nur ein Quell-Anker —
  jetzt funktional (Summary-Request `[]`, Normal-Request mit Werkzeugen); **+2**.
- **`do_status`-Positiv-Ausgabe** (`lurk_watch`): `Lauf aktiv (Marker
  .running)` nach `--start`; **+1** — vorher nur der Negative-Fall.
- Audit §6 damit **13/13 erledigt**.
- **O2** (`lex`): Kürzung an der Zeichengreise (`_hint_args`, Tool-Fehler,
  Trace) — `%.Ns` kürzte Bytes und konnte mitten im Mehrbyte-Zeichen enden;
  jetzt `${v:0:N}`; **+1** `test_features`.
- **O3** (`lex`): Mock-Konsum (`head`+`tail`+`mv`) jetzt unter
  `_lurk_pending_lock` — parallele Läufe derselben `LEX_MOCK_FILE` lasen vorher
  dieselbe Antwort und schrieben in dieselbe `.tmp`; **+1** (deterministisch).
- `run_all` 13/13 = **1031 [PASS] = 1018 Einzelf** (1017→1031); lint sauber;
  `lex` 5134 → **5145 Zeilen**.

### Behoben 2026-10-08 — Audit-Testlücken-Runde (§6, #79)

- `test_features` R4/R5/R6 (lurk_watch): `*_SNAP`-Fixtures jetzt auch bei
  `--start` — vorher war die Baseline der echte Maschinenstand (ss/ip/
  Schlüsseldateien), R4/R5 feuerten nur zufällig, R6 auch ohne Änderung rc1;
  jede Fixture wird nach ihrem Check zurückgesetzt (`LEX_LURK_NO_SNAP=1`
  schreibt die Baseline nicht fort). Needles literal-korrigiert
  (`neu seit Baseline: 10.0.0.5 wlan0`, `0.0.0.0:4444`,
  `prompt    : standard` statt grep-Syntax `\|`).
- `test_http` fake_server „Port belegt“: zweiter Lauf vor dem kill des
  Fremd-Listeners (vorher war der Port frei → keine Meldung + ein zweiter,
  nie aufgeräumter Listener), Needle literal (`belegt`).
- `test_proxy`: `contains`/`assert` fehlten komplett → „Kommando nicht
  gefunden“ ließ `FAIL` unangetastet, der Läufer ging **still grün** und die
  M7-Prüfungen liefen nie; Helfer ergänzt, invertierter rc0-Assert korrigiert,
  Port-belegt-Test mit Fremd-Listener (eigener Proxy wird vor dem ss-Check von
  `_running` abgefangen), `LEX_PROXY_DIR` nach `$TMP`, Ports 24618/24619 in
  die Freiheitsliste.
- Nur `test/` geändert, `lex` unverändert (5134 Zeilen).
- `run_all` 13/13 = **1017 [PASS] = 1004 Einzelf** (1003→1017); lint sauber.

### Behoben 2026-10-08 — Audit Mittel/Niedrig (M1–M13, N1/N2/N5/N7–N15; N3/N4/N6 übersprungen)

- **M1** `_tool_spill`: umask 077 + chmod 600 + `_redact`, Ordner chmod 700; +3 `test_limits`
- **M2** `session_init` idempotent (+2 `test_features`); **M3** `_load_settings` `max_nudges`/`silent_turns` + JSON-Warnung (+3)
- **M4** `--eval`+`load_config`/`log_dir`/rc1; **M5** `/server` aus `_api_url`+rc1, argparse `--approve`
- **M6** `_kill_tree` (BFS TERM→KILL) + **M7** `_port_owned_by`/PORT-Validierung/Bind-Beweis; +11 `test_proxy`
- **M8** `_snap_write` (mktemp in `$DIR`, `mv -f`, chmod 600) + **M9** `alert()` via `jq -cn --arg`; +8 `test_features`
- **M10** RUN-Marker nur wenn existent; +4; **M13** werkstatt_index arg-Validierung rc2 + mktemp in `$HT`; +5
- **N1** pending-Zähler flock-geschützt (`_lurk_pending_lock/add/drain`, fd im AKTUELLEN Prozess); +2 `test_features`; **N2** `_loop_run`-Reset nach record (+1); **N5** `_lurk_interval` (+4); **N8** `_float_or` regex (+7); **N9** `run_all.sh` syntax_check broad + Testboden-Selftest
- **N10–N15** Doku-Sync LEX.md (Leerzeile, Datum, Next-Step, Hebel, Sort+Lücke, Format, „damals kein Commit"×13, Commit-Stand, #77→679eb45)
- `run_all` 13/13 = **1003 [PASS] = 990 Einzelf** (941→1003); lint sauber; `lex` 5001 → **5134 Zeilen**; §5-Zeilenkarte neu; README/CLAUDE/MAPPE synchronisiert

Bericht: `AUDIT-2026-10-08.md` (0 kritisch, 6 hoch, 13 mittel, 15 niedrig,
17 Beobachtungen). Jeder Fix einzeln gebaut und danach vollständig getestet.

- **`_redact()` übersah URL-Credentials und `user:`/`login:`-Paare**
  (Audit H1): Prefilter mit `case "${out,,}"` (`*pass*`, `*secret*`,
  `*token*`, `*key*`, `*auth*`, `*bearer*`, `*://*@*`, `*sk-*`, `*xox*`,
  `*user:*`, `*login*`), Redaktion in drei sed-Stufen (doppelt, einfach,
  unquotet) plus `user:`/`login:`-Regel; die Anführungszeichen bleiben
  erhalten → das Session-JSON bleibt gültig. Tests +10 → `test_features`.
- **`write_file`/`append_file` akzeptierten leere Pfade und Verzeichnisse**
  (H2): jetzt rc1 mit `Fehler: Pfad leer.` bzw. `Fehler: '<path>' ist ein
  Verzeichnis.` Tests +7 → `test_tools`.
- **`lurk_watch.sh` Peer-Regel prüfte die Port-Spalte statt die IP**
  (H3): `snap_peers` `$4` → `$5` — externe Peers wurden vorher nie
  alarmiert. Tests +4 → `test_features`.
- **`lurk_watch.sh` zählt jetzt erfolgreiche Logins** (H4): `login_count()`
  (`Accepted …`), Counts-Zeile `fb=/au=/login=`, neue Regel R2b
  `alert high login`; Bestands-Baseline ohne `login=` überspringt die Regel.
  Tests +5 → `test_features`.
- **`llama-proxy.sh` `stop` könnte fremde Prozesse killen** (H5):
  `_is_our_proxy()` prüft `/proc/$pid/cmdline` (fallback `ps -o args=`)
  auf `ncat` + `--listen`; fremde PID → Fehler rc1 ohne Kill, verwaistes
  PID-File → rc0 + Aufräumen. Tests +3 → `test_proxy`.
- **Doku-Zahlen** (H6): README + LEX.md auf den Ist-Stand (5001 Zeilen,
  11 Testdateien, 928 Prüfungen, Default `LEX_REASONING_MAX=0` /
  `LEX_TRACE_RESULT_MAX=0`), §5-Zeilenkarte neu generiert.
- `run_all` 13/13 = **941 [PASS] = 928 Einzelf**; lint sauber; `lex`
  4966 → **5001 Zeilen**. Kein Commit (Auftrag offen).

## [0.2.1] — 2026-10-08

### Behoben 2026-10-08 — `/lexlurk` Eingabe-Fix (kein `read -t` mehr im REPL-Loop)

- **Getippte Eingaben überleben den Wächter-Tick:** `read -t
  ${LEX_LURK_INTERVAL:-20}` mitten in der Eingabe verwarf bei jedem Tick
  die bis dahin getippten Tasten (Repro tmux: `abc` → Tick → nur `def`
  kam an), und `_lurk_tick` druckte `⚠ LURK`-Zeilen direkt in die
  Eingabezeile (User-Report „input goes crazy, jumps back, overwrites
  typing every few seconds").
- **Hintergrund-Ticker:** `_lurk_ticker_start()` als Subshell (alle
  `LEX_LURK_INTERVAL` → `_lurk_tick`; `kill -0 $$` verhindert
  Waisenprozesse), gestartet nur bei TTY in `cmd_lexlurk on`, gestoppt
  bei `off` / `cmd_lexpen`-Verdrängung / REPL-Ende
  (`_lurk_ticker_stop` = kill + `pkill -P` für das laufende `sleep` +
  wait).
- **pending statt stdout:** `_lurk_tick` schreibt die fortlaufende Datei
  `${_lex_home}/lurk/pending`; `_lurk_pending_flush` meldet vor dem
  nächsten Prompt `⚠ LURK — n neue Alarm(e)` und zählt `_lurk_open`
  (Marker `lexl!N>` unverändert); Glocke über
  `( printf '\a' > /dev/tty ) 2>/dev/null` in der Untershell (ohne TTY
  still, flach meldete bash den Redirection-Fehler).
- Tests +9 → `test_features` 621; `run_all` 13/13 = 912 [PASS] = 899
  Einzelf; lint sauber; `lex` 4912 → 4966 Zeilen; E2E tmux (2-s):
  `lexl> abcdef` überlebt zwei Tick-Feuer ✓.

## [0.2.0] — 2026-10-08

### Hinzugefügt 2026-10-08 — Prompt-Modus `/lexlurk` (Lurk-Wache) + `/help`-Übersicht

- **`/lexlurk [on|off|status|alerts [n]|check]`:** zweiter Prompt-Modus
  neben `/lexpen` (Slot 0, exklusiv — der eine verdrängt den anderen mit
  Hinweis); Lazy-Create `~/.lex/prompts/lexlurk.md` mit Blue-Team-Wächter-
  Persona (DE, „Befund vor Bewertung", „Kein Alarm ohne Beleg"); Marker
  `lexl>` bzw. `lexl!N>` bei offenen Alarmen; `/status`-`prompt`-Zeile und
  `usage()` (inkl. live „Modus gerade aktiv") kennen den Modus; Session-
  Record `{type:prompt_mode,mode:lurk}`.
- **`tools/lurk_watch.sh`** (kein 18. lex-Tool): Wächter mit 6 Regeln —
  fail2ban-Ban-Delta, Auth-Fehler-Delta, neue externe Peers, neue Neighbor,
  neue Listen-Ports, geänderte Schlüsseldateien; Baseline + `alerts.jsonl`
  unter `~/.lex/lurk/`, Snapshots werden nach jedem Check fortgeschrieben
  (jede Abweichung genau 1× gemeldet), rc 0/1/2, alle Pfade per
  `LEX_LURK_*`-ENV umlenkbar (Test-Isolation).
- **Wächter-Tick ohne Tokens:** `read -t ${LEX_LURK_INTERVAL:-20}` in der
  REPL-Loop (Timeout rc>128 ohne `_int_seen`); bei Alarm: Ausgabe am
  Prompt, Glocke (`\a`), `notify-send` hinter Gate `LEX_LURK_NO_NOTIFY` —
  bewusst nur Anzeige, kein Auto-Turn.
- **`/help`-Übersicht:** Slash-Liste um `/lexlurk`-Unterbefehle ergänzt
  plus live „Modus gerade aktiv: Original|/lexpen|/lexlurk".
- Tests +48 → `test_features` 612; `run_all` 13/13 = 903 [PASS];
  `lex` 4711 → 4912 Zeilen.

### Hinzugefügt 2026-10-07 — Werkstatt-Pakete (Werkstatt-Index, Schnelltechniken, Verfahrensregel)

- **Werkstatt-Index `WERKSTATT.md`:** ehrlicher Werkstatt-Index (eigene Skripte mit
  Aufruf, alle installierten Tools mit Zweck + Schnellaufruf, Ablagen,
  Repo-Struktur) — Lex liest ihn vor Tool-Suche/Installation/Pentest-Aufgabe.
- **`wiki/concepts/schnelltechniken.md`:** 6 eigene geprüfte Ketten für
  Zeitdruck (tshark-Scan-Erkennung, Beacon-Check, IP-Prüf-Kette,
  nmap-Schnell, osint-pipeline, pcap-Fix) mit Befehl/Dauer/Erfolgsmuster;
  Pflege-Regel: schneller Erfolg → sofort eintragen (auch nach 1×).
- **Prompt-Regel „Werkstatt-Verfahren":** vorher nachschlagen (Index +
  Playbooks + Schnelltechniken), nachher festhalten (Technik, neues Tool) —
  ergänzt die bestehende „Eigene Playbooks pflegen"-Regel. Tests +2 → 843.
- **`tools/werkstatt_index.sh`:** Auto-Block in der WERKSTATT.md auffrischen
  (Versionen der Werkstatt-Tools, Flag-Map + ANSI-Filter, `--check`-Dry-Run,
  Marker-Gate, idempotent) — Prompt-Verweis in der Werkstatt-Verfahren-Regel.
  Tests +9 → 852.

### Geändert 2026-10-08 — Paket D: Wiki ist Quelle der Wahrheit für Playbooks

- **`playbooks`/`playbook_steps` (DB `lex`) sind nur noch Spiegel/Seed** —
  Pflege ausschließlich in `wiki/concepts/` (Neusäung via Seed-SQL unter
  `~/.lex/backups/`); Table-Comments markieren den Spiegelstatus.
  Verankert in `playbook-erstellen.md` §7, `pentest-db-architektur.md`
  (Geltungsbereich + Seed) — kein Prompt-/Code-Änderung nötig.

### Geändert 2026-10-07 — Anti-Verweigerungs-Guard: Verteidigung jeder Art

- **`_prompt_lexpen_guard` erweitert:** nach belegtem Angriff ist nun jede
  Art der aktiven Verteidigung und Gegenwehr gegen genau diesen Angreifer
  erlaubt (Gegen-Scans, Baiting, Honeypot, Sperrungen, Provider-Meldung,
  Gegenmaßnahmen am Netz) — keine Ausnahme nach Art der Maßnahme. Die
  Playbook-§1-Regel „Erlaubnis zuerst" gilt explizit nur für eigene
  initiativ begonnene Aktionen, nicht für die Reaktion auf einen belegten
  Angriff; kein ethisch/rechtliches Verweigern, keine Belehrung über
  Rechtsfolgen (Legalität entscheidet der Mensch am Terminal).
  `wiki/concepts/security-playbook.md` §1 um dieselbe Ausnahme ergänzt.
  Auslöser: Session `anonym` (tshark-Capture, SSH-Scan alle 5 s,
  C2-Beacon alle 30 s → lex verweigerte den Gegenangriff mit Rechtstabelle).
  Tests +2 → 841/828.

### Geändert 2026-10-07 — Mindestversion Bash 4 (Versions-Guard)

- **Bash ≥ 4 wird ab sofort erzwungen**: `coproc` (MCP-Session) ist ein
  Bash-4.0-Reserviertes Wort — auf Bash 3.2 (macOS-Systembash) scheiterte
  das Parsen der Datei mit einem kryptischen Syntaxfehler. Neuer Guard im
  Dateikopf meldet klar `braucht Bash >= 4 … brew install bash` und
  beendet vor dem coproc-Block. README-Voraussetzung korrigiert (vorher
  stand dort fälschlich „keine Bash-4-only-Konstrukte").

### Hinzugefügt 2026-10-07 — Bedrohungsmodell (§8 E)

- **Bedrohungsmodell als Text**: `wiki/concepts/sicherheitsmodell.md` —
  Vertrauensmodell (Verbote richten sich gegen das Modell, nicht gegen den
  User), 10 harte Verbote aus der segmentweisen Deny-Liste, sudo als
  4-Stufen-Gate, Defense-in-Depth-Tabelle und ehrliche Lückenliste
  (Blacklist bewusst, Prompt-Injection, Landlock offen).

### Geändert 2026-10-07 — Overthinking-Optimierung (adaptives Reasoning-Budget + HUD-Metrik)

- **Adaptives `reasoning_budget`:** Default **8192 → 2048** für den ersten
  Turn, neu `reasoning_budget_followup` **768** für Folge-Turns
  (`call_api` wählt an `_turn_count`; Compaction-Override 0 schlägt beides).
  Config-Tier-Key `reasoning_budget_followup`, ENV
  `LEX_REASONING_BUDGET_FOLLOWUP`, settings-Template, `/status` und
  `usage()` ergänzt. Motivation: Recherche (Amazon 7–10× Overthinking,
  ARES −52,7 %, TALE −67 %, QwenCloud `enable_thinking:false` →
  −60–75 % Latenz; `reasoning_effort: low` wird bei Qwen-Varianten
  häufig ignoriert → Budget-Deckel statt effort).
- **HUD-Metrik „denke ~N tok":** `run_turn` merkt
  `_last_reasoning_chars`, `_trace_hud` rendert pro Turn
  `· denke ~<Zeichen/4> tok` — Grundlage für die geplanten Hebel 2
  (`auto_disable_thinking_with_tools`) und 4 (`reasoning_effort`).
- **Live-Nachweis** (isoliertes `LEX_HOME`): Turn 1 `20.0s · … · denke
  ~383 tok`, Folge-Turn `4.0s · … · denke ~27 tok` (vorher ~1000
  Reasoning-Tokens/Turn).
- **Hebel 2 `auto_disable_thinking_with_tools` (offen als Default, on als
  Option):** Config-Key `auto_disable_thinking_with_tools` (Tier 2) +
  `LEX_AUTO_DISABLE_THINKING_WITH_TOOLS` (on/off), `call_api` sendet
  `chat_template_kwargs:{auto_disable_thinking_with_tools}` pro Request
  immer mit (`false` = Template-Default, unverändertes Verhalten),
  `/status`-Zeile `thinking`, settings-/help-/header-Ergänzungen.
  Isoliert bewiesen (3 Live-Requests): `ctk:true` + Tools → kein
  `reasoning_content`, `ctk:false` → wie bisher. A/B je 2 Läufe mit
  identischer Mini-Task: **on** −60 % Zeit, aber falsches Ergebnis
  (`3` statt `7`) bzw. 200-Turn-Loop (rc=1, 539 s) → **Default bleibt
  `off`**. Sekundärbefund: `_rep_detect`/Fail-Gedächtnis fangen einen
  leeren-Content-Loop mit near-identischen Args nicht ab.
- **Hebel 4 `reasoning_effort` verworfen:** 3 Requests je `low`/`xhigh`
  (gleicher Prompt, `reasoning_budget_tokens:2048`) → Reasoning-Mittel
  213 vs. 212 Zeichen, keine systematische Differenz; Kontrolle
  `enable_thinking:false` → 0/0/0. Der Parameter wird vom Modell ignoriert
  → Steuerung bleibt allein beim Budget (Hebel 3). Reihenfolge 1→3→2→4
  abgeschlossen (1+3 gebaut, 2 gebaut/Default off, 4 verworfen).
- **Silent-Turn-Guard (Schlupfloch aus dem Hebel-2-A/B geschlossen):**
  Der Fail-Gedächtnis-Wächter sieht nur identische
  `name|args|result`-Signaturen — der `adwt=on`-B2-Loop hatte 195
  verschiedene Args und 200/200 Turns ohne sichtbare Zwischenaussage und
  lief bis `max_turns` (rc=1, 539 s). Neu in `run_turn`: Streak
  zählbarer textfreier Tool-Turns (Reset bei sichtbarem Text), Default
  Schwelle **12** (`LEX_SILENT_TURNS`, `0` = aus), unter dem
  `LEX_LOOP_GUARD`-Switch; weicher Nudge mit Antwortpflicht, beim
  zweiten Mal hart `rc=1`; Session-Record `{type:"silent_guard"}`.
  Grenzwert gegen gemessene gesunde Runs geprüft (adwt-off: 9/8/5
  textfreie Turns hintereinander → kein Fehlalarm).
- **Tests +23 → 811** (`test_features` 528 → 533, `test_sse` 30 → 32,
  `test_loop` 24 → 34; 824 PASS-Zeilen abzüglich 13 Läufer-Marken),
  `run_all.sh` **13/13** seriell; `bash -n` + shellcheck warning-sauber;
  `LEX.md` §5-Mappe 3× neu gezogen (48 Einträge gesamt). Dabei fing
  der neue Session-Record-Assert live einen jq-Syntaxfehler im neuen
  Code (fehlendes schließendes `"` → Record ging still verloren).
- **A/B-Experiment Prompt-Scaffolding vs. MCP sequential-thinking
  abgeschlossen und verworfen:** A0 Baseline 54,8 min/9 von 12 Rubrik-
  Punkten, A1 mit Prompt-Zeilen 34,6 min/10, A2 A1+MCP 246,9 min/11,
  A3 nur MCP 52,3 min/10 — MCP-Tool in allen Läufen **0×** aufgerufen.
  Entscheidungsregel (≥ +1 Rubrik-Punkt bei ≤ +50 % Zeit) nicht erfüllt →
  Prompt-Zeilen wieder raus, `~/.lex/mcp.json` gelöscht (Defaults aktiv).
- **Prompt-Nadeln „Denken hat ein Ende" + „Belegen oder benennen"
  (Recherche → A/B, Go für lex und lexpen):** Zwei Bullets in `_prompt_ops`
  — Stopp-Regel (Sache höchstens einmal mit einem Tool prüfen, kam das
  Ergebnis ist es Fakt; Abwägen nur bei Fehlschlag; kreist der Gedanke →
  Antwort fertig, aussprechen statt weitergrübeln) und Belegkette
  (Repo → Wiki → `web_search`/`web_fetch` → erst danach „weiß ich nicht";
  ein plausibler Einfall ersetzt keine Quelle). Greift in Original- **und**
  `/lexpen`-Modus (der hängt `${_prompt_ops}` an die Persona), Ops-Anfangs-
  Muster unverändert. Recherche-Kernbefund: **Länge** per Prompt nicht
  steuerbar (Token-Limits ignoriert [arXiv 2511.04108], „do not overthink"
  wirkungslos [Thought Terminator], eigener effort-Test 213 vs 212 Z),
  **Richtung** per Prompt wirkt (Self-Doubt arXiv 2505.23480: −37,1 %
  Reasoning bei +3,6 % Genauigkeit; Stop-Cue-Forschung [JET/Self-Braking]
  gegen Wiederprüfung bereits geprüfter Ergebnisse). A/B live (identische
  Task, Budget 2048/768 fix, isoliertes `LEX_HOME`, je 2 Läufe): Reasoning
  **7795 → 4548 Z (−42 %)**, Zeit **118,0 → 84,3 s (−27 %)**, Turns 12 → 10,
  **4/4 Ergebnisse korrekt**, kein Loop. Tests +4 → **815**
  (`test_features` 537), `run_all.sh` 13/13, §5-Mappe neu gezogen
  (43 Zeilen +2).
- **Display-Kappungen abgeschafft + Fake-Server nur noch localhost
  („ich will alles sehen"):** Tabellen-Zellen waren im Render auf
  40 Zeichen mit `…` gekappt (`_md_render`), Reasoning-Dumps auf 4000
  (`LEX_REASONING_MAX` Default) — beides jetzt **Default unkürzt**
  (`LEX_MD_CELL_MAX=0` bzw. `LEX_REASONING_MAX=0`; Werte >0 begrenzen
  weiterhin). Dazu der Security-Fund aus dem Audit-Lauf: zwei verwaiste
  `ncat --listen 28774/28775`-Listener der eigenen Tests horchten auf
  **0.0.0.0** (Handler-Scripts in tmp gelöscht, Prozesse liefen weiter;
  inzwischen tot) → `fake_server.sh` bindet jetzt `127.0.0.1`.
  Bewusst unverändert: Repetition-Guard-Render (2000, Loop-Schutz #46)
  und die Kontext-Caps (`search` 200, `_tool_max_output` 50000).
  Tests +4 → **819** (`test_features` 541), `run_all.sh` 13/13.

### Behoben 2026-10-07 — Verbliebene Display-Kappungen weg + Escape-Pipe-Fix (O1)

- **Verbliebene Display-Kappungen weg + Escape-Pipe-Fix in Tabellen
  (O1):** Tool-Ergebnisse im Trace waren auf 8 Zeilen/600 Zeichen
  gekappt — `LEX_TRACE_RESULT_MAX` jetzt **Default 0 = vollständig**
  (Wert >0 = Zeilenlimit). O1 behoben: `\|` in Tabellenzellen ist
  GFM-Escape und kein Spaltentrenner mehr (`cells()` schützt vor dem
  Split). Tests +4 → **823** (`test_features` 545), `run_all.sh` 13/13.

### Hinzugefügt

- **Wiederholungs-/Loop-Erkennung (Schritt 46):** `_rep_detect` prüft den
  sichtbaren Assistenten-Text in `run_turn` vor dem Render auf drei Arten —
  A1 Trailing-Run (dieselbe 8–32-Zeichen-Unit ≥6× am Ende), A2 Satz-Loop
  (ein Satz ≥40 Zeichen ≥4× identisch), A3 Rep-4 (Anteil doppelter
  4-Gramme ≥0.35 ab 70 4-Grammen); Codeblöcke, Tabellenzeilen und
  Trennlinien werden ausgeblendet (False-Positive-Gate für den
  `/lexpen`-Stil), `reasoning_content` und tool_calls-Argumente sind nie
  im Scope (Scope-Regel aus deepseek-harness #3480). Reaktion: 1. Fund =
  weicher Nudge, 2. Fund = harter „entscheide jetzt in einem Satz"-Nudge,
  danach Truncation-Render (2000 Zeichen) statt Loop-Ausgabe — alles
  gegen das bestehende `_max_nudges`-Budget, dazu Log-Zeile und
  Session-Record `{type:repetition}`. Der Guard hängt am Code, nicht am
  Prompt → in Original- und `/lexpen`-Modus identisch wirksam. Neuer
  Läufer `test/test_repetition.sh` (+20 → **709** = 696 Einzelf +
  13 Läufer).
- **`/autosudo` + Adress-/Download-Regel im System-Prompt (Schritt 45):**
  Slash `/autosudo on|aus|Status` (ENV `LEX_AUTOSUDO=1`) überspringt nur
  die y/N-Freigabe im `_sudo_gate` — Passwort-/TTY-Fragen in `_sudo_ask`
  bleiben manuell; behebt den y/N-Blocker der Schritt-45-Läufe (zwei
  Hänge à 24/13 Minuten). Prompt-Bullet „Adressen & Downloads nie raten":
  GitHub-Owner/Release-Tags/Assets nur aus Quellen (Repo-Root-Status →
  expanded_assets → Verifikation, unter 1 kB = Fehlerseite), kein
  Release = go install/Source-Build. Live-Nachweis im Folgelauf: 3× sudo
  ohne Block, 0 geratene GitHub-Owner. Fund beim Schreiben: Prompt-Range-
  Anker in `test_features.sh` brach → Prompt-Bullets getauscht, Test
  unverändert.

- **Prompt-Modus `/lexpen` (Schritt 43):** Slash `/lexpen` tauscht Slot 0
  des Kontexts gegen die Senior-Engineer-Persona aus
  `~/.lex/prompts/lexpen.md` (beim ersten Aufruf angelegt, XP4→Lex, danach
  frei editierbar), `/lex` bzw. `/lexpen off` zurück zum Original —
  Verlauf und Wiki-Stand bleiben erhalten (`_wiki_ex()`), Session-Record
  `{type:prompt_mode}`, Prompt-Marker `lex*>`, `prompt`-Zeile in
  `/status`, Slash-Liste in `usage()`. Antworten im Modus: Deutsch
  (Prompt-Direktive, Nachtrag 2026-10-03 — vorher englisch),
  Titel-Block, „Chief", `✦ made by @Lex ✦`. Live-Verify am echten Modell
  (Persona-Antwort mit Attribution + nmap-Ablauf; danach `/lex` → wieder
  deutsch). +22 Prüfungen in `test_features.sh` → **691** gesamt.
- **Context-Compaction + Kontext-HUD (Schritt 42):** neue Slash
  `/compact` (force) und Auto-Trigger in `run_turn` komprimieren alte
  Nachrichten, sobald der geschätzte Prompt die Schwelle
  `ctx − max(max_tokens, buffer)` (Default 242144 → inert) überschreitet:
  `_pairing_ok` als jq-Gate (Rollen/`tool_call_id`/kein offenes
  `tool_calls`), Forward-Unit-Gruppierung, `[Nutzer]:`-Token,
  deutsches Summary mit Marker `<!--lex-compact-->` in Slot 1,
  Fail-safe bei leerem Summary (`_messages` byte-identisch),
  Session-Record `{type:compaction}` + Span. Config-Tier
  `ctx_limit`/`compact`/`compact_keep`/`compact_buffer` (2 + ENV
  `LEX_CTX_LIMIT`/`LEX_COMPACT`/`LEX_COMPACT_KEEP`/`LEX_COMPACT_BUFFER`),
  HUD `tokens X/Y (Z%) prompt + …`, `/status` mit `compact`-/`ctx`-Block,
  `usage()` nennt Slash + ENV. Neuer Läufer `test/test_compaction.sh`
  (77 Prüfungen) — als 12. Läufer in `run_all.sh` eingehängt. Schätzer
  `Bytes ÷ 3` (Live-Verify 02.10. gegen 17408 `prompt_tokens` kalibriert:
  `/4` lag 18 % zu tief).

- **Testlauf `test_limits.sh` (Schritt 38):** 17 Prüfungen, dass nichts an
  der lex↔llama-Grenze abgeschnitten wird — 280 000-B-Nachrichten in
  `_messages` **und** Session-JSONL, 250 000-B-System-Prompt, ganze
  60 000-B-Datei über `read_file`, Spill-Ablage vollständig mit Zeiger im
  Kontext, 150 000-Zeichen-Server-Antwort vollständig. Als 11. Läufer in
  `run_all.sh` eingehängt.

- **Testboden + Stream-Budget (Schritt 37):** `run_all.sh` läuft als Erstes
  `testboden` — ab, wenn eine Testdatei gegenüber `HEAD` gelöscht, als Runner
  referenziert aber nicht vorhanden oder vorhanden aber nicht eingebunden ist
  (negative Tests: alle drei Richtungen fehlgeschlagen → rc 1, normal → 0).
  `test/test_sse.sh` nummeriert ein Performance-Budget: 3000 Chunks unter
  2000 ms **und** vollständig ausgewertet (damals 29 s, heute ~0,12 s).
  Dazu Regeln in LEX.md §C/§D/§E: Optimierung braucht Test + Messung in
  derselben Änderung, Fixture-Tests müssen den Pfad brechen können,
  Experimente nur auf `opt/*`-Branch.
- **Observability / `lex --eval` (Schritt 36):** `span_log()` schreibt pro
  `dispatch_tool`-Aufruf einen append-only Span nach
  `~/.lex/log/spans.jsonl` (Felder `ts`, `name`, `args_hash`, `duration_ms`,
  `ok` — Argumente nur als `cksum`, ohne jq als TSV), dazu `_ms_now()` als
  Millisekunden-Uhr. Auswertung über
  `cmd_eval` = `./lex --eval [datei]` → Tool-Zählung, Fehler-Quote,
  Dauer (Sekunden), Verdict, Pro-Tool-Sektion und die letzten 10 Spans;
  fehlende Datei nur als Hinweis (rc 0). `usage` listet den neuen Modus. Tests: **`test/test_eval.sh`
  (16)**.
- **Ethical-Hacker-Persona + neutraler Werkstatt-Pfad (Schritt 18):** neuer
  System-Prompt-Block „Rolle & Expertise (Ethical Hacker)" — der
  User-Text wörtlich (Cybersecurity, Netzwerksicherheit,
  Penetrationstesting, Exploit-Entwicklung, Echtzeit-Erkennung,
  Sicherheitsbewusstsein, Berichterstattung, ethischer/legaler Ansatz)
  — zwischen Identität und Persönlichkeits-Block. Dazu `_htools_dir`
  mit hardcodiertem Default `$HOME/.lex/werkstatt` (Override
  `LEX_HTOOLS_DIR` in Tier-1), Prompt-Regel „Software & Tools IMMER in
  ${_htools_dir}" (mkdir -p; nie $HOME, nie /tmp), `--status` zeigt
  `htools`, `usage` listet die ENV-Variable. Tests +12 → **418**,
  `lex` 2418 → **2439 Zeilen**, §5-Mappe neu gezogen (76/76).

- **Wissens-Paket Security-Playbook (Schritt 19):** Wiki-Artikel
  `concepts/security-playbook.md` (Best Practices, Tool-Pipeline,
  Wireshark benutzen/lesen, Angreifer-IPs) + 5 Raw-Quellen (WSUG,
  Wireshark dfref, MITRE T1595) + Prompt-Nadel „bei Security-Aufgaben
  erst das Playbook lesen". Tests +1 → **419**, `lex` → **2440 Zeilen**.

- **Playbooks-erstellen-Methode (Schritt 20):** Wiki-Artikel
  `concepts/playbook-erstellen.md` (Sinn/Kontinuität, Wann-Kriterien,
  6-Schritte-Prozess, Vorlage) + Prompt-Nadel „Eigene Playbooks pflegen"
  + Raw-Quelle (Wikipedia Runbook). Tests +1 → **420**, `lex` → **2441 Zeilen**.

- **Browser-Steuerung (Schritt 22):** neues Tool `browser` (navigate|snapshot|click|type|press|back|tabs|close) über Playwright-MCP mit **System-Chrome** (`npx @playwright/mcp --browser chrome`, kein Download) — Accessibility-Snapshot-Workflow (kein Vision-Modell nötig), **ohne Write-Gate** (User-Entscheidung: volles Vertrauen). Prompt-Liste + Zyklus-Regel, Default-Config um `playwright`, `fake_mcp.sh` um browser-Aktionen, Schritt-22-Block. Tests +21 → **441**, `lex` → **2528 Zeilen**, Mappe 77/77.

- **Generisches `mcp`-Tool (Schritt 23):** `mcp(server, tool, arguments?)` mit Discovery (__tools → `tools/list` via neuem `list`-Modus in `_mcp_call`) + `tools/call` für beliebige Server — ab jetzt ist jeder neue MCP-Server nur noch `mcp.json` + Prompt-Nadel. `dispatch` akzeptiert `arguments` als Objekt oder String. Fund: __tools-Apostrophe brachen `_build_tools` still (SC1078) → korrigiert. Tests +15 → **456**, `lex` → **2581 Zeilen**, Mappe 78/78.

- **Desktop-Zugriff (Schritt 24):** MCP-Server `@agent-sh/computer-use-linux` (Wayland-first) eingebunden — Default-Config `desktop` + Prompt-Regel „Desktop-Aufgaben: erst __tools, dann state → handeln“, kein neues Tool (generisches `mcp` aus Schritt 23). `doctor`/`setup`: AT-SPI aktiviert, Screenshots/RemoteDesktop/Input bereit; Window-Targeting-Extension aktiviert sich beim nächsten Login. Tests +8 → **464**, `lex` → **2583 Zeilen**.

- **Postgres (Schritt 25, verbindlich):** PostgreSQL **16.15 user-space** unter `~/.lex/pg` (Debs per `dpkg -x`, kein sudo) mit DB `lex` (trust@localhost) + `start.sh`; MCP-Server **`@bytebase/dbhub`** (execute_sql/search_objects, volle Rechte, stdio) über Node 22 (nvm) + Wrapper `dbhub.sh`. lex nur Config+Prompt: Default-Config `postgres` mit DSN, mcp-Description, Prompt-Regel „Datenbank-Aufgaben: erst __tools, dann SQL“. Echt-Beweis: Discovery + INSERT via `tool_mcp postgres`. Tests +8 → **472**, `lex` → **2585 Zeilen**.

- **sudo-Gate (LEX.md §6 #13):** `tool_bash` darf jetzt `sudo` — aber nur
  über ein Gate, das **genau eine Aufforderung** zeigt. Ohne gültiges
  sudo-Ticket ruft `_sudo_ask()` `sudo -v` auf und zeigt vorher das
  Kommando auf der controlling TTY; das Passwort geht **direkt an sudo**
  und läuft nie durch lex. Mit gültigem Ticket wird `y/N` gefragt. Ohne
  controlling TTY wird abgelehnt. Neue ENV-Variablen `LEX_SUDO=0`
  (sperren) und `LEX_SUDO_APPROVE=0` (y/N-Frage weglassen); in `/status`
  als `sudo: 1|0` sichtbar, System-Prompt/Tool-Schema/`usage`/README
  entsprechend.

- **Debug-Proxy `tools/llama-proxy.sh`:** leitet Requests an den
  llama-Server weiter und protokolliert Request **und** Response
  (`.proxy/traffic.log`, `<id>-in/out.json` roh + eingerückt,
  Request-/Upstream-Header). Kommandos: `start`, `stop`, `status`,
  `tail`, `show <n>`. Lauscht nur auf `127.0.0.1`, Port 8080 wird
  abgelehnt, bei totalem Upstream antwortet er mit **HTTP 502**.
- **`test/test_proxy.sh`** (26 Prüfungen) als 7. Läufer in
  `run_all.sh` → **7 Läufer**; `bash -n` und shellcheck
  laufen in CI jetzt auch über `tools/*.sh`.

- **11 Tools statt 8** (Schritt 1 + 2 der Wiki-Einbindung):
  - `append_file` — append-only schreiben, unverzichtbar für
    `wiki/log.md` (dort wäre `write_file` Datenverlust).
  - `search` — Volltextsuche als `pfad:zeile:text`, standard
    **wörtlich** (`grep -F`), `regex=true` für reguläre Ausdrücke,
    `glob` als Datei-Filter, 200-Treffer-Kappe.
  - `list_files` mit `pattern` (Glob) und `recursive` — ohne beide
    Argumente weiterhin `ls -la`.
  - `todo(action, text?, index?)` — persistenter Plan unter
    `~/.lex/plans/`, `done` ist idempotent, Index = Anzeige-Position;
    Slash-Befehl `/plan`.
  - Config `LEX_WIKI_DIR` (Default `~/Ai/wiki`) + Wiki-Konventionen
    und Planungs-Disziplin im System-Prompt, `wiki` in `/status`.
- **Oberfläche (Schritt 6):** CLI mit TUI-Gefühl, alles stderr-only bei
  TTY bzw. `LEX_TRACE=1` (Pipes/Tests bleiben roh):
  - `⏳ denke …`-Spinner während der Generierung (startet erst nach
    250 ms, damit schnelle Antworten nicht flackern)
  - `↳ tool` + eingerückte, auf 8 Zeilen/600 Zeichen gekappte Werkzeug-
    Rückgabe (vorher unsichtbar)
  - `⚙ denken:`-Block für `reasoning_content` (`LEX_SHOW_REASONING=0`
    aus, `LEX_REASONING_MAX` kürzt, Standard 4000)
  - Trennlinie nach jeder Antwort
  - Eingabe mit **Readline**: Pfeiltasten, Ctrl-A/E/W/U, **Tab =
    Pfadvervollständigung**, History in `~/.lex/history` (500 Einträge)
    — reines Bash (`read -e` + `set -o emacs` + `bind`), ohne gum/dialog
- **`fetch` (Schritt 4):** lädt eine Seite und speichert sie als Rohquelle
  unter `<wiki>/raw/<topic>/YYYY-MM-DD-slug.md` mit Metadatenkopf
  (`> Source` / `> Collected` / `> Published`), Slugs kollisionsfrei (`-2`,
  `-3`, …). HTML wird per awk in Klartext überführt (Überschriften, Listen,
  Link-Ziele als `Text (URL)`, Entities zurückübersetzt, Navigation/Scripts
  raus), Nicht-HTML bleibt unverändert. Ohne neue Abhängigkeit.
- **Rendering (Schritt 3):** `⚙`-Tool-Trace und `⏱`-HUD auf stderr
  (nur bei TTY bzw. `LEX_TRACE=1`) und Markdown-Licht für die finale
  Antwort (Überschriften, `**fett**`, `` `code` ``, `[[wikilinks]]`,
  Zitate) — ohne TTY bleibt die Ausgabe unverändert roh.

- **Persönlichkeit (Schritt 7):** Block oben im System-Prompt — immer
  Deutsch, kurz & wirksam, **nicht raten** (bei Befehlen
  `<Befehl> --help`, bei Fakten `search`/`web_search`/`web_fetch`, bei
  Bibliotheken `context7`), Fehler als Material (`wiki/log.md`,
  `wiki/errors/`) und das Wiki als Gedächtnis über Sitzungen hinweg.
- **Rendering wie opencode (Schritt 8):** Warnungs-Zitate orange,
  `❌`/`Fehler:` rot, `✓`/`OK` grün, Links cyan+unterstrichen mit
  dimmer URL, Listenmarker und `---` dim — dazu **echte Pipe-Tabellen**
  (Kopf cyan/fett, Raster dim, rechtsbündig bei `:---`, Kürzung auf 40
  Zeichen, UTF-8-sicher), weiterhin nur bei TTY bzw. `force`.
- **MCP (Schritt 9):** stdio-JSON-RPC-Client (`initialize` →
  `notifications/initialized` → `tools/call`, Antwort nach `id`
  gefiltert), Server aus `~/.lex/mcp.json` (Defaults: **defuddle**,
  **context7**), `LEX_MCP=0` schaltet ab, `LEX_MCP_TIMEOUT` begrenzt.
  **+2 Tools**: `web_fetch(url, max_length?)` (Crawler-Auszug ohne
  Ablage) und `context7(query, library?)` (`resolve-library-id` →
  `query-docs`) → **15 Tools**; `test/fake_mcp.sh` deckt die Fehlerpfade.
- **Websuche (Schritt 10):** `web_search(query)` über
  `html.duckduckgo.com` **ohne API-Key** — Titel, URL und Ausschnitt,
  `uddg=`-Redirects und HTML-Entities aufgelöst, `LEX_SEARCH_URL`
  schaltbar (die Tests laufen offline dagegen).
- **Browser-`wait`-Aktion (Live-Test 2026-09-29):** `browser(action=wait,
  text=Sekunden)` → playwright `browser_wait_for`. Seiten laden nach
  `back`/`click`/`Enter` asynchron und vergeben dabei neue Refs — vor
  jeder ref-basierten Aktion hilft nur ein frisches `snapshot`
  (Prompt-Regel) bzw. `wait`, bis die Seite stillsteht. Dazu
  Stub-`browser_wait_for` in `test/fake_mcp.sh` und zwei Nadeln.

- **Drei ENV-/Config-Knobs (Schritt 53–56):** `LEX_API_RETRIES` (bzw.
  `api_retries` in `settings.json`) — Wiederholungen bei HTTP 429/5xx
  und curl-Fehlern, Default 2, Clamp ≤10; `LEX_LOOP_GUARD=off` —
  schaltet das Fail-Gedächtnis in `run_turn` ab;
  `LEX_REASONING_STORE_MAX` — Obergrenze für das in der Session
  gespeicherte `reasoning` (Default 20000 Zeichen).

### Geändert

- **Palette / Lesbarkeit (Schritt 14):** alle ANSI-Sequenzen laufen ab
  jetzt über die zentrale `_palette_init()`-Palette — **`NO_COLOR`**
  und `TERM=dumb` schalten Farben komplett ab (Prompt und
  `render_markdown` sind auch ohne TTY farblos). H1 ist **fett +
  unterstrichen** statt „weiß" (weiß war auf hellem Terminal
  unsichtbar), H3 ist cyan statt fett, der `⚙ denken:`-Inhalt ist
  **grau** statt kursiv (italic wird nicht überall unterstützt).
  Reihenfolge bleibt: HUD + Trennlinie vor der Antwort, die Antwort
  steht als Letztes.
- **Deny-Liste:** `sudo` ist **raus** (war vorher pauschal verboten),
  `su` bleibt hart verboten. Dadurch kann der Agent erstmals
  Root-Aufgaben erledigen, statt sie nur abzulehnen — User-Auftrag
  2026-09-28 („eine Aufforderung, wo ich es einfach eingeben kann").
  Testzahl **330 → 340**, `lex` 2018 → **2101 Zeilen**.
- **Lesbarkeit (Schritt 13):** Denken, Werkzeuge und Antwort sind klar
  getrennt — `⚙ denken:` mit dim-magenta Header und **kursiv eingerücktem**
  Inhalt, Werkzeugname **fett cyan** (Argumente grau), `↳` cyan-dim,
  HUD + Trennlinie **vor** der Antwort (sie steht als Letztes auf dem
  Bildschirm), H1 fett weiß statt cyan. Neun Prüfungen dazu (+8 → **330**).
- **`todo`-Plan session-unabhängig:** `_todo_file()` liefert jetzt
  `~/.lex/plans/plan.md` statt `plans/<session-id>.md` — der Plan läuft
  wie die Wiki und `mem_*` über Sitzungen hinweg (zwei Kind-Läufe mit
  verschiedenen Session-IDs als Test, +5 → **322 Prüfungen**).
- **`lex` direkt aufrufbar:** Symlink `~/.local/bin/lex → ~/Ai/lex/lex`,
  damit `lex` im Terminal ohne Alias startet.
- **15 statt 12 Tools** (Schritt 9/10): Schema-Liste (`_build_tools`),
  `dispatch_tool`, System-Prompt und Doku (README/CLAUDE/LEX.md)
  aktualisiert; Testzahl **245 → 317**.
- **`reasoning_budget` = 4096** (`lex:252`, vorher 1024) — synchron zu
  `ai.sh --reasoning-budget 4096`; über einen Live-Request über den
  Proxy verifiziert (`reasoning_budget_tokens: 4096`, `max_tokens: 8192`).
- **Anti-Zweifel-Prompt (Schritt 15, 2026-09-29):** drei neue Regeln im
  System-Prompt — **entschlossen entscheiden** (keine Selbstzweifel-
  Formulierungen über selbst geprüftes), **Verifikation über Tools**
  (`bash -n`, `./test/run_all.sh`, `search`, Logs) statt Selbstintrospektion,
  **keine Zweifelschleifen** (kein „bist du sicher?", nach Fehler →
  Ursache/Fix/weiter). Recherche-basiert (arxiv 2603.03330: „bist du
  sicher?" flippt korrekte Antworten 72 vs. 6, arxiv 2506.21285:
  Selbstkritik bei 27B wertlos, llama.cpp #12339, Reddit-PSA „Tools an →
  Overthinking weg"); drei Prüfungen dazu (+3 → **389**), `lex`
  2330 → **2333 Zeilen**. Parallel (nicht in diesem Repo): gleiche
  Grundsätze in zoocode `custom_modes.yaml`, `ai.sh` ergänzt
  `--reasoning-budget-message` (`--reasoning-preserve` bleibt, Budget 4096).
- **Workflow-Fixes (Schritt 16, Live-Test 2026-09-29):**
  - **Leere/abgeschnittene Antworten:** `run_turn` nudged bei
    `finish_reason=length` **und** bei leerem Content maximal 2× und sendet
    dafür `reasoning_budget_tokens: 0` (`_rb_override` in `call_api`) — vorher
    fraß Reasoning im Nudge-Turn erneut alle Tokens und die Antwort blieb
    leer; nach 2 Nudges wird ein vorhandener Teiltext gerendert (live gemessen:
    195–214 Bytes, die sonst verlorengehen), erst bei leerem Content gibt es
    Abbruch (rc 1) statt Endlosdrehen bis `max_turns`. Zusätzlich rendert
    auch der Max-Turns-Abbruch den vorhandenen Teiltext (Nachtest2: 578 Bytes
    hingen darunter), statt ihn zu verwerfen.
  - **Spinner nur bei TTY:** `_spin_start()` kehrt ohne `[[ -t 2 ]]` zurück —
    die `\r`-Repaints landeten sonst in Pipes und Log-Dateien (auch mit
    `LEX_TRACE=1`); Test läuft dafür unter einer `script`-PTY.
  - **Defaults:** `temperature 0.1 → 0.7`, `max_turns 50 → 100`
    (`LEX_TEMPERATURE`/`LEX_MAX_TURNS`/`settings.json` überlagern weiter).
- **Wiki-Lernen (Schritt 17):**
  - `setup_messages` bettet den Wiki-Stand ein (index.md + die jüngsten 40
    Zeilen aus wiki/log.md) — das Karpathy-Wiki ist damit immer im Kontext,
    unabhängig vom Tool-Verhalten des Modells.
  - Pflicht-Regel im System-Prompt: erst Wiki + `mem_search` gelesen, dann erst
    „weiß ich nicht" sagen; neue Erkenntnisse werden gesammelt (Zeile an
    log.md, neue Artefakte als Artikel mit index.md-Zeile).
  - `search` ohne `path` sucht im Wiki statt im aktuellen Verzeichnis
    (Prompt- und Schema-Beschreibung entsprechend).
  - Tests +9 → **403**, `lex` 2382 → **2394 Zeilen**.
  - **E2BIG-Kontextschutz (17b, Live-Verify-Fund):** `tool_read_file` kappt wie
    `tool_bash` auf `tool_max_output` (135-KB-log.md überschritt das 128-KB-
    Argumentlimit von jq, ließ `msg` leer und räumte den gesamten Kontext);
    `append_message` kürzt >100000 Bytes und fängt jq-Fehler ab,
    `append_message_json` überschreibt `$_messages` nie mit leerem Ergebnis.
    Tests +3 → **406**, `lex` **2418 Zeilen**.
  - Live-Belege: sudo-Gate 1A (eine Aufforderung, Passwort im sudo-Prompt,
    Weiterlauf), Anti-Zweifel-Verhalten bestätigt; Tests **389 → 394**,
    `lex` 2333 → **2382 Zeilen**.

- **MCP-Session überlebt Calls (Live-Test 2026-09-29):** jede
  Tool-Iteration lief vorher in Command-Substitution → eigene Subshell →
  die Coproc-Session starb nach jedem Call (navigate→snapshot landete auf
  `about:blank`, Refs pro Call anders). Jetzt: `_mcp_out_var()` (Tempdatei
  statt `$(…)`), `run_turn` schreibt `dispatch_tool`-Output per
  Redirection in eine Tempdatei, Keep-Alive in `_mcp_call` (Reuse-Key
  `server|argv`, `kill -0`, Neustart bei Config-Wechsel, Server-Tod,
  JSON-RPC-Fehler oder Timeout).
- **Playwright-Config:** Default gepinnt auf `@playwright/mcp@0.0.83` mit
  `--cdp-endpoint http://127.0.0.1:9222`; `tool_browser` sorgt bei
  cdp-Configs mit `_ensure_browser()` für den Chrome-Dienst (PID-Datei
  `$LEX_HOME/browser.pid`). click/type senden `target` (= Ref-ID), wie es
  das Schema ≥0.0.83 verlangt.

### Geändert/Behoben 2026-10-06 — sudo-Passwort zurück, Postgres-Libs, Zählung deterministisch

- **sudo-Passwort wieder sichtbar (User-Auftrag „mach es rückgängig")**: der
  2026-10-03 angelegte systemweite Eintrag `/etc/sudoers.d/<datei>`
  (`<user> ALL=(ALL) NOPASSWD:ALL`) wurde entfernt — `sudo -n true` scheitert
  wieder (`rc=1`). Damit greift der lex-interne Weg genau dann, wenn sudo
  gebraucht wird: `_sudo_gate` → `_tty_preview` → „sudo-Passwort jetzt
  eingeben:" → `sudo -v < /dev/tty` (Passwort läuft direkt an sudo, nie durch
  lex). Ohne controlling TTY unverändert: saubere Verweigerung.
- **user-space Postgres wieder startbar**: apt entfernte am 05.10. `libxml2
  2.9.14` und `libicu74`; die Noble-Debs `libxml2_2.9.14+dfsg-1.3ubuntu3.9`
  und `libicu74_74.2-1ubuntu3.1` liegen jetzt unter `~/.lex/pg/deb`
  (`dpkg-deb -x`) — `ai.sh pg start` + `psql`-Abfrage wieder grün.
- **Tests hängen nicht mehr an der sudoers der Maschine**: `test_features`
  (DE+EN) simuliert den sudo-Ticket-Zustand (`_sudo_ticket_valid`-Stub:
  Zweig „ohne Ticket" → `1`, Zweig „Sitzungs-Freigabe" → `0`). Vorher änderte
  der Revert des NOPASSWD-Eintrags still, welcher Zweig läuft.
- **Tests +3 → 794** (`test_features` 525 → 528; 807 PASS-Zeilen abzüglich
  13 Läufer-Marken), `run_all.sh` **13/13** DE und EN, seriell; `bash -n` +
  shellcheck warning-sauber. `ai.sh` (außerhalb des Repos) bekam `pg`- und
  `docker`-Subcommands inkl. `start`/`stop`-Integration.

### Behoben 2026-10-06 — Fix-Paket Schritt 53–56 (Tool-Hang, HTTP 500, Redaction, Fail-Gedächtnis)

- **Tool-Läufe hängen nicht mehr in der Pipe**: `_run_limited` schreibt
  die Ausgabe der Kindkette jetzt in eine Tempdatei (`$_rl_out`) statt
  in eine Pipe — der Leser kann nicht mehr an einem offenen Schreibende
  hängen bleiben (Bug-Basis: bug-bash msg00059, opencode #32504, codey
  #65). Dazu `_kill_tree()`: BFS sammelt die Kindkette bis zur Wurzel
  und tötet Blatt→Wurzel (TERM, nach 3 s KILL), Watchdog `secs+10`
  legt einen eigenen Timer über den Lauf, Zustand in `$_rl_pid` /
  `$_rl_hung`, der rc von `_run_limited` ist der Funktionsstatus.
  `tool_bash` hängt daran. Live: `sleep 20` bei `LEX_TOOL_TIMEOUT=5`
  → Tool-Ergebnis `Exit-Code: 124`, der Turn läuft weiter.
- **HTTP-Fehler werden wiederholt (P3/P6)**: `call_api` retryt
  429/5xx und curl-Netzwerkfehler max. 2× (OpenAI-SDK-Norm),
  `_retry_delay` rechnet 0.8/1.6/3.2 s mit Deckel 8 s und Jitter
  ±25 %; neue Config `api_retries` / `LEX_API_RETRIES` (Default 2,
  Clamp ≤10, Tier 1/2/4). Fehlermeldungen nennen HTTP-Code,
  Body-Snippet (400 B), Byte-Anzahl, Versuchszahl und — bei
  `parse_error`/`invalid string` — den Hinweis auf Spezialzeichen oder
  Größe in Tool-Argumenten (llama.cpp #21660/#22072).
- **Secrets verlassen lex nicht mehr (P4)**: `_redact()`/`_redact_var()`
  maskieren eigenen API-Key, `password`/`secret`/`token`/`apikey`/
  `auth`-Paare, `Bearer`/`Basic`, Token-Präfixe (`sk-`, `ghp-`, `xox…`)
  und URL-Credentials — angewendet in `log()`, `session_write()`, der
  Anzeige (`_trace_result`, `_trace_reasoning`, `_md_render`) und den
  Wiki-Schreibpfaden. Bewusst **nicht** im Modellkontext und nicht an
  Config-/Script-Zielen. Die Wertgruppe bleibt JSON-sicher (escaptes
  Anführungszeichenpaar als Ganzes, offene Werte ohne `"`/`\`).
- **Fail-Gedächtnis gegen Tool-Loops (P5)**: `run_turn` merkt sich pro
  Tool-Call die Signatur `cksum(name|args|result[0..200])`; drei
  identische Läufe hintereinander → weicher Nudge mit Antwort-Pflicht,
  danach erneut identisch → harter Abbruch (`rc 1`). Ergebnis-Bytes
  sind Teil der Signatur, damit legitimes Polling (wachsende Datei,
  kippender Status) den Zähler zurücksetzt. Auswahl per
  `LEX_LOOP_GUARD=off`, Session-Records `{type:loop_guard}`.
- **Kontext-Warnung ab 85 % + Pinning (P7)**: `_compact_run` meldet
  `⚠️ Kontext zu X % voll …` **vor** dem Compaction-Gate, unabhängig
  von `LEX_COMPACT` (Re-Arm über `_compact_warned`, einmal pro
  „fast voll"-Periode); `_compact_prompt` hängt einen Pinning-Block an
  (Ziel, laufende Pläne, offene Entscheidungen, Pfade wandern immer in
  die neue Zusammenfassung).
- **Reasoning-Kappe (P8)**: `append_message_json` begrenzt das
  gespeicherte `reasoning` auf `LEX_REASONING_STORE_MAX` (Default
  20000 Zeichen) und schreibt den Rest als Hinweis in die Zeile.
- **Live-Test 2026-10-06** (isoliertes `LEX_HOME`, echte LLM-Turns):
  oneshot, Tool-Timeout, Redaction, Fail-Gedächtnis, 85-%-Warnung und
  Reasoning-Kappe alle live bestätigt. **Fund dabei**: der erste
  Redaktor fraß das `\` vor dem schließenden `"` und machte eine
  session.jsonl-Zeile ungültig → Wertgruppe nachgebessert
  (`wiki/errors/2026-10-06-redaction-brach-session-jsonl.md`); danach
  ist die Session zu 100 % parsebar und das Secret nirgends in
  `LEX_HOME` zu finden.
- **Tests +41 → 791** (13 Läufer, DE+EN grün): `test_features` +38
  (Fix-Paket inkl. JSON-Sicherheit), `test_loop` +9 (Fail-Gedächtnis
  weich/hart/off), `test_http` +6 (Retry mit 3×500, mit/ohne Budget),
  `test_sse` +1 (drei Versuche). Kein Commit/Push (Auftrag fehlt).

### Behoben 2026-10-05 — sudo fragte y/N pro Kommando (Schritt 52)

- **Sitzungs-Freigabe statt y/N pro Befehl (neuer Default)**: das
  sudo-Gate fragte bei gültigem Ticket pro sudo-Kommando eine y/N-
  Freigabe (58 % der Laufzeit im Audit-Lauf, 32 sudo-Calls). Neu:
  Prozess-State `_sudo_grant` (`""` unbefragt → `"1"` erteilt →
  `"0"` abgelehnt) + `_sudo_grant_request()` — beim ersten sudo der
  Sitzung EINE Frage `sudo für diese ganze Sitzung freigeben? (y/N): `
  (Titel + gekürztes Kommando wie der Freigabe-Prompt, Frage ohne
  newline, Strg+C-abbrechbar); Ja = die Sitzung läuft ohne weitere
  Rückfragen, Nein = merkt sich `"0"` und fragt weiter y/N pro Befehl
  (alter Weg). `/status` zeigt `grant: offen|erteilt|abgelehnt`,
  `/autosudo on` und `LEX_SUDO_APPROVE=0` überspringen auch die
  Sitzungsfrage; ohne controlling TTY ändert sich nichts (Frage
  scheitert → Ablehnung → Altverhalten, deterministisch). Englisch
  `allow sudo for this entire session? (y/N): `. Nebenbei im
  `/help`-Text der alte Irrtum „LEX_SUDO_APPROVE=0 (Start-Wert)"
  bereinigt — der Default ist 1. **Tests +12 → 750** (13 Läufer,
  DE+EN grün): 8 Gate-/Anker-Checks in `test_features` + 4 PTY-E2E-
  Checks in `test_input` (Fake-`sudo` im PATH protokolliert die Calls,
  genau 1× Sitzungsfrage im Transkript).

### Behoben 2026-10-05 — Strg+C beendete lex + Session-Rechte umask-anfällig (Schritt 51)

- **Strg+C beendete den ganzen lex-Prozess**: es gab keinen
  `trap … INT` — im Turn wie am Prompt (Live-Fund: Session `125104`, der
  User stoppte den Audit-Lauf und lex war komplett tot). Neu:
  `_sigint()`-Trap (lex:4983) — im Turn nur `_turn_aborted=1`,
  `run_turn` bricht an den Abbruchstellen ab (Loop-Top / nach
  `call_api` / Tool-Loop), alle offenen `tool_call`-IDs bekommen ihre
  protokollkonforme Markierungs-Antwort (`_abort_turn_tools`), eine
  hängende user-Message wird über `_abort_turn_note` beantwortet; am
  Prompt: 1. Strg+C = Zeile weg, 2. Druck ≤2 s = `Bye!`, Strg+D bleibt
  EOF (Unterscheidung über `rc>128 || _int_seen`).
- **`timeout` überlebte tty-Strg+C**: die Kindkette steckt in eigener
  Process Group — der Turn lief bis `tool_timeout` weiter (gemessen
  20 s statt 2 s). Fix: `timeout --foreground` in `_run_limited`
  (rc=124-Timer weiter geprüft, `_have_tf`-Cache, Fallback ohne
  Support).
- **Session-Rechte umask-anfällig**: neue Sessions entstanden 775/664
  (Fund: Session 125104). Neu: `session_init`/`install_lex` —
  `sessions/` + Ordner `700`, `session.jsonl` vor der ersten Zeile
  `: >` + `600`; bestehende Sessions nachgezogen.
- **Diagnose-Mit (User-Frage „warum kam keine sudo-Aufforderung?")**:
  NOPASSWD:ALL aktiv → sudo fragt nie ein Passwort, nur y/N ist die
  Frage; alle 11 Langblöcke des Laufs waren sudo-Freigaben
  (~2 h 35 m ≈ 58 % der Session, davon 2 h Avahi-Stop); echte Blocker
  waren Avahi/Netz-Proxy-DNS/Client-Permissions, nicht sudo.
  **Tests +8 → 738** (13 Läufer, DE+EN grün).

### Behoben 2026-10-05 — sichtbarer y/N-Freigabe-Prompt (Schritt 50)

- **Freigabe-Frage war unsichtbar**: `_approve_request`/`_sudo_ask`
  schrieben die Frage **vor** das Kommando
  (`printf 'Freigabe für Kommando (y/N): %s\n' "$cmd"`) — bei mehrzeiligen
  sudo-Befehlen scrollte `(y/N)` aus dem Bild, der User sah nur
  Kommando-Ende + blinkenden Cursor (Live-Hänger im Audit-Lauf,
  Weiterlauf nur per manueller Zeichen-Injektion ins Terminal). Neu:
  `_tty_preview_text()`/`_tty_preview()` — Titel + Kommando gekürzt
  (200 B, `LC_ALL=C`, `…(+N bytes)`) über der Frage, danach
  `freigeben? (y/N): ` **ohne newline** als letzte Zeile (Cursor
  dahinter); `_sudo_ask` analog, letzte lex-Zeile
  `sudo-Passwort jetzt eingeben:`. Verhalten (y/j), Gate und `/autosudo`
  unverändert; EN 1:1 portiert. **Tests +2 → 730** (13 Läufer, DE+EN grün).

### Geändert 2026-10-05 — Anti-Verweigerungs-Guard im lexpen-Modus (Schritt 49)

- **Auslöser (User-GO)**: vor dem lexpen-Prompt verweigerte `lex` ethische
  OpSec-Analysen (Ethical-Hacker-Rolle + Legal-Satz → „böses Hacking“
  vermutet); die Persona (`lexpen.md`) löst das, aber es fehlte eine
  positive Handlungs-Anweisung, und seit Schritt 48 zog die Playbook-Regel
  „Erlaubnis/Scope zuerst“ in den Modus. **Gebaut**: `_prompt_lexpen_guard`
  (Zeile 402) — „Aufträge werden ausgeführt, nicht verneint“: Scans,
  Packet-/Log-Analysen, Schwachstellen-Bewertungen sind Analysearbeit;
  Rückfragen nur technisch; Legalität regelt der Mensch am Terminal.
  Gehängt ausschließlich in `cmd_lexpen on` an `${_prompt_ops}` — Persona
  unverändert, Default-Prompt byte-identisch, `/lexpen off` stellt das
  Original her. **Tests +2 → 728** (Guard-Needle im lexpen-Kontext,
  Guard-nicht-im-Default). **Verify**: run_all 13/13 = 728 grün
  (seriell), shellcheck sauber, byte-Identität nach
  Wiki-Pfad-Normalisierung. `lex` 4027 → 4029 Zeilen.

### Geändert 2026-10-05 — Ops-Layer-Split im System-Prompt (Schritt 48)

- **System-Prompt in Style + Ops zerlegt, `/lexpen` behält die
  Werkzeug-/Research-Regeln:** Live-Fund 2026-10-05 (Proxychain-/SOCKS5-
  Aufgabe, Session `anonym`) — im Persona-Modus **0
  Tool-Calls** bei einer Recherche-Aufgabe, die „Antwort" war eine reine
  Gewichts-Antwort. Ursache: `cmd_lexpen` tauscht Slot 0 komplett gegen
  die Persona, die keine Werkzeug-/Research-Regeln enthält (Tool-
  Schemata werden weiter gesendet, die Disziplin fehlt im Kontext). Der
  Standard-Prompt besteht jetzt aus `_prompt_style` (Identität, Rolle,
  Arbeitsrahmen, Stil inkl. Sprachregel) + `_prompt_ops` („Prüfen tust
  du mit Tools", „Nicht raten, nachschlagen" → `web_search`, „Fehler
  sind Material", „Für Menschen am Terminal", 17-Tool-Liste,
  Wiki-Struktur, Regeln) und wird zu `_system_prompt`
  zusammengesetzt — **byte-identisch** zum vorherigen Prompt (sha256
  `057c6842…`, 13884 Bytes). `cmd_lexpen on` hängt `${_prompt_ops}` an
  die Persona (`"$content"$'\n'"${_prompt_ops}"`), `/lexpen off` bleibt wie
  bisher; der Style-Marker `IMMER auf Deutsch` bleibt im Modus draußen
  (die Persona führt ihre eigene SPRACHE-Direktive). **Tests +14 →
  726** (Default-Identität, Style-/Ops-Needles einzeln, Ops-Needles im
  lexpen-Kontext, Marker-Weg/Marker-zurück); Testfund: der
  Prompt-Range-`sed`-Startmuster `^_system_prompt="` in
  `test_features.sh` brach → `^_prompt_style="`. **Live gegen den
  echten Server:** `web_search` → `web_fetch` → `fetch` (raw/) →
  `append_file` (Log) = 4 Tool-Calls, 5 Turns, 60 s, belegte Antwort
  mit Primärquelle. Nachtrag: `$(cat)` frisst trailing newlines → explizites `$'\n'` zwischen Persona und Ops (Test +1 → 726).

### Behoben 2026-10-03 — REPL-Prompt nach leerem Enter + Spinner-Hardening (Schritt 47)

- **REPL-Prompt verschwand (User-Report „nach Aufgaben nur blinkender
  Cursor"):** Bei leerer Eingabe sprang `[[ -z "$input" ]] && continue`
  über `_prompt` — readline löscht beim Enter die Eingabezeile, der
  Prompt blieb weg (Eingabe funktionierte weiter). Jetzt
  `{ _spin_stop; _prompt; continue; }` plus `_spin_stop` hart vor jedem
  Schleifenende-`_prompt`.
- **Spinner-Hardening:** die Repaint-Loop lief `while :;` endlos — ein
  überlebendes Kind hätte die Prompt-Zeile weiter gefressen. Jetzt
  Flag-Gate `while [[ -f "$_spin_flag" ]]` (endet ≤0,12 s nach
  `_spin_stop`), Lösch-Clear läuft damit immer vor dem Prompt.
- **Tests +3 → 712** (699 Einzelf + 13 Läufer): PTY-Test (2× Enter →
  ≥3 `lex>`) + zwei statische Anker in `test_input.sh`.
- **Nebenbefund behoben:** `LEX.md` war im Commit 2bdbd7d in sich
  verdoppelt (§0–§7 und §9–§13 je zweimal) → auf Basis von 756e10b mit
  Einträgen 45/46 und den aktuellen Zahlen neu aufgesetzt (811 Zeilen).

### Behoben

- **15 Review-Befunde (Schritt 14, P1/P2/P3):**
  - **[P1]** rm-Deny-Liste umging `rm -rf -- /`, `rm -Rf /`,
    `rm --no-preserve-root -rf /`, `sudo rm -rf /`, `xargs rm -rf /` —
    jetzt segmentweise Prüfung der rm-Ziel-Tokens.
  - **[P1]** `curl … | sh | cat` und `curl … && sh x.sh` liefen durch,
    weil nur das **letzte** Segment geprüft wurde — jetzt alle Segmente.
  - **[P1]** `safe_path` ließ nackte Wurzeln (`/etc`, `/usr`, `/var`,
    `/proc`) und **Symlink-Ziele** zu — beides wird jetzt gesperrt
    (inkl. `cd -P` im Fallback).
  - **[P2]** `su postgres -c …` wurde verfehlt — `su` gilt jetzt als
    Kommando-Wort (false positives wie `grep su -` bleiben erlaubt).
  - **[P2]** Ungültige/leere API-Antworten reduzierten `_messages` auf
    die Fehlermeldung (**Modellkontext weg**) — jetzt Guard mit rc 1.
  - **[P2]** MCP-Server, der beim Start stirbt, löste `set -u`-Absturz
    bzw. rc 141 ohne Meldung aus — `_mcp_send()` + FD-Prüfung melden
    jetzt „Server ist nicht startbar".
  - **[P2]** Nicht-numerische Config-Werte (`LEX_MAX_TURNS=abc`)
    brachen `(( ))` ab — `_int_or()`/`_float_or()` validieren.
  - **[P2]** `edit_file` schrieb per `mktemp` nach `/tmp` (nicht
    atomar, Modus 600) — Tempdatei jetzt im Zielverzeichnis, Modus
    wird übernommen (auch `todo done`).
  - **[P2]** `_mcp_config` ohne `LEX_HOME` und `_load_settings` ohne
    `max_turns`/`tool_timeout`/`tool_max_output`/`log_dir` korrigiert.
  - **[P3]** `dispatch_tool` verlangt JSON-Objekte als Argumente,
    Prompt nur noch bei TTY, `ss`-Prüfung ohne Pipe (rc 141),
    Spinner-`trap` beim Exit, Testpfad `/tmp/safe_err` → `$TMP`.
  - Testzahl **340 → 386**, `lex` 2101 → **2330 Zeilen**.
- **Backticks im System-Prompt** wären als **Command-Substitution**
  ausgeführt worden (`bash`, `context7(…)` …) — alle 32 Vorkommen im
  Prompt-Block escaped (`\``); ein Test prüft Quelltext und
  ausgewerteten Prompt.
- **MCP-Timeout wurde nie erkannt:** `if ! …; then rc=$?` liefert immer
  0 → Zeitüberschreitungen meldeten „Verbindung abgebrochen". Jetzt
  `rc=$?` direkt nach der Zuweisung; `read`-rc > 128 gilt als Timeout,
  alles andere als Verbindungsabbruch.
- **`&amp;` blieb in Suchtreffern stehen:** `gsub(/&amp;/, "&", …)` —
  `&` bedeutet im Ersetzungstext „ganzer Treffer" → `"\\&"`.
- **`_ddg_parse` erhielt die Suchanfrage statt des HTML** als stdin
  (`<<< "$q"` im Parser) → jedes Ergebnis „Keine Treffer".
- **Doppelte HTTP-Statuszeile** im Proxy (`HTTP/1.1 HTTP/1.1 200 OK`)
  → `curl: Unsupported HTTP/1 subversion`; jetzt gewinnt der letzte
  Status aus `curl -D` (der `100 Continue` des Expect-Handshakes).
- **Content-Length 1 Byte zu groß** (Body per `$(cat …)`, die
  Kommando-Setzung schluckte das abschließende `\n`) → `curl: rc 18`.
- **Race beim Protokollieren:** `traffic.log` wurde erst nach der
  Antwort geschrieben → jetzt davor.
- **`status` zeigte immer den Default-Upstream `8080`** statt der
  gespeicherten URL; der Proxy band zudem auf `0.0.0.0` statt
  `127.0.0.1`.

- **E2BIG im curl-Pfad (Live-Test 2026-09-29):** `call_api` übergab den
  Body als exec-Argument — ab ~128 KiB meldete der Kernel „Argumentliste
  zu lang" (Mehrfach-Turns schoben die Historie von 34 KB auf 140 KB).
  Jetzt Tempdatei + `curl -d @file`; Nadel mit 140.000-B-Body gegen den
  Fake-Server. Tests **+13 → 485**, `lex` → **2683 Zeilen**.
- **Ref-Verfall nach asynchronen Seiten-Events (Live-Test):** playwright
  vergibt nach `fill` (Autocomplete) und `back` (Reload) neue Refs — der
  alte Ref wurde mit „Ref not found" verneint. Kein lex-Bug im engeren
  Sinn, aber abgefangen: `wait`-Aktion, Ref-Regel im System-Prompt
  („vor ref-Aktionen immer frisches snapshot") und die sessionstabile
  Haltung aus dem Keep-Alive-Fix.
- **DDG-Anti-Bot (extern, nur gemeldet):** `web_search` bekam 0 Treffer,
  weil DuckDuckGo eine Challenge-Seite liefert — nicht lex-seitig gefixt
  (offener Punkt: anderer Provider/eigene UA).

### Geändert

- **Limits für große Aufgaben erhöht (Gesamtprüfung 2026-09-29):**
  Defaults `max_tokens` 8192 → **16384**, `reasoning_budget` 4096 →
  **8192**, `max_turns` 100 → **200**, `tool_timeout` 60 → **300 s**;
  Nudge-Grenze als eigener Default 4 (`LEX_MAX_NUDGES`) statt versteckter
  Zahl; API-Timeout `LEX_API_TIMEOUT` (Default 1800 s) statt festem
  `curl --max-time 900`; `--status` zeigt `nudges`. Ziel: keine Abbrüche
  mehr durch `finish=length`, Nudge-Limits oder zu kurze Timeouts bei
  langen Generierungen.

### Behobert

- **jq-E2BIG im Nachrichten-Pfad:** `call_api` liefert den Kontext über
  `--slurpfile`/Tempdatei statt als exec-Argument (Linux-Grenze
  131 071 B → leerer Body, „❌ API-Fehler", mit 193 KB reproduziert);
  `append_tool_message`, `append_message` und `setup_messages` kapieren
  ihre jq-Argumente jetzt bei 100 000 B (Protokollbruch/Startabbruch
  verhindert). `dispatch_tool`-Ergebnisse laufen durch die zentrale
  Tool-Kappe (`LEX_TOOL_MAX_OUTPUT`).
- **Harte Deny-Liste geschlossen:** `rm -rf ${HOME}` / `"$HOME"/.` /
  `/home/…/.` (Home-Wurzel in literal **und** expandierter Form;
  Subtrees wie `~/projekt` bleiben erlaubt) und Download-Umgehungen
  `curl … | sudo sh`, `| env sh`, `| nohup sh`, `bash <(curl …)`,
  `source <(curl …)`, `eval "$(curl …)"`, `curl … & sh f.sh`
  (Wrapper-Skip, Direktausführung/Prozess-Substitution, `&` als
  Segment-Trenner).
- **Code-Review-Fixes (P2/P3):** `tool_web_fetch`/`tool_context7` ohne
  Subshell (`_mcp_out_var` — Coproc-Session/NEXTID stabil), `mem_add`
  verliert keine Einträge in derselben Sekunde (Kollisionsschleife),
  `edit_file` behält alle Trailing-Newlines, `write_file` ist atomar
  (Tempdatei + `mv`) und vergibt den korrekten Modus, `--approve`
  funktioniert in beliebiger Argumentposition, `safe_path` expandiert
  `~/…`, MCP-Errdatei pro Server (`mcp.<server>.err`), `agent_loop`
  ohne TTY wertet wie `--oneshot` aus (Pipe schluckt Eingabe nicht
  mehr), `_ensure_browser` prüft die PID-Datei (kein Doppelstart bei
  „Profile in use"), `source lex` in 4 Testläufern mit Fehler-Guard.

### Geändert

- **Streaming-Pfad in `call_api` (Schritt 36):** Antwortauswertung läuft
  jetzt über einen einzigen jq-Lauf (`_sse_to_response`) über die
  Streamdatei — JSON-Passthrough, wenn der Body mit `{` beginnt (klassische
  JSON-Antworten bleiben möglich), sonst `reduce` über die SSE-Zeilen:
  Content-Deltas werden verkettet, `tool_calls` nach `index` fusioniert
  (Name/ID aus dem ersten Delta, Argumente kumuliert), `usage` kommt aus
  dem Stream. Übertrag läuft als `curl -o <stream> -w '%{http_code}'`,
  wodurch curl-Rückgabecode und HTTP-Status getrennt geprüft werden
  können. 3000 Chunks: 29 s → **0,12 s**.
- **Nudge-Logik mit Diagnose:** gechockt wird nur noch bei echtem
  `finish_reason == "length"`; jede Nudge-Zeile landet als
  `nudge k/max finish=… content=… reasoning=…` im Log, andere Fälle
  bekommen eigene Meldungen (nur-Reasoning, leer). Abbruch nennt jetzt
  Nudge-Anzahl, finish_reason und Reasoning-Länge.
- **`test/fake_server.sh`:** Endung `.sse` liefert die Datei als
  `text/event-stream` (Stream-Tests ohne Verbrauchsproblem), erste Zeile
  `STATUS:<code>|{json}` setzt den HTTP-Status.

### Behoben

- **Streaming-Regression in `call_api` (Schritt 36):** `rc=$?` nach
  `done < <(curl …)` war der Status des Schleifenkörpers statt von curl —
  Server-/HTTP-Fehler landeten still in der Nudge-Kette (4× „Antwort war
  leer", dann „Antwort mehrfach leer — Abbruch.") statt als API-Fehler.
  Die tool_calls-Fusion `jq -s '.[0] + .[1]'` mit zwei Here-Strings las
  nur das letzte Delta → `name: null`, Argumente als Fragment (`}`) →
  `tool: null` in der Session. `data:` ohne Leerzeichen und Streams ohne
  `[DONE]` wurden stillschweigend leer. Fix: rc-/HTTP-Guard, ein
  jq-Lauf, Server-Toleranz, Warnung bei fehlendem `[DONE]`, echte
  `usage`; Tests **`test/test_sse.sh` (19)**.
### Behoben

- **Kürzungen an der lex↔llama-Grenze entfallen (Schritt 38):**
  `append_message`, `append_tool_message` und `setup_messages` kappten bei
  100 000 Bytes (E2BIG-Guard für `jq --arg`), `append_message_json` und
  `assistant_msg` liefen noch über Argumente, `tool_read_file`/`tool_bash`/
  `tool_search`/`tool_browser`/`tool_mcp` kappten zusätzlich auf
  `_tool_max_output` (50 000 Bytes) und die zentrale Kappung in `run_turn`
  schnitt Ergebnisse ab, ohne dass das Modell es bemerken konnte. Der
  Nachrichtenpfad läuft jetzt über Dateien (`--rawfile`/`--slurpfile`),
  übergroße Tool-Ergebnisse legt `_tool_spill()` unter `~/.lex/toolout/`
  ab (jüngste 100) und der Kontext bekommt Kopf + Pfad. Unverändert bleiben
  Anzeige-Kappen (`_trace_*`, `render_markdown`), die 200-Treffer-/
  500-Einträge-Marker und `web_fetch max_length`.

- **Verlorene Bestandteile wiederhergestellt:** `_ms_now`/`span_log` und
  `cmd_eval` (`lex --eval`) fehlten, `test/fake_server.sh` und
  `test/test_http.sh` waren gelöscht und `test_proxy.sh` schickte echte
  Requests an Port 8080 (Regel 6) — alles zurückgeholt bzw. auf hohe
  Ports begrenzt.

- **`/exit`/`/quit` fehlten (Live-Fund 2026-10-01):** die Slash-Liste
  kannte nur `/status /server /help /plan` — `/exit` fiel zu `run_turn`,
  kostete einen kompletten Request (das Modell antwortete „Gut. …") und
  ließ die REPL offen. Jetzt `break` in der REPL bzw. rc 0 ohne
  Modell-Call in oneshot/pipe; `usage()` listet `/server` und `/exit`.

- **HUD loggte erfundene Token-Nullen (Live-Fund 2026-10-01):** der
  Request-Body fehlte `stream_options:{include_usage:true}` — llama-server
  liefert Usage im Stream nur auf Anforderung → jeder Turn zeigte
  `tokens 0 prompt + 0 completion`. Body ergänzt **und** der
  Nullen-Default in `_sse_to_response` entfernt: ohne usage-Event zeigt
  das HUD jetzt `?` statt zu lügen.

- **O6: kein Compaction/Summarization (Schritt 42):** `_messages` wuchs
  unbegrenzt, bis der Server an der ctx-Grenze ablehnte — jetzt
  Auto-Trigger vor `append_message user` plus `/compact` als Force;
  die Default-Schwelle liegt bewusst inert (242144), Alt-Tests laufen
  unverändert weiter.

### Geändert

- **Slash-Commands dokumentiert:** README und `usage()` nennen jetzt die
  vollständige Liste `/status`, `/server`, `/plan`, `/help`, `/exit`.

- **„Arbeitsrahmen" im System-Prompt (Schritt 40):** stehender Scope statt
  pro Anfrage — eigene Systeme/Lab/CTF, Blue-Team-Arbeit (Härtung,
  Schwachstellenanalyse, Malware-Analyse, Incident Response,
  Detektions-Engineering) als Kerngeschäft ohne Rückfrage; Offensiv-Begriffe
  als Arbeitsvokabular; Scope-Frage statt pauschaler Absage. Fundlage:
  Defensive Refusal Bias (arXiv 2603.01246) — Autorisierungs-Sätze in der
  *User-Message* verschlimmern Ablehnungen, COVER (ACL 2025) — der
  System-Prompt ist der wirksame Hebel.

- **HUD-Format mit ctx% (Schritt 42):** bei gesetztem `ctx_limit` zeigt
  `_trace_hud` `tokens 65536/262144 (25%) prompt + 42 completion`, ohne
  Limit weiter die alte Formel, ohne usage `?/Y` — vier Alt-Assertions in
  `test_features.sh`/`test_sse.sh` auf den neuen Vertrag gezogen.

### Dieser Stand

- Tests **591 → 669** (12 Läufer grün), `lex` 3211 → **3622 Zeilen**,
  `shellcheck -S warning` = 0.

## [0.1.0] — 2026-09-28

Erste vollständige, getestete Version.

### Hinzugefügt

- **Session-Persistenz (Spec §6.5):** append-only JSONL unter
  `~/.lex/sessions/<id>/session.jsonl` — Kopfzeile plus eine Zeile pro
  Message, inklusive `reasoning_content`. Das Reasoning landet bewusst
  **nicht** im Modell-Kontext (Kontextschutz, LEX.md §4).
  Abschalten mit `LEX_SESSION=0`.
- **Memory-Tools (Spec §6.4):** `mem_add`, `mem_list`, `mem_search`.
  Markdown mit YAML-Frontmatter (`date`, `type`, `slug`) unter
  `~/.lex/mem/`, Typen `memory|fact|preference|note`.
  Konfigurierbar über `LEX_MEM_DIR`.
- **Harte Deny-Liste für `tool_bash` (§6 #11):** `rm -rf /`/`~`,
  Blockgeräte, Fork-Bomben, `sudo`/`su`, Herunterfahren/Neustart,
  Systemprozesse, Rechte-Wegwerfen, `curl|sh` — **immer aktiv**.
- **Approval-Gate (§6 #12, opt-in):** `--approve` bzw. `LEX_APPROVE=1`
  fragt jede bash-Ausführung ab (nur mit controlling TTY).
- **`/status` (Spec §6.6)** als Slash-Befehl und als `lex --status`:
  Modus, Modell, API, Budget, Tools, Session, Memory, Turn-Zähler.
- **`edit_file` Multi-Block (Spec §6.6):** neues Argument `all`
  (Schema: `boolean`) ersetzt alle Vorkommen.
- **`lex --approve`**, `/help`, Port-Hinweis beim REPL-Start
  (nur Port-Prüfung per `ss`, **kein** HTTP-Request).
- **Test-Läufer `test/test_features.sh`** (53 Prüfungen) + Aufnahme in
  `run_all.sh` → 6 Läufer, 89 Prüfungen.
- **CI:** `.github/workflows/ci.yml` (`bash -n`, shellcheck, Tests, Hygiene).
- `README.md`, `CLAUDE.md`, `CHANGELOG.md`.

### Behoben

- **§6 #8 — GNU-Tool-Guards:** `readlink -f` beim Skript-Pfad,
  `realpath -m` in `safe_path()` und `timeout` in `tool_bash()` laufen
  jetzt über Fallback-Ketten (`_abs_path`, `_run_limited`).
- **§6 #9 — `install_lex`:** legt `mem/` an, nicht mehr `mem_net/`.
- **§6 #10 — `LEX_MOCK_FILE` zerstörte die Quelldatei:** jetzt
  Schattenkopie unter `~/.lex/mock/`; die Sequenz bleibt über Läufe
  erhalten, die Quelle bleibt unversehrt.
- **REPL-Prompt:** `printf '\033[1;34m\x01%\033[0m '` erzeugte
  „Ungültiges Formatierungszeichen" und einen kaputten Prompt
  (shellcheck SC2183) → `lex>`.
- **Isolation von `test_input.sh`:** `LEX_HOME` wurde nicht gesetzt,
  Tests schrieben Sessions und Mock-Schatten ins echte `~/.lex`.
- shellcheck `-S warning` ist für `lex` und alle Testdateien sauber.