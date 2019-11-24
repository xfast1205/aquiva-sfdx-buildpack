#!/usr/bin/env bash

START_TIME=$SECONDS

# set -x
set -o errexit      # always exit on error
set -o pipefail     # don't ignore exit codes when piping output

SFDX_PACKAGE_NAME=${1:-}
SFDX_PACKAGE_VERSION_ID=${2:-}
ORG_USERNAME=${3:-}
INSTANCE_URL=${4:-}
DEVHUB_USERNAME=${5:-}
DEVHUB_INSTANCE_URL=${6:-}
BP_DIR="."
# DEV_HUB_INSTANCE_URL=${6:-}

# Import dependencies

source lib/lib.sh
source lib/deps.sh
source lib/sfdc.sh

header "Running release.sh ..."

promote_package() {
  log "Promote package ..."

  prepare_sfdc_environment \
    "$DEVHUB_INSTANCE_URL" \
    "$DEVHUB_USERNAME"

  sfdx force:package:version:promote \
    -p "$SFDX_PACKAGE_VERSION_ID" \
    -v "$DEVHUB_USERNAME" \
    -n

  prepare_sfdc_environment \
    "$INSTANCE_URL" \
    "$ORG_USERNAME"

  sfdx force:package:install \
  -p "$SFDX_PACKAGE_VERSION_ID" \
  -u "$ORG_USERNAME" \
  -w 10 \
  -b 10 \
  -n

}

promote_package

header "DONE! Completed in $(($SECONDS - $START_TIME))s"
exit 0
