#!/usr/bin/env bash
# Tests for scripts/certify.sh and scripts/install.sh. Run: bash tests/run.sh
# Stub cases put a fake `kya` first on PATH. Real-CLI cases need the published
# @shield-agent/kya on PATH (npm i -g @shield-agent/kya) and are skipped
# without it unless REQUIRE_REAL_KYA=1.
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
certify="$here/scripts/certify.sh"
install="$here/scripts/install.sh"
real_kya="$(command -v kya || true)"
real_dir=""
if [ -n "$real_kya" ]; then real_dir="$(cd "$(dirname "$real_kya")" && pwd)"; fi
base="$(mktemp -d)"
trap 'rm -rf "$base"' EXIT
fails=0
n=0

SECRET="runner-secret-$$"

# new_case <name>: fresh workspace, output file, outside dir with a sentinel.
new_case() {
  n=$((n + 1))
  c="$base/$n"
  mkdir -p "$c/ws" "$c/outside" "$c/stub"
  ws="$(cd "$c/ws" && pwd -P)"
  outside="$(cd "$c/outside" && pwd -P)"
  printf '%s\n' "$SECRET" > "$outside/secret.txt"
  : > "$c/out"
  echo "--- $1"
}

# run_certify [extra PATH prefix]: runs certify.sh in $ws, sets rc and log.
run_certify() {
  local path="$PATH"
  if [ -n "${1:-}" ]; then path="$1:$PATH"; fi
  (cd "$ws" && PATH="$path" GITHUB_WORKSPACE="$ws" GITHUB_OUTPUT="$c/out" RUNNER_TEMP="$c" \
    KYA_WINDOW_DAYS=30 KYA_FAIL_ON="${FAIL_ON:-gap}" bash "$certify") > "$c/log" 2>&1
  rc=$?
}

out_val() { sed -n "s/^$1=//p" "$c/out" | tail -n 1; }

expect() { # description actual expected
  if [ "$2" = "$3" ]; then
    echo "  ok: $1"
  else
    echo "  FAIL: $1 (got '$2', want '$3')"
    sed 's/^/    | /' "$c/log"
    fails=$((fails + 1))
  fi
}

stub() { # body of the fake kya
  printf '#!/usr/bin/env bash\n%s\n' "$1" > "$c/stub/kya"
  chmod +x "$c/stub/kya"
}

untouched() { # the outside dir still holds only the unchanged sentinel
  expect "outside secret unchanged" "$(cat "$outside/secret.txt")" "$SECRET"
  expect "nothing written outside" "$(ls -A "$outside")" "secret.txt"
  if grep -q "$SECRET" "$c/log" "$c/out"; then
    expect "secret not read into output" "leaked" "not leaked"
  fi
}

# ---------- stub CLI (simulates kya behaviour) ----------

new_case "stub: CLI refusal (PROJECT_PATH_REFUSED, exit 1) is error, not gap"
stub 'echo "error: refusing to write outside the project [PROJECT_PATH_REFUSED]" >&2; exit 1'
mkdir -p "$ws/.kya/certify" && echo '{"stale":true}' > "$ws/.kya/certify/report.json"
run_certify "$c/stub"
expect "status" "$(out_val status)" "error"
expect "exit-code" "$(out_val exit-code)" "1"
expect "report-path empty" "$(out_val report-path)" ""
expect "step fails" "$rc" "1"
expect "annotation" "$(grep -c '::error title=kya certify::.*PROJECT_PATH_REFUSED' "$c/log")" "1"

new_case "stub: plain exit 1 stays gap"
stub 'mkdir -p .kya/certify; echo "{}" > .kya/certify/report.json; exit 1'
run_certify "$c/stub"
expect "status" "$(out_val status)" "gap"
expect "exit-code" "$(out_val exit-code)" "1"
expect "report-path" "$(out_val report-path)" "$ws/.kya/certify/report.json"
expect "step exit" "$rc" "1"

new_case "stub: exit 0 is pass"
stub 'mkdir -p .kya/certify; echo "{}" > .kya/certify/report.json; exit 0'
run_certify "$c/stub"
expect "status" "$(out_val status)" "pass"
expect "exit-code" "$(out_val exit-code)" "0"
expect "step exit" "$rc" "0"

new_case "stub: exit 2 is error"
stub 'echo "error: --fail-on must be gap or never [USAGE]" >&2; exit 2'
run_certify "$c/stub"
expect "status" "$(out_val status)" "error"
expect "exit-code" "$(out_val exit-code)" "2"
expect "step exit" "$rc" "2"

new_case "stub: report.json turned into an outside link during the run is not read"
stub "mkdir -p .kya/certify; ln -s '$c/outside/secret.txt' .kya/certify/report.json; exit 0"
run_certify "$c/stub"
expect "status" "$(out_val status)" "error"
expect "exit-code" "$(out_val exit-code)" "0"
expect "report-path empty" "$(out_val report-path)" ""
expect "step fails" "$rc" "1"
untouched

new_case "stub: workflow commands in CLI output are fenced by stop-commands"
stub 'echo "::warning::from-cli"; exit 0'
run_certify "$c/stub"
token="$(sed -n 's/^::stop-commands::\(.*\)$/\1/p' "$c/log")"
expect "stop-commands token emitted" "$([ -n "$token" ] && echo yes)" "yes"
expect "resume after CLI output" "$(tail -n 1 "$c/log")" "::${token}::"

new_case "pre-run: symlinked .kya is refused without running the CLI"
stub 'echo ran > "$GITHUB_WORKSPACE/../ran"; exit 0'
ln -s "$outside" "$ws/.kya"
run_certify "$c/stub"
expect "status" "$(out_val status)" "error"
expect "exit-code empty (not run)" "$(out_val exit-code)" ""
expect "CLI not invoked" "$([ -e "$c/ran" ] && echo ran || echo not-run)" "not-run"
expect "step fails" "$rc" "1"
untouched

# ---------- install.sh input validation ----------

for bad in "npm:evil-pkg@1.0.0" "github:someone/repo" "git+https://example.com/x.git" "file:../x" "someone/repo" "1.0.0 --registry=x"; do
  new_case "install: refuses kya-version '$bad'"
  printf '#!/usr/bin/env bash\necho called > "%s/npm-called"\n' "$c" > "$c/stub/npm"
  chmod +x "$c/stub/npm"
  (PATH="$c/stub:$PATH" KYA_VERSION="$bad" bash "$install") > "$c/log" 2>&1
  expect "exit" "$?" "1"
  expect "npm not called" "$([ -e "$c/npm-called" ] && echo called || echo no)" "no"
done

new_case "install: passes a plain version through to npm"
printf '#!/usr/bin/env bash\necho "$@" > "%s/args"\n' "$c" > "$c/stub/npm"
chmod +x "$c/stub/npm"
(PATH="$c/stub:$PATH" KYA_VERSION="^0.29" bash "$install") > "$c/log" 2>&1
expect "exit" "$?" "0"
expect "npm args" "$(cat "$c/args")" "i -g @shield-agent/kya@^0.29"

# ---------- real published CLI ----------

if [ -z "$real_kya" ]; then
  if [ "${REQUIRE_REAL_KYA:-0}" = "1" ]; then
    echo "FAIL: REQUIRE_REAL_KYA=1 but kya is not on PATH"
    fails=$((fails + 1))
  else
    echo "--- real CLI cases skipped (kya not on PATH)"
  fi
else
  echo "--- real CLI at $real_dir/kya"

  new_case "real: clean checkout reports gap with a readable report"
  run_certify "$real_dir"
  expect "status" "$(out_val status)" "gap"
  expect "exit-code" "$(out_val exit-code)" "1"
  expect "report-path" "$(out_val report-path)" "$ws/.kya/certify/report.json"

  new_case "real: fail-on never reports pass"
  FAIL_ON=never run_certify "$real_dir"
  expect "status" "$(out_val status)" "pass"
  expect "exit-code" "$(out_val exit-code)" "0"

  new_case "real: .kya symlinked outside is error, CLI never writes or reads through it"
  ln -s "$outside" "$ws/.kya"
  run_certify "$real_dir"
  expect "status" "$(out_val status)" "error"
  expect "report-path empty" "$(out_val report-path)" ""
  expect "step fails" "$rc" "1"
  untouched

  new_case "real: .kya/certify/report.json symlinked to a runner file is error, not read"
  mkdir -p "$ws/.kya/certify"
  ln -s "$outside/secret.txt" "$ws/.kya/certify/report.json"
  run_certify "$real_dir"
  expect "status" "$(out_val status)" "error"
  expect "report-path empty" "$(out_val report-path)" ""
  untouched

  new_case "real: .kya/certify symlinked outside is error"
  mkdir -p "$ws/.kya"
  ln -s "$outside" "$ws/.kya/certify"
  run_certify "$real_dir"
  expect "status" "$(out_val status)" "error"
  untouched
fi

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails check(s) failed"; exit 1; fi
