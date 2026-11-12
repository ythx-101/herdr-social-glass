#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "unexpected path exists: $1"
}

export HOME="$TEST_ROOT/home"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_PLUGIN_CONFIG_DIR="$TEST_ROOT/plugin-config"
export HERDR_PLUGIN_STATE_DIR="$TEST_ROOT/plugin-state"
export HERDR_CONFIG_PATH="$TEST_ROOT/herdr/config.toml"
export HERDR_BIN_PATH="$TEST_ROOT/bin/herdr"
mkdir -p "$HOME" "$HERDR_PLUGIN_CONFIG_DIR" "$(dirname "$HERDR_CONFIG_PATH")" "$(dirname "$HERDR_BIN_PATH")"

cat > "$HERDR_BIN_PATH" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_HERDR_LOG:?}"
if [[ "${1:-}" == "--version" ]]; then
  echo 'herdr 0.8.2-test'
  exit 0
fi
if [[ "${1:-}" == "server" && "${2:-}" == "reload-config" && "${MOCK_HERDR_FAIL_NEXT:-0}" == 1 && ! -e "${MOCK_HERDR_FAIL_MARKER:?}" ]]; then
  : > "$MOCK_HERDR_FAIL_MARKER"
  exit 1
fi
MOCK
chmod +x "$HERDR_BIN_PATH"
export MOCK_HERDR_LOG="$TEST_ROOT/herdr-calls.log"
export MOCK_HERDR_FAIL_MARKER="$TEST_ROOT/fail-next.marker"
: > "$MOCK_HERDR_LOG"

ORIGINAL='# original Herdr config
onboarding = true
'
printf '%s' "$ORIGINAL" > "$HERDR_CONFIG_PATH"
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/original.toml"

# Treat the local title as data, including shell syntax, quotes, and backslashes.
TITLE='QingYue "literal" \\ $(touch should-never-exist)'
printf '%s\n' "$TITLE" > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
(
  cd "$TEST_ROOT"
  bash "$ROOT/scripts/apply.sh"
)
assert_not_exists "$TEST_ROOT/should-never-exist"
python3 - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == sys.argv[2]
PY
cmp -s "$TEST_ROOT/original.toml" "$HERDR_PLUGIN_STATE_DIR/baseline-config.toml" || fail 'baseline was not preserved'
[[ "$(stat -c '%a' "$HERDR_CONFIG_PATH" 2>/dev/null || stat -f '%Lp' "$HERDR_CONFIG_PATH")" == 600 ]] || fail 'active config mode is not 600'
assert_contains "$MOCK_HERDR_LOG" 'server reload-config'
assert_contains "$MOCK_HERDR_LOG" 'config check'

SOCIAL_STATUS="$TEST_ROOT/social-status.txt"
bash "$ROOT/scripts/status.sh" > "$SOCIAL_STATUS"
assert_contains "$SOCIAL_STATUS" 'State:   social-glass'

bash "$ROOT/scripts/apply-island.sh"
ISLAND_STATUS="$TEST_ROOT/island-status.txt"
bash "$ROOT/scripts/status.sh" > "$ISLAND_STATUS"
assert_contains "$ISLAND_STATUS" 'State:   island-glass'
python3 - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == sys.argv[2]
assert config["theme"]["custom"]["sidebar_bg"] == "#F1EAD8"
PY

# A reload failure must restore the exact immediate predecessor and reload it.
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/before-failed-apply.toml"
rm -f "$MOCK_HERDR_FAIL_MARKER"
export MOCK_HERDR_FAIL_NEXT=1
if bash "$ROOT/scripts/apply.sh" > "$TEST_ROOT/failed-apply.out" 2> "$TEST_ROOT/failed-apply.err"; then
  fail 'apply unexpectedly succeeded when reload failed'
fi
unset MOCK_HERDR_FAIL_NEXT
cmp -s "$TEST_ROOT/before-failed-apply.toml" "$HERDR_CONFIG_PATH" || fail 'reload failure did not restore immediate backup'
assert_contains "$TEST_ROOT/failed-apply.err" 'previous config restored'
[[ "$(grep -c '^server reload-config$' "$MOCK_HERDR_LOG")" -ge 4 ]] || fail 'rollback reload was not attempted'

# Invalid local titles must fail closed without touching config or invoking Herdr.
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/before-invalid-title.toml"
CALLS_BEFORE="$(wc -l < "$MOCK_HERDR_LOG" | tr -d ' ')"
printf 'bad\ttitle\n' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
if bash "$ROOT/scripts/apply.sh" > /dev/null 2> "$TEST_ROOT/control-title.err"; then
  fail 'control-character title was accepted'
fi
assert_contains "$TEST_ROOT/control-title.err" 'window title'
cmp -s "$TEST_ROOT/before-invalid-title.toml" "$HERDR_CONFIG_PATH" || fail 'invalid title changed config'
[[ "$(wc -l < "$MOCK_HERDR_LOG" | tr -d ' ')" == "$CALLS_BEFORE" ]] || fail 'invalid title invoked Herdr'

python3 - <<'PY' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
print("x" * 121)
PY
if bash "$ROOT/scripts/apply-island.sh" > /dev/null 2> "$TEST_ROOT/long-title.err"; then
  fail 'overlong title was accepted'
fi
assert_contains "$TEST_ROOT/long-title.err" 'window title'
cmp -s "$TEST_ROOT/before-invalid-title.toml" "$HERDR_CONFIG_PATH" || fail 'overlong title changed config'

# Without local personalization, applying a public preset keeps its generic title.
mv "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt" "$TEST_ROOT/window-title.disabled"
bash "$ROOT/scripts/apply-island.sh" > "$TEST_ROOT/generic-apply.out"
python3 - "$HERDR_CONFIG_PATH" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == "Herdr Island Glass"
PY
mv "$TEST_ROOT/window-title.disabled" "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"

# Restore must return the first pre-theme baseline, not a later variant.
printf '%s\n' 'Restored title' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
bash "$ROOT/scripts/restore.sh"
cmp -s "$TEST_ROOT/original.toml" "$HERDR_CONFIG_PATH" || fail 'restore did not recover original baseline'
RESTORE_BACKUPS=("$HERDR_PLUGIN_STATE_DIR"/backups/before-restore-*.toml)
[[ -f "${RESTORE_BACKUPS[0]}" ]] || fail 'restore did not write a before-restore backup'
[[ "$(stat -c '%a' "${RESTORE_BACKUPS[0]}" 2>/dev/null || stat -f '%Lp' "${RESTORE_BACKUPS[0]}")" == 600 ]] || fail 'before-restore backup mode is not 600'

printf 'local_marker = true\n' >> "$HERDR_CONFIG_PATH"
MODIFIED_STATUS="$TEST_ROOT/modified-status.txt"
bash "$ROOT/scripts/status.sh" > "$MODIFIED_STATUS"
assert_contains "$MODIFIED_STATUS" 'State:   not applied or locally modified'

# The Island launcher adds per-window OSC 10/11 defaults; Social adds none.
cat > "$TEST_ROOT/bin/osascript" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${MOCK_OSASCRIPT_ARGS:?}"
cp /dev/stdin "${MOCK_OSASCRIPT_STDIN:?}"
MOCK_OSASCRIPT
chmod +x "$TEST_ROOT/bin/osascript"
export PATH="$TEST_ROOT/bin:$PATH"
export MOCK_OSASCRIPT_ARGS="$TEST_ROOT/osascript.args"
export MOCK_OSASCRIPT_STDIN="$TEST_ROOT/osascript.stdin"

bash "$ROOT/scripts/open-island-window.sh" > /dev/null
assert_contains "$MOCK_OSASCRIPT_ARGS" '#5B4636'
assert_contains "$MOCK_OSASCRIPT_ARGS" '#F8F4E8'
assert_contains "$MOCK_OSASCRIPT_STDIN" "\\\\033]10;%s\\\\007"
assert_contains "$MOCK_OSASCRIPT_STDIN" "\\\\033]11;%s\\\\007"

SOCIAL_ARGS="$TEST_ROOT/social-osascript.args"
SOCIAL_STDIN="$TEST_ROOT/social-osascript.stdin"
MOCK_OSASCRIPT_ARGS="$SOCIAL_ARGS" MOCK_OSASCRIPT_STDIN="$SOCIAL_STDIN" bash "$ROOT/scripts/open-social-window.sh" > /dev/null
[[ "$(wc -l < "$SOCIAL_ARGS" | tr -d ' ')" == 4 ]] || fail 'Social launcher gained Island color arguments'

cp "$MOCK_OSASCRIPT_ARGS" "$TEST_ROOT/island-valid.args"
if HERDR_ISLAND_FOREGROUND='#12345;bad' bash "$ROOT/scripts/open-island-window.sh" > /dev/null 2> "$TEST_ROOT/invalid-color.err"; then
  fail 'invalid Island foreground was accepted'
fi
assert_contains "$TEST_ROOT/invalid-color.err" 'Invalid Island foreground color'
cmp -s "$TEST_ROOT/island-valid.args" "$MOCK_OSASCRIPT_ARGS" || fail 'invalid color reached osascript'

if HERDR_ISLAND_BACKGROUND='rgb(1,2,3)' bash "$ROOT/scripts/open-island-window.sh" > /dev/null 2> "$TEST_ROOT/invalid-background.err"; then
  fail 'invalid Island background was accepted'
fi
assert_contains "$TEST_ROOT/invalid-background.err" 'Invalid Island background color'
cmp -s "$TEST_ROOT/island-valid.args" "$MOCK_OSASCRIPT_ARGS" || fail 'invalid background reached osascript'

# Without herdr on PATH, the launcher must fail loudly and never reach osascript.
mkdir -p "$TEST_ROOT/osabin"
cp "$TEST_ROOT/bin/osascript" "$TEST_ROOT/osabin/osascript"
if PATH="$TEST_ROOT/osabin:/usr/bin:/bin" command -v herdr > /dev/null 2>&1; then
  printf 'skipping missing-herdr check: herdr found in /usr/bin or /bin\n'
else
  : > "$TEST_ROOT/missing-herdr.args"
  if /usr/bin/env -u HERDR_BIN_PATH PATH="$TEST_ROOT/osabin:/usr/bin:/bin" MOCK_OSASCRIPT_ARGS="$TEST_ROOT/missing-herdr.args" bash "$ROOT/scripts/open-social-window.sh" > /dev/null 2> "$TEST_ROOT/missing-herdr.err"; then
    fail 'launcher succeeded without herdr'
  fi
  assert_contains "$TEST_ROOT/missing-herdr.err" 'herdr was not found'
  [[ ! -s "$TEST_ROOT/missing-herdr.args" ]] || fail 'osascript was invoked without herdr'
fi

if find "$(dirname "$HERDR_CONFIG_PATH")" -maxdepth 1 -type f \( -name '*.social-glass.*' -o -name '*.island-glass.*' \) | grep -q .; then
  fail 'temporary config file was left behind'
fi

printf 'functional tests passed\n'
