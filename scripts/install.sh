#!/usr/bin/env bash
# Installs @shield-agent/kya@$KYA_VERSION globally. The version comes from env,
# never from ${{ }} interpolation. Only an npm version, dist-tag or range is
# accepted (latest, next, 0.29.0, 0.29.0-rc.1, ^0.29, ~0.29.1, >=0.28, 0.x, *).
# The allowlist keeps out npm: aliases, git, URL, directory (., .., .hidden)
# and tarball (x.tgz, x.tar) specs, which npm would resolve against the PR
# checkout. npm runs from RUNNER_TEMP with --ignore-scripts as a second fence.
set -eu

v="${KYA_VERSION:-latest}"
re='^[0-9A-Za-z^~*<>=][0-9A-Za-z.+^~*<>=|-]*$'
ok=1
[[ "$v" =~ $re ]] || ok=0
# npm matches tarball suffixes case-insensitively (x.TGZ, x.Tar).
shopt -s nocasematch
case "$v" in
  *.tgz | *.tar | *.tar.gz | .*) ok=0 ;;
esac
shopt -u nocasematch
if [ "$ok" -ne 1 ]; then
  echo "::error title=kya certify::kya-version must be an npm version, dist-tag or range of @shield-agent/kya (got an unsupported value)."
  exit 1
fi

cd "${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
npm i -g --ignore-scripts "@shield-agent/kya@${v}"
