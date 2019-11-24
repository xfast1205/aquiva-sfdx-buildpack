#!/usr/bin/env bash

START_TIME=$SECONDS

# set -x
set -o errexit      # always exit on error
set -o pipefail     # don't ignore exit codes when piping output

DEV_HUB_SESSION_ID=${1:-}
SFDX_PACKAGE_VERSION_ID=${2:-}
STAGING_SF_URL=${3:-}
STAGING_SESSION_ID=${4:-}
BP_DIR="."
# DEV_HUB_INSTANCE_URL=${6:-}

# Import dependencies

source lib/lib.sh
source lib/deps.sh
source lib/sfdc.sh

header "Running release.sh ..."

promote_package() {
  log "Promote package ..."

  sfdx force:package:version:promote \
    -p "$SFDX_PACKAGE_VERSION_ID" \
    -v "$DEV_HUB_SESSION_ID" \
    -n

  prepare_sfdc_environment \
    "$STAGING_SF_URL" \
    "$STAGING_SESSION_ID"

  sfdx force:package:install \
  -p "$SFDX_PACKAGE_VERSION_ID" \
  -u "$STAGING_SESSION_ID" \
  -w 10 \
  -b 10 \
  -n

}

promote_package

header "DONE! Completed in $(($SECONDS - $START_TIME))s"
exit 0
