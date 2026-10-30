#!/usr/bin/env bash
#
# lex/test/test_golden.sh — Golden Files (§8 F, LEX.md).
#
# Drei Sektionen, alle ohne Server und ohne Port 8080 (nur source + jq + cmp):
#   A) fixtures/*.jsonl … Mock-Sequenzen: JSONL-Integrität + golden.tsv
#   B) fixtures/sse/*   … _sse_to_response: SSE/JSON → OpenAI-Response
#   C) fixtures/md/*    … _md_render force: Markdown → Terminal-Ausgabe
#
# Soll-Dateien: golden.tsv, *.golden.json, *.golden.err, *.golden.out.
# Neue/Geänderte Sollwerte NUR bewusst erzeugen — der Git-Diff zeigt sie:
#   LEX_GOLDEN_UPDATE=1 ./test/test_golden.sh
#
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEX_DIR="$(dirname "$SCRIPT_DIR")"
FIX="$SCRIPT_DIR/fixtures"
UPD="${LEX_GOLDEN_UPDATE:-0}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

# lex sourceen wie die anderen Tests: LEX_HOME isoliert, Mock an, MCP aus,
# stdin=/dev/null (sonst startet die REPL), ohne echte HTTP-Calls.
export LEX_HOME="$TMP"
export LEX_MODEL="$TMP/model.gguf"
export LEX_MOCK="done"
export LEX_MCP="0"
source "$LEX_DIR/lex" < /dev/null > /dev/null 2>&1 || {
  echo "FEHLSCHLAG: $LEX_DIR/lex nicht ladbar (Syntax-/Bash-Fehler)" >&2
  exit 1
}

# ===========================================================================
# A) fixtures/*.jsonl — Integrität + golden.tsv
# ===========================================================================
echo "[INFO] A) fixtures/*.jsonl (Integrität + golden.tsv)"

# Soll-Manifest: Dateiname, Zeilen, Inhalt der letzten Antwort, deren
# finish_reason. Felder als JSON-kodiert, damit \n/\t in Inhalten die
# TSV-Zeile nicht zerlegen.
gen_manifest() {
  local f n lc lf
  printf 'datei\tzeilen\tletzter_content\tletzter_finish\n'
  for f in "$FIX"/*.jsonl; do
    [[ -e "$f" ]] || continue
    n="$(wc -l < "$f" | tr -d ' ')"
    lc="$(tail -n1 "$f" | jq -c '.choices[0].message.content // ""' 2>/dev/null)" \
      || lc='"<unparsbar>"'
    lf="$(tail -n1 "$f" | jq -c '.choices[0].finish_reason // ""' 2>/dev/null)" \
      || lf='"<unparsbar>"'
    printf '%s\t%s\t%s\t%s\n' "${f##*/}" "$n" "$lc" "$lf"
  done
}

nfix=0
for f in "$FIX"/*.jsonl; do
  [[ -e "$f" ]] || continue
  nfix=$((nfix + 1))
  b="${f##*/}"
  # Genau das Mock-Format von call_api: Objekt mit choices-Array pro Zeile.
  bad="$(jq -c 'select((type != "object") or ((.choices | type) != "array"))' \
    "$f" 2>/dev/null | head -n1)"
  check "$b (jede Zeile: Objekt mit choices-Array)" \
    "$([[ -z "$bad" ]] && echo 1 || echo 0)" "böse Zeile: $bad"
  # Dynamische Platzhalter gehören nicht in eine Fixture (die Sequenz bleibt
  # dann inline im Test, wo der Wert beim Lauf entsteht).
  if grep -qF '$TMP' "$f"; then
    fail "$b (enthält \$TMP-Platzhalter — dynamische Sequenz gehört ins Testskript)"
  else
    pass "$b (statisch, ohne \$TMP-Platzhalter)"
  fi
done
check "jsonl-Fixtures vorhanden" "$([[ "$nfix" -ge 1 ]] && echo 1 || echo 0)"

gen_manifest > "$TMP/golden.tsv"
if [[ "$UPD" == "1" ]]; then
  cp "$TMP/golden.tsv" "$FIX/golden.tsv"
  pass "golden.tsv aktualisiert ($nfix Zeilen)"
elif [[ ! -f "$FIX/golden.tsv" ]]; then
  fail "golden.tsv fehlt — anlegen mit LEX_GOLDEN_UPDATE=1"
elif cmp -s "$FIX/golden.tsv" "$TMP/golden.tsv"; then
  pass "golden.tsv (Zeilenanzahl & Schlüsselfelder)"
else
  fail "golden.tsv weicht ab" \
    "$(diff -u "$FIX/golden.tsv" "$TMP/golden.tsv" | sed -n '3,8p' | tr '\n' ';')"
fi

# ===========================================================================
# B) _sse_to_response — SSE-Stream bzw. Direkt-JSON → OpenAI-Response
# ===========================================================================
echo "[INFO] B) fixtures/sse (_sse_to_response)"

nsse=0
for s in "$FIX"/sse/*; do
  [[ -e "$s" ]] || continue
  base="${s##*/}"
  # Nur Eingaben — die erzeugten *.golden.* liegen im selben Ordner.
  [[ "$base" == *.golden.* ]] && continue
  nsse=$((nsse + 1))
  out="$TMP/$base.out"
  err="$TMP/$base.err"
  _sse_to_response "$s" > "$out" 2> "$err"
  rc=$?
  gjson="$FIX/sse/$base.golden.json"
  gerr="$FIX/sse/$base.golden.err"

  if (( rc == 0 )); then
    if [[ "$UPD" == "1" ]]; then
      if jq -cS . "$out" > "$gjson" 2>/dev/null; then
        pass "$base → golden.json aktualisiert"
      else
        rm -f "$gjson"
        fail "$base (Antwort nicht als JSON normalisierbar)" "$(head -c 200 "$out")"
      fi
      continue
    fi
    if [[ ! -f "$gjson" ]]; then
      fail "$base (golden.json fehlt)" "anlegen mit LEX_GOLDEN_UPDATE=1"
      continue
    fi
    if ! jq -e . "$out" > /dev/null 2>&1; then
      fail "$base (Ausgabe ist kein JSON)" "$(head -c 200 "$out")"
      continue
    fi
    jq -cS . "$out" > "$out.norm" 2>/dev/null
    if cmp -s "$gjson" "$out.norm"; then
      pass "$base (Response == golden)"
    else
      fail "$base (Response weicht vom Golden ab)" \
        "$(diff -u "$gjson" "$out.norm" | sed -n '3,8p' | tr '\n' ';')"
    fi
  else
    # Fehlerpfad: rc ≠ 0 UND die jq-Meldung sind das Soll (z. B. Serverfehler-
    # Event, Stream ohne data:-Events, Direkt-JSON ohne choices). Die Höhe des
    # Codes wird NICHT gepinnt — jq 1.8 meldet error() mit 5, ältere Versionen
    # teilen das nicht mit; lex prüft nur ≠ 0.
    if [[ "$UPD" == "1" ]]; then
      sed -E 's/^jq: error \(at [^)]*\):[ ]?//' "$err" | head -n1 > "$gerr"
      pass "$base → golden.err aktualisiert (rc=$rc)"
      continue
    fi
    if [[ ! -f "$gerr" ]]; then
      fail "$base (golden.err fehlt, rc=$rc)" "anlegen mit LEX_GOLDEN_UPDATE=1"
      continue
    fi
    want="$(cat "$gerr")"
    if grep -qF -- "$want" "$err"; then
      pass "$base (Fehlerpfad rc=$rc ≠ 0 + Meldung)"
    else
      fail "$base (Fehlermeldung weicht ab)" \
        "erwartet enthalten: $want / stderr: $(head -c 200 "$err")"
    fi
  fi
done
check "sse-Fixtures vorhanden" "$([[ "$nsse" -ge 1 ]] && echo 1 || echo 0)"

# ===========================================================================
# C) _md_render force — Markdown → Terminal-Ausgabe (Farben erzwungen)
# ===========================================================================
echo "[INFO] C) fixtures/md (_md_render force)"

# Umfeld festnageln: NO_COLOR/TERM/LEX_MD_CELL_MAX dürfen die Goldens nicht
# vom aufrufenden Terminal abhängig machen (force umgeht nur die TTY-Prüfung,
# NO_COLOR und TERM=dumb gewinnen auch mit force).
_saved_no_color="${NO_COLOR-__unset__}"
_saved_term="${TERM-__unset__}"
_saved_cell="${LEX_MD_CELL_MAX-__unset__}"
export NO_COLOR=""
export TERM="xterm-256color"
export LEX_MD_CELL_MAX="0"

nmd=0
for m in "$FIX"/md/*.md; do
  [[ -e "$m" ]] || continue
  nmd=$((nmd + 1))
  base="${m##*/}"
  out="$TMP/$base.out"
  _md_render force < "$m" > "$out" 2> "$TMP/$base.err"
  g="$FIX/md/$base.golden.out"
  if [[ "$UPD" == "1" ]]; then
    cp "$out" "$g"
    pass "$base → golden.out aktualisiert"
  elif [[ ! -f "$g" ]]; then
    fail "$base (golden.out fehlt)" "anlegen mit LEX_GOLDEN_UPDATE=1"
  elif cmp -s "$g" "$out"; then
    pass "$base (gerendert == golden)"
  else
    fail "$base (Ausgabe weicht vom Golden ab)" \
      "erste Abweichung: $(cmp -l "$g" "$out" 2>/dev/null | head -n1)"
  fi
done
check "md-Fixtures vorhanden" "$([[ "$nmd" -ge 1 ]] && echo 1 || echo 0)"

# Umfeld wiederherstellen
if [[ "$_saved_no_color" == "__unset__" ]]; then unset NO_COLOR; else export NO_COLOR="$_saved_no_color"; fi
if [[ "$_saved_term" == "__unset__" ]]; then unset TERM; else export TERM="$_saved_term"; fi
if [[ "$_saved_cell" == "__unset__" ]]; then unset LEX_MD_CELL_MAX; else export LEX_MD_CELL_MAX="$_saved_cell"; fi

echo ""
if (( FAIL > 0 )); then
  echo "FEHLSCHLAG: $FAIL Prüfung(en) in test_golden.sh" >&2
  exit 1
fi
echo "test_golden.sh grün. ✓"
exit 0
