#!/usr/bin/env bash

START_TIME=$SECONDS

# set -x
set -o errexit      # always exit on error
set -o pipefail     # don't ignore exit codes when piping output
unset GIT_DIR       # Avoid GIT_DIR leak from previous build steps

DEV_HUB_USERNAME=${1:-}
SFDX_PACKAGE_VERSION_ID=${2:-}
STAGING_SF_URL=${3:-}
STAGING_SESSION_ID=${4:-}

vendorDir="vendor/sfdx"

# Import dependencies

source $BP_DIR/lib/lib.sh
source $BP_DIR/lib/deps.sh
source $BP_DIR/lib/sfdc.sh

header "Running release.sh"

# Prepare environment

setup_dirs() {
  export PATH="$BUILD_DIR/vendor/sfdx/cli/bin:$PATH"
  export PATH="$BUILD_DIR/vendor/sfdx/jq:$PATH"
}

export_env_dir() {
  if [ -d "$ENV_DIR" ]; then
    for e in $(ls $ENV_DIR); do
      export $e=$(cat $ENV_DIR/$e)
      :
    done
  fi
}

promote_package() {
  log "Promote package ..."

  VERSION_NUMBER=$(get_package_version $1 $2)

  PACKAGE_VERSION_ID="$(eval sfdx force:package:version:create -p $1 --versionnumber $VERSION_NUMBER --installationkeybypass -v $2 --wait 100 --json |
    jq -r '.result.SubscriberPackageVersionId')"
}

header "DONE! Completed in $(($SECONDS - $START_TIME))s"
exit 0
