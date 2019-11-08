#!/usr/bin/env bash
# export helper functions for aquiva buildpack

header() {
  echo "" || true
  echo -e "-----> \e[34m$*\033[0m" || true
  echo "" || true
}

log() {
  echo -e "       $*"
}

debug() {
  if [ "$SFDX_BUILDPACK_DEBUG" == "true" ] ; then
    echo "       [DEBUG] $*"
  fi
}

setup_dirs() {
  local DIR="$1"
  export PATH="$DIR/vendor/sfdx/cli/bin:$PATH"
}