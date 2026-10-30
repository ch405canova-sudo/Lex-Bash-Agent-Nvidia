#!/usr/bin/env bash
#
# lex/test/test_soul.sh — `_soul_ex` (dynamische Persönlichkeits-Datei
# ~/.lex/soul.md) UND die Klassen-Nadel für §6-Bug #57: `_swap_slot0` muss
# ALLE Bausteine aus `setup_messages` überleben lassen (Präferenzen, Skills,
# Wiki, Seele). Fund 2026-10-26: soul.md existierte und behauptete im Kopf,
# lex läd sie — aber `grep soul lex` = 0 Treffer; und der Moduswechsel
# montierte Slot 0 ohne die Präferenzen (Session 20261026-072904: Ton-Regel
# nach `/lexpen on` physisch aus dem Prompt verschwunden).
# NIE echte Requests an 127.0.0.1:8080 — nur LEX_MOCK / LEX_MOCK_FILE.
#
# shellcheck disable=SC1090,SC1111,SC2154  # Quelle wird per Variable geladen;
#                                    # Unicode-Anführungszeichen in deutschen Meldungen;
#                                    # Variablen aus lex sind shellcheck unsichtbar.
#
set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEX_DIR="$(dirname "$SCRIPT_DIR")"
LEX_BIN="$LEX_DIR/lex"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAIL=0

assert() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  [PASS] %s\n' "$desc"
  else
    printf '  [FAIL] %s\n' "$desc" >&2
    printf '         erwartet: %q\n' "$expected" >&2
    printf '         ist:      %q\n' "$actual" >&2
    FAIL=1
  fi
}

contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf '  [PASS] %s\n' "$desc"
  else
    printf '  [FAIL] %s\n' "$desc" >&2
    printf '         fehlt: %q\n' "$needle" >&2
    FAIL=1
  fi
}

notcontains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf '  [PASS] %s\n' "$desc"
  else
    printf '  [FAIL] %s\n' "$desc" >&2
    printf '         darf nicht vorkommen: %q\n' "$needle" >&2
    FAIL=1
  fi
}

# --- Fixtur: isoliertes LEX_HOME, stdin=/dev/null (REPL-Pfad bricht ab) -----
export LEX_HOME="$TMP"
export LEX_MODEL="$TMP/model.gguf"
export LEX_MEM_DIR="$TMP/mem"
export LEX_WIKI_DIR="$TMP/wiki"
export LEX_SESSION=0
source "$LEX_BIN" < /dev/null > /dev/null 2>&1 || {
  echo "FEHLSCHLAG: $LEX_BIN nicht ladbar (Syntax-/Bash-Fehler)" >&2
  exit 1
}
load_config || { echo "FEHLSCHLAG: load_config" >&2; exit 1; }

mkdir -p "$LEX_MEM_DIR" "$LEX_WIKI_DIR" "${_lex_home}/skills/testskill"

# Marker, die nur über die INJEKTION in den Prompt gelangen können —
# identische Prüfung wie in test_mem_pref.sh (NEUESTE Präferenz).
mkmem() {  # $1 = Dateiname, $2 = type, $3 = Inhalt
  printf -- '---\ndate: 2026-01-03T00:00:00+0200\ntype: %s\nslug: %s\n---\n\n%s\n' \
    "$2" "${1%.md}" "$3" > "$LEX_MEM_DIR/$1"
}
mkmem "20260103000001-a-aeltere.md"  preference "AELTERE Präferenz"
mkmem "20260103000002-b-neueste.md"  preference "NEUESTE Präferenz"

# Ein Skill-Marker: beweist, dass `_skills_ex` mit in den Wechsel muss.
printf -- '---\nname: testskill\ndescription: Test-Skill\n---\n\nSKILL_MARKER_TEST\n' \
  > "${_lex_home}/skills/testskill/SKILL.md"

# ══ 1. Basis-Gate: fehlend/leer = Ausgabe leer, Prompt unverändert ═════════
out="$(_soul_ex)"
assert "soul.md fehlt → _soul_ex gibt nichts aus" "" "$out"

: > "${_lex_home}/soul.md"          # leer
out="$(_soul_ex)"
assert "soul.md leer → _soul_ex gibt nichts aus" "" "$out"

printf '   \n\t\n' > "${_lex_home}/soul.md"   # nur Whitespace
out="$(_soul_ex)"
assert "soul.md nur Whitespace → _soul_ex gibt nichts aus" "" "$out"

# ══ 2. Inhalt: Kopf + Geltungssatz + Body ══════════════════════════════════
printf '# MEINE SEELE\n\nSOUL_MARKER_CONTENT\n' > "${_lex_home}/soul.md"
out="$(_soul_ex)"
contains "Kopf nennt den dynamischen Pfad" "# — Seele (dynamisch: ${_lex_home}/soul.md," "$out"
contains "Geltungssatz: gilt in ALLEN Modi" "Gilt in ALLEN Modi" "$out"
contains "Body landet im Block" "SOUL_MARKER_CONTENT" "$out"
contains "Überschrift aus soul.md landet im Block" "# MEINE SEELE" "$out"

# stdout ist ausschließlich der Block (kein Rauschen auf stderr/stdout davor)
rc=0; out="$(_soul_ex 2>"$TMP/err")" || rc=$?
assert "rc bei vorhandener soul.md" "0" "$rc"
assert "stderr ist leer" "" "$(cat "$TMP/err")"

# ══ 3. Reihenfolge: Seele ganz hinten (höchste Stil-Rang) ══════════════════
_mem_dir="$LEX_MEM_DIR"
LEX_SESSION=0 setup_messages >/dev/null 2>&1
sys="$(printf '%s' "$_messages" | jq -r '.[0].content' 2>/dev/null)"
contains "setup_messages: Seele landet im System-Prompt" "SOUL_MARKER_CONTENT" "$sys"
contains "setup_messages: Präferenz landet weiterhin im Prompt" "NEUESTE Präferenz" "$sys"
contains "setup_messages: Skill landet weiterhin im Prompt" "SKILL_MARKER_TEST" "$sys"
# Byte-Offsets: Seele MUSS nach Präferenz UND Skill kommen (höchste Rang).
soul_pos="$(printf '%s' "$sys" | grep -b -o 'SOUL_MARKER_CONTENT' | head -1 | cut -d: -f1)"
pref_pos="$(printf '%s' "$sys" | grep -b -o 'NEUESTE Präferenz' | head -1 | cut -d: -f1)"
skill_pos="$(printf '%s' "$sys" | grep -b -o 'SKILL_MARKER_TEST' | head -1 | cut -d: -f1)"
contains "Seele steht NACH der Präferenz (höchster Rang)" "1" \
  "$([[ -n "$soul_pos" && -n "$pref_pos" && "$soul_pos" -gt "$pref_pos" ]] && echo 1 || echo 0)"
contains "Seele steht NACH dem Skill (höchster Rang)" "1" \
  "$([[ -n "$soul_pos" && -n "$skill_pos" && "$soul_pos" -gt "$skill_pos" ]] && echo 1 || echo 0)"

# ══ 4. KLASSEN-NADEL (#57): _swap_slot0 montiert ALLES neu ═════════════════
# Der Wechsel simuliert `/lexpen on`: Slot 0 wird FRISCH montiert. Vor dem
# Fix montierte `_swap_slot0` nur Basis+Skills+Wiki — die Präferenzen fielen
# still raus (Session 20261026-072904: Ton-Regel nach /lexpen physisch weg)
# und die Seele fehlte, weil ihr Loader tot war. Diese Nadel prüft die
# KLASSE: Slot 0 startet MINIMAL (nur Basis) und MUSS nach dem Wechsel
# Präferenz + Skill + Seele enthalten — derselbe Stapel wie in setup_messages.
_mem_dir="$LEX_MEM_DIR"
minimal='[{"role":"system","content":"NUR_BASIS_PROMPT"},{"role":"user","content":"hi"}]'
printf '%s' "$minimal" > "$TMP/msgs_before.json"
_messages="$minimal"
_swap_slot0 default >/dev/null 2>&1
swapped="$(printf '%s' "$_messages" | jq -r '.[0].content' 2>/dev/null)"
contains "_swap_slot0: Präferenz landet im gewechselten Slot 0 (Bug #57)" "NEUESTE Präferenz" "$swapped"
contains "_swap_slot0: Skill landet im gewechselten Slot 0" "SKILL_MARKER_TEST" "$swapped"
contains "_swap_slot0: Seele landet im gewechselten Slot 0" "SOUL_MARKER_CONTENT" "$swapped"
notcontains "_swap_slot0: der minimale Platzhalter ist ersetzt" "NUR_BASIS_PROMPT" "$swapped"
# Byte-Offsets auch hier: Seele bleibt höchste Rang nach dem Wechsel.
soul_pos2="$(printf '%s' "$swapped" | grep -b -o 'SOUL_MARKER_CONTENT' | head -1 | cut -d: -f1)"
pref_pos2="$(printf '%s' "$swapped" | grep -b -o 'NEUESTE Präferenz' | head -1 | cut -d: -f1)"
contains "_swap_slot0: Seele steht NACH der Präferenz" "1" \
  "$([[ -n "$soul_pos2" && -n "$pref_pos2" && "$soul_pos2" -gt "$pref_pos2" ]] && echo 1 || echo 0)"
# Der Wechsel darf die Nachrichten-Kette nicht zerstören (Rollen bleiben).
assert "_swap_slot0: Nachrichtenanzahl bleibt" \
  "$(jq 'length' < "$TMP/msgs_before.json")" \
  "$(printf '%s' "$_messages" | jq 'length')"
assert "_swap_slot0: Rollen unverändert" \
  "$(jq -c '[.[].role]' < "$TMP/msgs_before.json")" \
  "$(printf '%s' "$_messages" | jq -c '[.[].role]')"
assert "_swap_slot0: Slot 0 bleibt die system-Rolle" "system" \
  "$(printf '%s' "$_messages" | jq -r '.[0].role' 2>/dev/null)"

# ══ 5. --status-Zeile ══════════════════════════════════════════════════════
printf '# MEINE SEELE\n\nSOUL_MARKER_CONTENT\n' > "${_lex_home}/soul.md"
status_out="$(LEX_SESSION=0 cmd_status 2>/dev/null)"
contains "status: soul-Zeile nennt Pfad" "soul      : ${_lex_home}/soul.md" "$status_out"
contains "status: soul-Zeile meldet Zeilen + dynamisch" "Zeilen, dynamisch" "$status_out"

rm -f "${_lex_home}/soul.md"
status_out="$(LEX_SESSION=0 cmd_status 2>/dev/null)"
contains "status: fehlende soul.md wird als fehlt gemeldet" "fehlt — editierbare Persönlichkeits-Datei" "$status_out"

# ══ 6. stdout-Isolation von setup_messages (Block ist alles) ═══════════════
printf '# MEINE SEELE\n\nSOUL_MARKER_CONTENT\n' > "${_lex_home}/soul.md"
_mem_dir="$LEX_MEM_DIR"
LEX_SESSION=0 setup_messages >/dev/null 2>&1
sys="$(printf '%s' "$_messages" | jq -r '.[0].content' 2>/dev/null)"
contains "Seele steht im Slot 0 (system), nicht in einer späteren Nachricht" "SOUL_MARKER_CONTENT" "$sys"
assert "Slot 0 ist system" "system" \
  "$(printf '%s' "$_messages" | jq -r '.[0].role' 2>/dev/null)"

printf '\n%s\n' "$([[ $FAIL -eq 0 ]] && echo 'SOUL: alle Nadeln grün' || echo 'SOUL: Nadeln gefallen')"
exit "$FAIL"
