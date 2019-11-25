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

# Import dependencies

source lib/lib.sh
source lib/deps.sh
source lib/sfdc.sh

header "Running release.sh ..."

promote_package() {
  log "Promote package ..."
  INSTANCE_URL=${1:-}

  prepare_sfdc_environment \
    "$DEVHUB_INSTANCE_URL" \
    "$DEVHUB_USERNAME"

  sfdx force:package:version:promote \
    -p "$SFDX_PACKAGE_VERSION_ID" \
    -v "$DEVHUB_USERNAME" \
    -n
  echo "$INSTANCE_URL"
  prepare_sfdc_environment \
    "$INSTANCE_URL" \
    "$ORG_USERNAME"

  sfdx force:package:install \
  -p "$SFDX_PACKAGE_VERSION_ID" \
  -u "$ORG_USERNAME" \
  -w 10 \
  -b 10 \
  -r

}

promote_package "$INSTANCE_URL"

header "DONE! Completed in $(($SECONDS - $START_TIME))s"
exit 0
