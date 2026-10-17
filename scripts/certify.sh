#!/usr/bin/env bash
# Runs `kya certify` for the composite action and writes exit-code, status and
# report-path to $GITHUB_OUTPUT.
#
# Inputs come only from env (KYA_WINDOW_DAYS, KYA_FAIL_ON), never from ${{ }}
# interpolation, because a workflow may feed them from PR data.
#
# Exit-code mapping: 0 -> pass, 1 -> gap, anything else -> error. Two cases
# override it to error:
#   - the CLI refused a write that leaves the project (stderr has
#     PROJECT_PATH_REFUSED, kya newer than 0.29.0), or
#   - .kya, .kya/certify or .kya/certify/report.json is a symlink or resolves
#     outside the workspace (checked before and after the run, so a PR
#     checkout cannot point the CLI or the PR comment at runner files).
set -u

ws="${GITHUB_WORKSPACE:-$PWD}"
out="${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
report_rel=".kya/certify/report.json"

# Prints a reason and returns 1 when a report path component is unsafe.
check_paths() {
  local ws_real p rp
  ws_real="$(realpath "$ws")" || { echo "cannot resolve the workspace"; return 1; }
  for p in .kya .kya/certify "$report_rel"; do
    if [ -L "$ws/$p" ]; then
      echo "$p is a symlink"
      return 1
    fi
    [ -e "$ws/$p" ] || continue
    rp="$(realpath "$ws/$p")" || { echo "cannot resolve $p"; return 1; }
    case "$rp" in
      "$ws_real"/*) ;;
      *) echo "$p resolves outside the workspace"; return 1 ;;
    esac
  done
  return 0
}

finish() { # status exit-code report-path reason
  {
    echo "exit-code=$2"
    echo "status=$1"
    echo "report-path=$3"
  } >> "$out"
  if [ "$1" = "error" ]; then
    echo "::error title=kya certify::$4"
    if [ -n "$2" ] && [ "$2" -ne 0 ]; then exit "$2"; fi
    exit 1
  fi
  exit "$2"
}

if ! reason="$(check_paths)"; then
  finish error "" "" "Refusing to run kya certify: $reason. Replace the link with a regular directory or file. This is an error, not a certify gap."
fi

errf="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/kya-certify-stderr.XXXXXX")"
trap 'rm -f "$errf"' EXIT

# CLI output can echo repository content; stop workflow-command processing
# while it prints so a crafted line cannot run ::set-output:: and friends.
token="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
echo "::stop-commands::${token}"
kya certify --window "${KYA_WINDOW_DAYS:-30}" --fail-on "${KYA_FAIL_ON:-gap}" --json 2>"$errf"
code=$?
cat "$errf" >&2
echo "::${token}::"

if grep -q "PROJECT_PATH_REFUSED" "$errf"; then
  finish error "$code" "" "kya certify refused to write through a symlink that leaves the project (PROJECT_PATH_REFUSED). Replace the link with a regular directory or file. This is an error, not a certify gap."
fi

case "$code" in
  0) status=pass ;;
  1) status=gap ;;
  *) finish error "$code" "" "kya certify exited with code $code." ;;
esac

if ! reason="$(check_paths)"; then
  finish error "$code" "" "Not reading the certify report: $reason. This is an error, not a certify gap."
fi

report=""
if [ -f "$ws/$report_rel" ]; then report="$ws/$report_rel"; fi
finish "$status" "$code" "$report" ""
