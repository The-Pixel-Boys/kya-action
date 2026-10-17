#!/usr/bin/env bash
# Installs @shield-agent/kya@$KYA_VERSION globally. The version comes from env,
# never from ${{ }} interpolation. A version, tag or range is accepted (1.2.3,
# latest, ^0.29); anything with ':' '/' '\' or whitespace is refused so the
# input cannot swap the package for an npm: alias, git, file or URL spec.
set -eu

v="${KYA_VERSION:-latest}"
case "$v" in
  "" | *[:/\\[:space:]]*)
    echo "::error title=kya certify::kya-version must be an npm version, tag or range of @shield-agent/kya (got an unsupported value)."
    exit 1
    ;;
esac

npm i -g "@shield-agent/kya@${v}"
