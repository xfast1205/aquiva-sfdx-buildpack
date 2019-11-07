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

export_env() {
  local env_dir=${1:-$ENV_DIR}
  local whitelist=${2:-''}
  local blacklist="$(_env_blacklist $3)"
  if [ -d "$env_dir" ]; then
    for e in $(ls $env_dir); do
      echo "$e" | grep -E "$whitelist" | grep -qvE "$blacklist" &&
      export "$e=$(cat $env_dir/$e)"
      :
    done
  fi
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