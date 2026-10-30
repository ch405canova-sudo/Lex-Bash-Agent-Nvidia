#!/usr/bin/env bash
#
# lex/test/test_fuzz.sh — Fuzzing der Parser- und Dispatch-Grenzen (§8 F).
#
# Deterministisch: RANDOM=42, feste Korpusfälle, Mutationen aus einem festen
# Zeichenvorrat — gleicher Lauf = gleiche Eingaben, überall reproduzierbar.
#
# Ziele:
#   A) _sse_to_response … SSE- und Direkt-JSON-Pfad (also was call_api liefert)
#   B) Mock-Queue ………… call_api konsumiert kaputte Zeilen sauber
#   C) dispatch_tool …… Argument-Strukturen, NUR hilfreiche Tools
#                        (read_file / list_files / unbekannt — bewusst KEIN
#                         bash, mcp, web_*, browser, agent, task: die führen
#                         etwas aus und würden hier nur Rauschen erzeugen)
#
# Invarianten je Fall:
#   · kein Hang (Fall-Budget + 180-s-Watchdog über den ganzen Lauf)
#   · rc im erlaubten Bereich — Parser 0..5 (jq: 0 = ok, 5 = error()),
#     Dispatch 0/1; damit sind Abstürze (128+n, 124 Timeout) ausgeschlossen
#   · bei rc 0 (Parser): Ausgabe ist gültiges JSON mit choices-Array
#   · bei rc ≠ 0: stderr nennt den Fehler (kein stiller Abbruch)
#   · Queue danach leer, kein *.tmp-Rest (Read-Modify-Write-Sperre, §6 O3)
#   · keine Prozess-Reste, keine echten 8080-Requests
#
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEX_DIR="$(dirname "$SCRIPT_DIR")"

# Determinismus VOR jeder Erzeugung von Zufallsdaten.
RANDOM=42

TMP="$(mktemp -d)"
WATCHDOG=""
cleanup() {
  if [[ -n "$WATCHDOG" ]]; then
    if command -v pkill >/dev/null 2>&1; then pkill -P "$WATCHDOG" 2>/dev/null || true; fi
    kill "$WATCHDOG" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'cleanup; exit 143' TERM
start_watchdog() {
  stop_watchdog
  ( sleep 180 && kill -TERM "$$" 2>/dev/null ) &
  WATCHDOG=$!
  # Aus der Jobliste: sonst meldet die Shell beim Beenden des Wächters
  # „Beendet sleep 180" mitten im Testprotokoll.
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
check() {
  if [[ "$2" == "1" ]]; then pass "$1"; else fail "$1" "${3:-}"; fi
}

# Gruppen-Zähler: eine Zeile je Ziel, Details nur bei Verstößen.
CASES=0
CASEFAIL=0
case_start() { CASES=0; CASEFAIL=0; }
case_bad() {
  CASEFAIL=$((CASEFAIL + 1))
  printf '  [FAIL] %s — %s\n' "$1" "${2:-}" >&2
  FAIL=$((FAIL + 1))
  return 0
}
case_end() {
  if (( CASEFAIL == 0 )); then
    pass "$1 ($CASES Fälle, alle Invarianten erfüllt)"
  else
    printf '  [FAIL] %s: %s von %s Fällen verletzt\n' "$1" "$CASEFAIL" "$CASES" >&2
    FAIL=$((FAIL + 1))
  fi
  return 0
}

now_ms() { date +%s%N; }

# Deterministische Mutation: bis zu3 Schritte (löschen/ersetzen/einfügen/
# abschneiden) über den festen Zeichenvorrat — keine TMP-Abhängigkeit, damit
# der Lauf überall identische Eingaben erzeugt.
CHARS='!@#$%^&*(){}[]<>?/|`~;:=%+'
mutate() {
  local s="$1" i pos len
  for i in 1 2 3; do
    len="${#s}"
    (( len > 0 )) || break
    pos=$(( RANDOM % len ))
    case $(( RANDOM % 4 )) in
      0) s="${s:0:$pos}${s:$((pos + 1))}" ;;
      1) s="${s:0:$pos}${CHARS:$((RANDOM % ${#CHARS})):1}${s:$pos}" ;;
      2) s="${s:0:$pos}${CHARS:$((RANDOM % ${#CHARS})):1}${s:$((pos + 1))}" ;;
      3) s="${s:0:$pos}" ;;
    esac
  done
  printf '%s' "$s"
}

# lex sourceen: LEX_HOME isoliert, Mock an, MCP aus, stdin=/dev/null.
export LEX_HOME="$TMP"
export LEX_MODEL="$TMP/model.gguf"
export LEX_MOCK="done"
export LEX_MCP="0"
source "$LEX_DIR/lex" < /dev/null > /dev/null 2>&1 || {
  echo "FEHLSCHLAG: $LEX_DIR/lex nicht ladbar (Syntax-/Bash-Fehler)" >&2
  exit 1
}
setup_messages

# ===========================================================================
# A) _sse_to_response — feste Korpusfälle
# ===========================================================================
echo "[INFO] A) _sse_to_response (Korpus)"
C="$TMP/corpus"
mkdir -p "$C"

canon='data: {"choices":[{"index":0,"delta":{"content":"Hallo"}}]}

data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]
'

# -- feste, von Hand gesetzte Randfälle -------------------------------------
printf '' > "$C/empty"
printf '\n\n\n' > "$C/newlines"
printf '   \t  ' > "$C/spaces"
printf 'data:' > "$C/data_only"
printf 'data: {"choices":[' > "$C/truncated_json"
printf 'data: {"choices":[]}\n' > "$C/empty_choices"
printf 'data: null\n' > "$C/null_event"
printf 'data: 123\n' > "$C/number_event"
printf 'data: "text"\n' > "$C/string_event"
printf 'data: []\n' > "$C/array_event"
printf 'data: {"error":{}}\n' > "$C/error_without_msg"
printf 'data: {"choices":[{"delta":{"tool_calls":"kein-array"}}]}\n' > "$C/tcs_as_string"
printf 'data: {"choices":[{"delta":{"content":123}}]}\n' > "$C/content_number"
printf 'data: {"choices":[{"delta":{"content":null}}]}\n' > "$C/content_null"
printf 'data: {"choices":[{"index":"x","delta":{}}]}\n' > "$C/index_string"
printf '{"choices":[{"index":0,"message":{"role":"assistant","content":"ok"}}]}\n' > "$C/direct_ok"
printf '{}\n' > "$C/direct_empty"
printf '[]\n' > "$C/direct_array"
printf '{"choices":{}}\n' > "$C/direct_choices_object"
printf '{"choices":null}\n' > "$C/direct_choices_null"
printf '{"choices":[' > "$C/direct_truncated"
printf 'd' > "$C/head_d"
printf '{\n' > "$C/head_brace_nl"
printf 'data: {"choices":[{"delta":{"content":"Ünïcödé ✓ 🚀"}}]}\n\ndata: [DONE]\n' > "$C/unicode"
# Steuerzeichen/Binary-Reste (als Datei, weil Bash-Variablen kein NUL halten)
printf 'data: \x01\x02\x03\x7f\x1b[31mrot\x00ende\n' > "$C/control_bytes"
# Riesige Einzelzeile
{ printf 'data: {"choices":[{"delta":{"content":"'; head -c 200000 /dev/zero | tr '\0' 'x'; printf '"}}]}\n'; } > "$C/huge_line"
# Zu tiefe Verschachtelung (jq-Scanlimit): gültiges JSON, choices = tiefes Array
{ printf 'data: {"choices":['; head -c 4000 /dev/zero | tr '\0' '[' ; printf '1'; head -c 4000 /dev/zero | tr '\0' ']'; printf ']}\n'; } > "$C/deep_nesting"

# -- deterministische Mutationen eines gültigen Streams ---------------------
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  mutate "$canon" > "$C/mut_$i.sse"
done
# Mutation eines Direkt-JSON-Falls
mutate '{"choices":[{"index":0,"message":{"role":"assistant","content":"Hallo Welt."}}]}' > "$C/mut_direct.json"

start_watchdog
case_start
for f in "$C"/*; do
  [[ -e "$f" ]] || continue
  name="${f##*/}"
  out="$TMP/A_$name.out"
  err="$TMP/A_$name.err"
  t0="$(now_ms)"
  _sse_to_response "$f" > "$out" 2> "$err"
  rc=$?
  t1="$(now_ms)"
  ms=$(( (t1 - t0) / 1000000 ))
  CASES=$((CASES + 1))
  if (( ms > 5000 )); then
    case_bad "$name" "zu langsam: $ms ms (Hang-Verdacht)"
    continue
  fi
  if (( rc < 0 || rc > 5 )); then
    case_bad "$name" "rc=$rc außerhalb 0..5 (Crash/Timeout?)"
    continue
  fi
  if (( rc == 0 )); then
    # Ganze Datei prüfen (die Riesenantwort ist größer als head -c).
    if ! jq -e '(.choices | type) == "array"' > /dev/null 2>&1 "$out"; then
      case_bad "$name" "rc 0, aber kein choices-Array: $(head -c 160 "$out")"
      continue
    fi
  else
    if [[ ! -s "$err" ]]; then
      case_bad "$name" "rc=$rc ohne Fehlermeldung auf stderr (still)"
      continue
    fi
  fi
done
case_end "A) _sse_to_response"

# ===========================================================================
# B) Mock-Queue mit kaputten Zeilen über call_api
# ===========================================================================
echo "[INFO] B) call_api (kaputte Mock-Zeilen)"
q="$TMP/fuzz_queue.jsonl"
{
  printf '%s\n' '{"choices":[{"index":0,"message":{"role":"assistant","content":"gut.","tool_calls":[]}}]}'
  printf '%s\n' 'kaputte zeile ohne json'
  printf '%s\n' '{"choices":['
  printf '%s\n' ''
  mutate "$canon"
  printf '%s\n' 'null'
  printf '%s\n' '{"choices":[{"message":{"content":42}}]}'
  printf '%s\n' 'data: {"choices":[]}'
} > "$q"
start_watchdog
case_start
_mock_file="$q"
n_lines="$(wc -l < "$q" | tr -d ' ')"
for ((i = 0; i < n_lines; i++)); do
  t0="$(now_ms)"
  line="$(call_api)"; c_rc=$?
  t1="$(now_ms)"
  CASES=$((CASES + 1))
  if (( (t1 - t0) / 1000000 > 5000 )); then
    case_bad "call_api Zeile $i" "zu langsam"
    continue
  fi
  if (( c_rc != 0 )); then
    case_bad "call_api Zeile $i" "rc=$c_rc (muss 0 sein — Fallback ist 'Taugt.')"
    continue
  fi
  if [[ -z "$line" ]]; then
    case_bad "call_api Zeile $i" "leere Ausgabe"
    continue
  fi
  # Was danach an den Parser geht, darf ihn nicht werfen, ohne zu erklären.
  # Achtung: als Datei ablegen, NICHT per <( … ) — _sse_to_response liest mit
  # `head -c 1` die erste Byte aus der Quelle, an einer Pipe wäre die weg.
  p_in="$TMP/B_$i.line"
  p_out="$TMP/B_$i.out"; p_err="$TMP/B_$i.err"
  printf '%s\n' "$line" > "$p_in"
  _sse_to_response "$p_in" > "$p_out" 2> "$p_err"
  p_rc=$?
  CASES=$((CASES + 1))
  if (( p_rc < 0 || p_rc > 5 )); then
    case_bad "Parser nach Zeile $i" "rc=$p_rc außerhalb 0..5"
    continue
  fi
  if (( p_rc != 0 )) && [[ ! -s "$p_err" ]]; then
    case_bad "Parser nach Zeile $i" "rc=$p_rc ohne Meldung"
    continue
  fi
done
_mock_file=""
rest="$(wc -l < "$q" | tr -d ' ')"
check "B) Queue vollständig konsumiert" "$([[ "$rest" == "0" ]] && echo 1 || echo 0)" "$rest Zeilen übrig"
check "B) kein *.tmp-Rest (Read-Modify-Write)" \
  "$([[ -e "$q.tmp" ]] && echo 0 || echo 1)" "Datei $q.tmp existiert"
case_end "B) call_api mit kaputten Zeilen"

# ===========================================================================
# C) dispatch_tool — Argument-Strukturen (hilfreiche Tools)
# ===========================================================================
echo "[INFO] C) dispatch_tool (Argument-Fuzz)"
printf 'Zielinhalt für read_file.\n' > "$TMP/vorhanden.txt"
mkdir -p "$TMP/verzeichnis"

start_watchdog
case_start
# -- Werkzeugnamen (leer/unbekannt/selbständige Namen) ---------------------
for name in "" "kann_nicht" "BASH" "read_file " " read_file" "../../etc/passwd" "list_files"; do
  t0="$(now_ms)"
  out="$(dispatch_tool "$name" '{"path":"'"$TMP"'/vorhanden.txt"}' 2>&1)"
  rc=$?
  t1="$(now_ms)"
  CASES=$((CASES + 1))
  if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "Tool-Name '$name'" "zu langsam"; continue; fi
  if (( rc < 0 || rc > 1 )); then case_bad "Tool-Name '$name'" "rc=$rc außerhalb 0..1"; continue; fi
  if [[ -z "$out" ]]; then case_bad "Tool-Name '$name'" "keine Rückmeldung (still)"; continue; fi
done

# -- Argument-Strukturen (Index-Array: Reihenfolge und damit der RANDOM-
#    Verbrauch bleiben fest) ------------------------------------------------
p="$TMP/vorhanden.txt"
fuzz_args=(
  $'leer\t'
  $'kein_json\tkein json'
  $'array\t[1,2,3]'
  $'zahl\t123'
  $'string\t"text"'
  $'null\tnull'
  $'offen\t{"path":'
  $'pfad_zahl\t{"path":123}'
  $'pfad_objekt\t{"path":{"in":1}}'
  $'pfad_array\t{"path":["a","b"]}'
  $'pfad_null\t{"path":null}'
  $'pfad_leer\t{"path":""}'
  $'zusatztypen\t{"path":true,"content":false,"old":[],"new":{}}'
)
for entry in "${fuzz_args[@]}"; do
  key="${entry%%$'\t'*}"
  fargs="${entry#*$'\t'}"
  t0="$(now_ms)"
  out="$(dispatch_tool read_file "$fargs" 2>&1)"
  rc=$?
  t1="$(now_ms)"
  CASES=$((CASES + 1))
  if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "args:$key" "zu langsam"; continue; fi
  if (( rc < 0 || rc > 1 )); then case_bad "args:$key" "rc=$rc außerhalb 0..1"; continue; fi
  if [[ -z "$out" ]]; then case_bad "args:$key" "keine Rückmeldung"; continue; fi
done

# -- Pfade: existierend / Verzeichnis / fehlend / Sonderzeichen / groß -----
paths=(
  "$p"
  "$TMP/verzeichnis"
  "$TMP/gibt_es_nicht.txt"
  "$TMP/../$(basename "$TMP")/vorhanden.txt"
  "/dev/null"
  "$TMP/$(printf 'zeile\nbruch').txt"
  "$TMP/ünïcode-🚀.txt"
)
for path in "${paths[@]}"; do
  a="$(jq -cn --arg p "$path" '{path:$p}')"
  t0="$(now_ms)"
  out="$(dispatch_tool read_file "$a" 2>&1)"
  rc=$?
  t1="$(now_ms)"
  CASES=$((CASES + 1))
  if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "path:${path:0:40}" "zu langsam"; continue; fi
  if (( rc < 0 || rc > 1 )); then case_bad "path:${path:0:40}" "rc=$rc außerhalb 0..1"; continue; fi
  if [[ -z "$out" ]]; then case_bad "path:${path:0:40}" "keine Rückmeldung"; continue; fi
done

# -- sehr langer Pfad + tiefe Verschachtelung ------------------------------
long_path="$(head -c 100000 /dev/zero | tr '\0' 'a')"
a="$(jq -cn --arg p "$TMP/$long_path" '{path:$p}')"
t0="$(now_ms)"
out="$(dispatch_tool read_file "$a" 2>&1)"; rc=$?
t1="$(now_ms)"
CASES=$((CASES + 1))
if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "path:100k" "zu langsam"
elif (( rc < 0 || rc > 1 )); then case_bad "path:100k" "rc=$rc außerhalb 0..1"
else check "C) Argument-Fuzz:100-kB-Pfad abgefangen" \
  "$([[ -n "$out" ]] && echo 1 || echo 0)" "leere Rückmeldung"; fi

deep="$(head -c 2000 /dev/zero | tr '\0' '[')1$(head -c 2000 /dev/zero | tr '\0' ']')"
t0="$(now_ms)"
out="$(dispatch_tool read_file "$deep" 2>&1)"; rc=$?
t1="$(now_ms)"
CASES=$((CASES + 1))
if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "args:deep" "zu langsam"
elif (( rc < 0 || rc > 1 )); then case_bad "args:deep" "rc=$rc außerhalb 0..1"
elif [[ -z "$out" ]]; then case_bad "args:deep" "keine Rückmeldung"
else :; fi

# -- Mutationen einer gültigen Argument-JSON -------------------------------
for i in 1 2 3 4 5 6; do
  a="$(mutate '{"path":"'"$TMP"'/vorhanden.txt","old":"a","new":"b"}')"
  t0="$(now_ms)"
  out="$(dispatch_tool read_file "$a" 2>&1)"
  rc=$?
  t1="$(now_ms)"
  CASES=$((CASES + 1))
  if (( (t1 - t0) / 1000000 > 5000 )); then case_bad "mut_args $i" "zu langsam"; continue; fi
  if (( rc < 0 || rc > 1 )); then case_bad "mut_args $i" "rc=$rc außerhalb 0..1 ($a)"; continue; fi
  if [[ -z "$out" ]]; then case_bad "mut_args $i" "keine Rückmeldung"; continue; fi
done
case_end "C) dispatch_tool"

# ===========================================================================
# Abschluss: die Session ist nach dem Fuzz noch brauchbar, keine Reste
# ===========================================================================
out="$(dispatch_tool read_file "$(jq -cn --arg p "$p" '{path:$p}')" 2>&1)"
check "nach dem Fuzz: normaler Tool-Lauf noch möglich" \
  "$([[ "$out" == *"Zielinhalt"* ]] && echo 1 || echo 0)" "$out"
leaks="$(pgrep -fa '127\.0\.0\.1:8080|ncat .*8080|http\.server 246|fake_mcp_hang' 2>/dev/null \
  | grep -v 'pgrep\|test_fuzz' | wc -l | tr -d ' ')"
check "kein Prozess-Rest / kein 8080-Request" \
  "$([[ "$leaks" == "0" ]] && echo 1 || echo 0)" "$leaks Treffer"

echo ""
if (( FAIL > 0 )); then
  echo "FEHLSCHLAG: $FAIL Prüfung(en) in test_fuzz.sh" >&2
  exit 1
fi
echo "test_fuzz.sh grün. ✓"
exit 0
