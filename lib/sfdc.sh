#!/usr/bin/env bash
# SFDC deps for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_auth_jwt() {
  log "Starting JWT auth ..."

  sfdx force:auth:jwt:grant  \
    --clientid $CONSUMER_KEY \
    --jwtkeyfile $SERVER_KEY \
    --username $SF_USERNAME  \
    --setdefaultdevhubusername
}

sfdx_auth_sfdxurl() {
  log "Starting SFDX URL auth ..."

  SFDX_AUTH_URL_FILE="$1"
  if [ ! "$2" == "" ]; then
    echo "$2" > "$SFDX_AUTH_URL_FILE"
  fi

  sfdx force:auth:sfdxurl:store -f $SFDX_AUTH_URL_FILE -a $3
}

sfdx_auth_devhub_sfdxurl() {
  log "Starting SFDX URL auth DevHub ..."

  SFDX_AUTH_URL_FILE="$1"
  if [ ! "$2" == "" ]; then
    echo "$2" > "$SFDX_AUTH_URL_FILE"
  fi

  sfdx force:auth:sfdxurl:store -f $SFDX_AUTH_URL_FILE -a $3 --setdefaultdevhubusername
}

sfdx_create_scratch() {
  log "Creating scratch org ..."

  sfdx force:org:create -u $1 -f ./config/project-scratch-def.json -a $2
}

sfdx_source_push() {
  log "Pushing source to the scratch ..."

  sfdx force:source:push -u $1
}

sfdx_run_test() {
  log "Running org tests ..."

  sfdx force:apex:test:run -u $1 -r human -y -w 1000 --verbose -l RunLocalTests
}

sfdx_delete_scratch() {
  log "Removing scratch org ..."

  sfdx force:org:delete -u $1 -p
}

sfdx_deploy() {
  log "Deploy started ..."

  sfdx forcesource:deploy -u $1 -p $2
}

install_package_version() {
  PACKAGE_NAME=$1
  PACKAGE_VERSION_JSON="$(eval sfdx force:package:version:list --concise --packages $PACKAGE_NAME -v $2 --json | jq '.result | sort_by(-.MajorVersion, -.MinorVersion, -.PatchVersion, -.BuildNumber) | .[0] // ""')"
  echo $PACKAGE_VERSION_JSON

  IS_RELEASED=$(jq -r '.IsReleased?' <<< $PACKAGE_VERSION_JSON)
  MAJOR_VERSION=$(jq -r '.MajorVersion?' <<< $PACKAGE_VERSION_JSON)
  MINOR_VERSION=$(jq -r '.MinorVersion?' <<< $PACKAGE_VERSION_JSON)
  PATCH_VERSION=$(jq -r '.PatchVersion?' <<< $PACKAGE_VERSION_JSON)
  BUILD_VERSION="NEXT"
  echo $MINOR_VERSION

  if [ -z $MAJOR_VERSION ]; then MAJOR_VERSION=1; fi;
  if [ -z $MINOR_VERSION ]; then MINOR_VERSION=0; fi;
  if [ -z $PATCH_VERSION ]; then PATCH_VERSION=0; fi;
  if [ "$IS_RELEASED" == "true" ]; then MINOR_VERSION=$(($MINOR_VERSION+1)); fi;
  VERSION_NUMBER="$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION.$BUILD_VERSION"
  echo $VERSION_NUMBER

  export PACKAGE_VERSION_ID="$(eval sfdx force:package:version:create --package $PACKAGE_NAME --versionnumber $VERSION_NUMBER --installationkeybypass -v $2 --wait 100 --json | jq -r '.result.SubscriberPackageVersionId')"
  echo $PACKAGE_VERSION_ID

  sfdx force:package:list
  sfdx force:package:install --package $PACKAGE_VERSION_ID --wait 100 --publishwait 100 --noprompt -u $3
}