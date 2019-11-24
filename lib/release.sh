#!/usr/bin/env bash

START_TIME=$SECONDS

# set -x
set -o errexit      # always exit on error
set -o pipefail     # don't ignore exit codes when piping output

DEV_HUB_SESSION_ID=${1:-}
SFDX_PACKAGE_VERSION_ID=${2:-}
STAGING_SF_URL=${3:-}
STAGING_SESSION_ID=${4:-}
BUILD_DIR=${5:-}
# DEV_HUB_INSTANCE_URL=${6:-}
ls -la
# Import dependencies

source $BUILD_DIR/lib/lib.sh
source $BUILD_DIR/lib/deps.sh
source $BUILD_DIR/lib/sfdc.sh

header "Running release.sh ..."

promote_package() {
  log "Promote package ..."

  sfdx force:package:version:promote \
    -p $1 \
    -v $2 \
    -n

  prepare_sfdc_environment \
    "$STAGING_SF_URL" \
    "$STAGING_SESSION_ID"

  sfdx force:package:install \
  -p $1 \
  -u $3 \
  -w 10 \
  --publishwait 10 \
  -n

}

promote_package \
  "$SFDX_PACKAGE_VERSION_ID" \
  "$DEV_HUB_SESSION_ID" \
  "$STAGING_SESSION_ID"

header "DONE! Completed in $(($SECONDS - $START_TIME))s"
exit 0
