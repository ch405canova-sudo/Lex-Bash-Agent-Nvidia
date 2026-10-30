# test/fixtures — Golden Files (§8 F)

Statische Testdaten als eigene Dateien statt als Inline-JSON in den
Testskripten. Zweck: eine Sequenz hat GENAU EINE Quelle, ihre Sollwerte sind
im Git-Diff sichtbar, und `test_golden.sh` sperrt beides.

## Aufbau

| Pfad | Inhalt | Soll-Datei |
|---|---|---|
| `*.jsonl` | Mock-Antwort-Sequenzen für `_mock_file`/`LEX_MOCK_FILE` (eine OpenAI-Response pro Zeile) | `golden.tsv` |
| `sse/*` | Eingabe-Streams für `_sse_to_response` (SSE `data:`-Events, Direkt-JSON, Fehlerfälle) | `*.golden.json` bzw. `*.golden.err` |
| `md/*` | Markdown-Eingaben für `_md_render force` | `*.golden.out` (roh, inkl. ANSI-Farbcodes) |

`golden.tsv` hält pro `*.jsonl`: Zeilenanzahl, Inhalt der letzten Antwort und
deren `finish_reason` (Felder JSON-kodiert, damit `\n` die TSV nicht zerlegt).

## Regeln

1. **Nur statische Sequenzen.** Was `$TMP`, Lauf-Zähler oder Funktionsaufrufe
   interpolated, bleibt als `printf` im Testskript — eine Fixture darf keinen
   Platzhalter enthalten (`test_golden.sh` prüft das).
2. **Aufruf per `cp`, nicht per Umleitung.** `call_api` konsumiert
   `_mock_file` (head/tail + mv, §6 O3) — wer direkt aus `fixtures/` liest,
   würde die Quelle zerstören. Immer:
   `cp "$FIX/name.jsonl" "$TMP/name.json"` und `_mock_file` darauf setzen.
3. **Sollwerte nur bewusst ändern:**
   `LEX_GOLDEN_UPDATE=1 ./test/test_golden.sh`
   Der Update-Lauf schreibt `golden.tsv` und alle `*.golden.*`; der
   resulting Git-Diff ist die Freigabe-Hürde (im Review sichtbar).

## Fälle in `sse/`

- `content.sse` — Textdeltas, `[DONE]`, `_lex_stream_ok:true`
- `toolcall_split.sse` — Name/Argumente über mehrere Chunks verteilt
  (Regression: Fusion der `tool_calls`, Name=None sonst)
- `reasoning_usage.sse` — `reasoning_content`, `usage`, `finish=length`
- `no_done.sse` — Stream ohne `[DONE]` → `_lex_stream_ok:false`
- `direct.json` — Server ignoriert `stream:true`, Antwort ist reines JSON
- `error.sse`, `no_events.sse`, `direct_bad.json` — Fehlerpfad: rc ≠ 0 plus
  exakte jq-Meldung in `*.golden.err` (Höhe des jq-Codes wird nicht gepinnt,
  jq 1.8 meldet `error()` mit 5).
