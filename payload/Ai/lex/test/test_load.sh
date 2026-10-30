#!/usr/bin/env bash
#
# lex/test/test_load.sh — Lastfälle (§8 F): breite SSE-Streams, breite
# Responses, großer Kontext inkl. automatischer Kompaktion, große
# Einzelantwort, lange Mock-Queue, echter Multi-Tool-Dispatch.
# NUR Mock/Fake — nie an 127.0.0.1:8080.
#
# Budgets: max(4 × Referenz, 5000 ms). Die Referenzwerte sind Messungen vom
# 2026-10-28 (Workstation, jq 1.8.1) und stehen in REF unten; der Lauf gibt
# seine Ist-Zeit immer als [INFO] mit aus. Der Test fängt Hänge und
# Zusammenbrüche (superlineares Wachstum, leere/gekürzte Ergebnisse), keine
# Fein-Regressionen — CI ist langsamer als die Referenzmaschine, die
# Reserve liegt im Faktor und im 180-s-Watchdog pro Lauf.
#
# Neu messen ohne rot zu werden:  LEX_LOAD_MEASURE=1 ./test/test_load.sh
# (Budgettreffer werden dann nur als [INFO] gemeldet; Referenztabelle danach
#  nachtragen und den Modus wieder abschalten.)
#
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEX_DIR="$(dirname "$SCRIPT_DIR")"

MEASURE="${LEX_LOAD_MEASURE:-0}"

# Referenzmessungen (ms) — Budget = max(4 × Wert, 5000 ms).
declare -A REF=(
  [sse5000]=116
  [tools300]=9
  [ctx4001]=9056
  [answer2mb]=3841
  [queue500]=6786
  [tools20]=2319
)

TMP="$(mktemp -d)"
WATCHDOG=""
cleanup() {
  if [[ -n "$WATCHDOG" ]]; then
    # pkill zuerst: sonst läuft der Wächter nach dem kill weiter, sein
    # „sleep && kill" bekäme den Sleep-Weg-Exit noch als Erfolg (sleep stirbt
    # mit rc ≠ 0 → && bricht ab, also kein Rückschlag auf dieses Skript).
    if command -v pkill >/dev/null 2>&1; then pkill -P "$WATCHDOG" 2>/dev/null || true; fi
    kill "$WATCHDOG" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
# Watchdog: 180 s ohne Ende → harter Abbruch (rc 143 → in run_all FAIL statt
# eines hängenden Läufers, der die ganze Suite aufhält).
trap 'cleanup; exit 143' TERM
start_watchdog() {
  stop_watchdog
  ( sleep 180 && kill -TERM "$$" 2>/dev/null ) &
  WATCHDOG=$!
  disown "$WATCHDOG" 2>/dev/null || true
}
stop_watchdog() {
  [[ -z "$WATCHDOG" ]] && return 0
  if command -v pkill >/dev/null 2>&1; then pkill -P "$WATCHDOG" 2>/dev/null || true; fi
  kill "$WATCHDOG" 2>/dev/null || true
  WATCHDOG=""
  return 0
}

FAIL=0
pass() { printf '  [PASS] %s\n' "$1"; }
fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then printf '         %s\n' "$2" >&2; fi
  FAIL=$((FAIL + 1))
  return 0
}
# assert: Vergleich erwartet/ist (wie test_compaction.sh)
assert() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1" "erwartet: $2 — ist: $3"
  fi
}
# check: Zustandsform, 1 = Bedingung erfüllt
check() {
  if [[ "$2" == "1" ]]; then pass "$1"; else fail "$1" "${3:-}"; fi
}

# Budget-Prüfung: Ist-Zeit immer als [INFO], Verstoß nur im Normalmodus rot.
budget() {
  local key ms limit ref
  key="$1"
  ms="$2"
  ref="${REF[$1]:-0}"
  limit=$(( ref * 4 ))
  (( limit < 5000 )) && limit=5000
  printf '  [INFO] %s: %s ms (Referenz %s ms, Budget %s ms)\n' "$key" "$ms" "$ref" "$limit"
  if (( ms <= limit )); then
    return 0
  fi
  if [[ "$MEASURE" == "1" ]]; then
    printf '  [INFO] %s überschreitet das Budget (Messmodus: nicht rot)\n' "$key"
    return 0
  fi
  fail "$key innerhalb Budget" "ist $ms ms > $limit ms (Referenz $ref ms)"
  return 0
}

now_ms() { date +%s%N; }

# lex sourceen: LEX_HOME isoliert, Mock an, MCP aus, stdin=/dev/null.
export LEX_HOME="$TMP"
export LEX_MODEL="$TMP/model.gguf"
export LEX_MOCK="done"
export LEX_MCP="0"
source "$LEX_DIR/lex" < /dev/null > /dev/null 2>&1 || {
  echo "FEHLSCHLAG: $LEX_DIR/lex nicht ladbar (Syntax-/Bash-Fehler)" >&2
  exit 1
}

# ===========================================================================
# L1 — SSE-Stream mit 5000 Content-Deltas (Größenordnung Echt-Stream)
# ===========================================================================
echo "[INFO] L1 sse5000 (5000 Deltas)"
f="$TMP/wide.sse"
{
  for _ in $(seq 1 5000); do
    printf 'data: {"choices":[{"index":0,"delta":{"content":"xy"}}]}\n\n'
  done
  printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}\n\n'
  printf 'data: [DONE]\n\n'
} > "$f"
start_watchdog
t0="$(now_ms)"
resp="$(_sse_to_response "$f" 2>/dev/null)"
rc=$?
t1="$(now_ms)"
stop_watchdog
budget sse5000 "$(( (t1 - t0) / 1000000 ))"
assert "sse5000 (rc 0)" "0" "$rc"
assert "sse5000 (5000 Deltas zusammengeführt)" "10000" \
  "$(jq -r '.choices[0].message.content | length' <<< "$resp" 2>/dev/null)"
# _sse_to_response liefert pretty-printed JSON → Felder per jq lesen,
# nicht per String-Match.
assert "sse5000 (finish=stop)" "stop" \
  "$(jq -r '.choices[0].finish_reason' <<< "$resp" 2>/dev/null)"
check "sse5000 ([DONE] erkannt)" \
  "$([[ "$(jq -r '._lex_stream_ok' <<< "$resp" 2>/dev/null)" == "true" ]] && echo 1 || echo 0)"

# ===========================================================================
# L2 — Direkt-JSON mit 300 Tool-Calls in EINER Response (Passthrough)
# ===========================================================================
echo "[INFO] L2 tools300 (300 tool_calls)"
f2="$TMP/wide_tools.json"
jq -cn '{choices:[{index:0,message:{role:"assistant",content:"",
  tool_calls:[range(0;300)|{index:.,id:("tc"+tostring),type:"function",
  function:{name:"bash",arguments:("{\"command\":\"echo "+tostring+"\"}")}}],
  reasoning_content:""},finish_reason:"tool_calls"}],"usage":{"total_tokens":1}}' > "$f2"
start_watchdog
t0="$(now_ms)"
resp="$(_sse_to_response "$f2" 2>/dev/null)"
rc=$?
t1="$(now_ms)"
stop_watchdog
budget tools300 "$(( (t1 - t0) / 1000000 ))"
assert "tools300 (rc 0)" "0" "$rc"
assert "tools300 (alle Calls erhalten)" "300" \
  "$(jq -r '.choices[0].message.tool_calls | length' <<< "$resp" 2>/dev/null)"
assert "tools300 (Argumente unverändert)" '{"command":"echo 299"}' \
  "$(jq -c '.choices[0].message.tool_calls[299].function.arguments | fromjson' <<< "$resp" 2>/dev/null)"

# ===========================================================================
# L3 — großer Kontext: 4001 Nachrichten (~480 KB), Grenzwert-Kompaktion
# Der Fall liegt BEWUSST über der automatischen Schwelle (Messung:
# estimate 160311 > threshold 160224) — getestet wird das Lastverhalten
# von run_turn MIT Kompaktion, nicht das Inert-Verhalten (das deckt
# test_compaction ab).
# ===========================================================================
echo "[INFO] L3 ctx4001 (~480 KB Kontext + auto-Kompaktion)"
setup_messages
_messages="$(jq -cn '[{role:"system",content:"SYSTEMPROMPT"}]
  + [range(0;4000) | {role:(if . % 2 == 0 then "user" else "assistant" end),
      content:("Frage und Antwort Nummer "+tostring+" mit etwas mehr Text, damit der Kontext realistisch wächst.")}]')"
ctx_bytes="$(printf '%s' "$_messages" | wc -c | tr -d ' ')"
check "ctx4001 (Kontextgröße ~480 KB)" \
  "$([[ "$ctx_bytes" -ge 400000 ]] && echo 1 || echo 0)" "nur $ctx_bytes Bytes"
check "ctx4001 (Paarungs-Gate vor dem Turn)" \
  "$(_pairing_ok <<< "$_messages" >/dev/null 2>&1 && echo 1 || echo 0)"
est="$(_compact_estimate)"
check "ctx4001 (über der Kompaktierungs-Schwelle)" \
  "$([[ "$est" -gt "$(_compact_threshold)" ]] && echo 1 || echo 0)" \
  "estimate $est, Schwelle $(_compact_threshold)"
start_watchdog
t0="$(now_ms)"
run_turn "Lastlauf" > "$TMP/out_l3.txt" 2> "$TMP/err_l3.txt"
rc=$?
t1="$(now_ms)"
stop_watchdog
budget ctx4001 "$(( (t1 - t0) / 1000000 ))"
assert "ctx4001 (run_turn rc 0)" "0" "$rc"
assert "ctx4001 (Mock-Antwort kommt an)" "Taugt." "$(cat "$TMP/out_l3.txt")"
check "ctx4001 (Kompaktion lief und ist protokolliert)" \
  "$([[ "${_compact_count:-0}" -ge 1 ]] && echo 1 || echo 0)" \
  "_compact_count=${_compact_count:-0}"
check "ctx4001 (Logzeile compact:)" \
  "$(grep -c 'compact:' "$LEX_HOME/log/lex.log" 2>/dev/null | grep -q '^[1-9]' && echo 1 || echo 0)"
assert "ctx4001 (Tail behält Struktur: system zuerst)" "system" \
  "$(jq -r '.[0].role' <<< "$_messages" 2>/dev/null)"
check "ctx4001 (Paarungs-Gate nach der Kompaktion)" \
  "$(_pairing_ok <<< "$_messages" >/dev/null 2>&1 && echo 1 || echo 0)"
check "ctx4001 (Tail deutlich kleiner, aber nicht leer)" \
  "$([[ "$(jq 'length' <<< "$_messages" 2>/dev/null)" -ge 100 && "$(jq 'length' <<< "$_messages" 2>/dev/null)" -lt 4001 ]] \
    && echo 1 || echo 0)" "nun $(jq 'length' <<< "$_messages" 2>/dev/null) Einträge"

# ===========================================================================
# L4 — 2-MB-Einzelantwort rendert vollständig
# Inhalt ist EINDEUTIG (laufende Zahl/x/Oktal-Dreier je Position), damit der
# Repetitions-Guard (_rep_detect: A1 Trailing-Run / A2 Satz-Loop /
# A3 Rep-4) nicht zuschlägt — sonst misst der Test die Abwehr, nicht die Last.
# ===========================================================================
echo "[INFO] L4 answer2mb (2 MB Antwort)"
mock="$TMP/huge.json"
big="$(awk 'BEGIN{for(i=0;i<150000;i++)printf "%d/%x/%o ", i,i,i}')"
printf '{"choices":[{"index":0,"message":{"role":"assistant","content":"%s","tool_calls":[]},"finish_reason":"stop"}]}\n' \
  "$big" > "$mock"
check "answer2mb (Mock-Datei ≥ 2 MB)" \
  "$([[ "$(wc -c < "$mock")" -ge 2000000 ]] && echo 1 || echo 0)" \
  "$(wc -c < "$mock") Bytes"
rep_hit="$(printf '%s' "$big" | _rep_detect)"
check "answer2mb (Repetitions-Guard unauffällig)" \
  "$([[ -z "$rep_hit" ]] && echo 1 || echo 0)" "$rep_hit"
_mock_file="$mock"
start_watchdog
t0="$(now_ms)"
run_turn "Riesenantwort" > "$TMP/out_l4.txt" 2> "$TMP/err_l4.txt"
rc=$?
t1="$(now_ms)"
stop_watchdog
_mock_file=""
budget answer2mb "$(( (t1 - t0) / 1000000 ))"
out_l4="$(wc -c < "$TMP/out_l4.txt" | tr -d ' ')"
assert "answer2mb (run_turn rc 0)" "0" "$rc"
check "answer2mb (Antwort vollständig gerendert)" \
  "$([[ "$out_l4" -ge 2000000 ]] && echo 1 || echo 0)" "nur $out_l4 Bytes"
check "answer2mb (kein Loop-Hinweis auf stderr)" \
  "$([[ "$(cat "$TMP/err_l4.txt")" != *"Wiederholungsschleife"* ]] && echo 1 || echo 0)" \
  "$(head -c 120 "$TMP/err_l4.txt")"

# ===========================================================================
# L5 — 500er-Mock-Queue über call_api (Datei-I/O pro Turn)
# ===========================================================================
echo "[INFO] L5 queue500 (500 Antworten)"
q="$TMP/queue.jsonl"
jq -cn 'range(0;500) | {choices:[{index:0,message:{role:"assistant",
  content:("Antwort "+tostring),tool_calls:[]},finish_reason:"stop"}]}' > "$q"
assert "queue500 (Queue angelegt)" "500" "$(wc -l < "$q" | tr -d ' ')"
_mock_file="$q"
start_watchdog
t0="$(now_ms)"
last=""
rc=0
for ((i = 0; i < 500; i++)); do
  last="$(call_api)" || rc=1
done
t1="$(now_ms)"
stop_watchdog
_mock_file=""
budget queue500 "$(( (t1 - t0) / 1000000 ))"
assert "queue500 (alle Aufrufe ok)" "0" "$rc"
assert "queue500 (Queue vollständig konsumiert)" "0" "$(wc -l < "$q" | tr -d ' ')"
assert "queue500 (letzte Antwort = Nummer 499)" "Antwort 499" \
  "$(jq -r '.choices[0].message.content' <<< "$last" 2>/dev/null)"

# ===========================================================================
# L6 — 20 Tool-Calls in EINER Response, echter Dispatch + finale Antwort
# Breite wird per jq konstruiert (der Lastfall definiert die Größe), die
# fertige Queue bleibt deshalb inline wie in test_limits.sh.
# ===========================================================================
echo "[INFO] L6 tools20 (20 Calls + Abschluss-Turn)"
m6="$TMP/twenty.json"
{
  jq -cn '{choices:[{index:0,message:{role:"assistant",content:"",
    tool_calls:[range(0;20)|{index:.,id:("c"+tostring),type:"function",
    function:{name:"bash",arguments:("{\"command\":\"echo Nummer "+tostring+"\"}")}}],
    reasoning_content:""},finish_reason:"tool_calls"}]}'
  jq -cn '{choices:[{index:0,message:{role:"assistant",content:"Alle 20 erledigt.",
    tool_calls:[]},finish_reason:"stop"}]}'
} > "$m6"
assert "tools20 (Queue mit 2 Zeilen)" "2" "$(wc -l < "$m6" | tr -d ' ')"
setup_messages
_mock_file="$m6"
start_watchdog
t0="$(now_ms)"
run_turn "zwanzig Tools" > "$TMP/out_l6.txt" 2> "$TMP/err_l6.txt"
rc=$?
t1="$(now_ms)"
stop_watchdog
_mock_file=""
budget tools20 "$(( (t1 - t0) / 1000000 ))"
assert "tools20 (run_turn rc 0)" "0" "$rc"
assert "tools20 (finale Antwort kommt an)" "Alle 20 erledigt." "$(cat "$TMP/out_l6.txt")"
# Ein Turn = 20 Calls in EINER assistant-Message, danach 20 tool-Results:
# system(1) + user(1) + assistant(1) + tool(20) + assistant-Final(1) = 24.
assert "tools20 (alle Ergebnisse im Kontext: 20 tool)" "20" \
  "$(jq -r '[.[] | select(.role=="tool")] | length' <<< "$_messages" 2>/dev/null)"
assert "tools20 (Kontext vollständig: 24 Einträge)" "24" \
  "$(jq 'length' <<< "$_messages" 2>/dev/null)"
check "tools20 (Paarungs-Gate hält)" \
  "$(_pairing_ok <<< "$_messages" >/dev/null 2>&1 && echo 1 || echo 0)"

# ===========================================================================
# Restkontrolle: kein echter Server, keine Prozess-Reste
# ===========================================================================
leaks="$(pgrep -fa '127\.0\.0\.1:8080|ncat .*8080|http\.server 246|fake_mcp_hang' 2>/dev/null \
  | grep -v 'pgrep\|test_load' | wc -l | tr -d ' ')"
check "kein Prozess-Rest / kein 8080-Request" \
  "$([[ "$leaks" == "0" ]] && echo 1 || echo 0)" "$leaks Treffer"

echo ""
if (( FAIL > 0 )); then
  echo "FEHLSCHLAG: $FAIL Prüfung(en) in test_load.sh" >&2
  exit 1
fi
echo "test_load.sh grün. ✓"
exit 0
