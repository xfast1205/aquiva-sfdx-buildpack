#!/usr/bin/env bash
# SFDC dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_create_scratch() {
  log "Creating scratch org ..."
  USERNAME=${1:-}
  ALIAS=${2:-}

  sfdx force:org:create \
    -v "$USERNAME" \
    -a "$ALIAS" \
    -f ./config/project-scratch-def.json
}

sfdx_source_push() {
  log "Pushing source to the scratch ..."
  USERNAME=${1:-}

  sfdx force:source:push \
    -u "$USERNAME"
}

sfdx_run_test() {
  log "Running org tests ..."
  USERNAME=${1:-}

  sfdx force:apex:test:run \
    -l RunLocalTests \
    -u "$USERNAME" \
    --verbose \
    -r human \
    -w 1000 \
    -y
}

sfdx_delete_scratch() {
  log "Removing scratch org ..."
  ALIAS=${1:-}
  USERNAME=${2:-}

  sfdx force:org:delete \
    -v "$USERNAME" \
    -u "$ALIAS" \
    -p
}

create_package() {
  log "Creating Package ..."
  PACKAGE_NAME=${1:-}
  PACKAGE_TYPE=${2:-}
  USERNAME=${3:-}

  PACKAGE_PATH="$(cat sfdx-project.json |
    jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" '.packageDirectories[]
      | select(.package==$PACKAGE_NAME)
      | .path')"

  sfdx force:package:create \
    -d "$PACKAGE_PATH" \
    -p "$PACKAGE_NAME" \
    -t "$PACKAGE_TYPE" \
    -v "$USERNAME"
}

is_package_exists_on_devhub() {
  log "Checking Package on Dev Hub ..."
  USERNAME=${1:-}
  PACKAGE_NAME=${2:-}

  IS_PACKAGE_EXISTS="$(eval sfdx force:package:list -v $USERNAME --json |
    jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" '.result[]
      | select(.Name==$PACKAGE_NAME)')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    echo "Please install your package in your Dev Hub"
    exit 1
  fi
}

is_package_exists_in_project_file() {
  log "Checking Package in project files ..."
  PACKAGE_NAME=${1:-}

  IS_PACKAGE_EXISTS="$(cat sfdx-project.json |
    jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" '.packageDirectories[]
      | select(.package==$PACKAGE_NAME)')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    echo "Please update sfdx-project.json file with package name"
    exit 1
  fi
}

is_namespace_exists_in_project_file() {
  log "Checking Namespace in project files ..."
  NAMESPACE=${1:-}

  IS_NAMESPACE_EXISTS="$(cat sfdx-project.json |
    jq -r --arg NAMESPACE "$NAMESPACE" '.packageDirectories[]
      | select(.namespace==$NAMESPACE)')"

  if [ -z "$IS_NAMESPACE_EXISTS" ]; then
    echo "Please link namespace to your Dev Hub and update sfdx-project.json file"
    exit 1
  fi
}

prepare_sfdc_environment() {
  log "Prepare Environment configs ..."
  INSTANCE_URL=${1:-}
  USERNAME=${2:-}
  SF_URL="https://$INSTANCE_URL"

  sfdx force:config:set \
    instanceUrl="$SF_URL"

  sfdx force:config:set \
    defaultusername="$USERNAME"
}

prepare_proc() {
  if [ ! -f $5/Procfile ]; then
    log "Creating Procfile ..."
    SFDX_PACKAGE_NAME=${1:-}
    PACKAGE_VERSION_ID=${2:-}
    DEV_SESSION_ID=${3:-}
    DEV_INSTANCE_URL=${4:-}
    BUILD_DIR=${5:-}
    BP_DIR=${6:-}

    echo "release: bash ./lib/release.sh \
      \"$SFDX_PACKAGE_NAME\" \
      \"$PACKAGE_VERSION_ID\" \
      \"$DEV_SESSION_ID\" \
      \"$DEV_INSTANCE_URL\"" > $5/Procfile

    mkdir $BUILD_DIR/lib/
    cp $BP_DIR/lib/release.sh $BUILD_DIR/lib/
    cp $BP_DIR/lib/deps.sh $BUILD_DIR/lib/
    cp $BP_DIR/lib/sfdc.sh $BUILD_DIR/lib/
    cp $BP_DIR/lib/lib.sh $BUILD_DIR/lib/

  fi
}

install_package_version() {
  log "Installing new package version ..."
  SFDX_PACKAGE_NAME=${1:-}
  DEVHUB_USERNAME=${2:-}
  USERNAME=${3:-}
  INSTANCE_URL=${4:-}
  BUILD_DIR=${5:-}
  BP_DIR=${6:-}

  VERSION_NUMBER=$(get_package_version $SFDX_PACKAGE_NAME $DEVHUB_USERNAME)

  PACKAGE_VERSION_ID="$(eval sfdx force:package:version:create -p $SFDX_PACKAGE_NAME --versionnumber $VERSION_NUMBER --installationkeybypass -v $USERNAME --wait 100 --json |
    jq -r '.result.SubscriberPackageVersionId')"

  prepare_proc \
    "$SFDX_PACKAGE_NAME" \
    "$PACKAGE_VERSION_ID" \
    "$USERNAME" \
    "$INSTANCE_URL" \
    "$BUILD_DIR" \
    "$BP_DIR"

  prepare_sfdc_environment \
    "$INSTANCE_URL" \
    "$USERNAME"

  sfdx force:package:install \
    -p "$PACKAGE_VERSION_ID" \
    -u "$USERNAME" \
    -w 100 \
    -b 100 \
    -r
}

get_package_version() {
  log "Retrieving Package ID ..."
  SFDX_PACKAGE_NAME=${1:-}
  DEVHUB_USERNAME=${2:-}

  PACKAGE_VERSION_JSON="$(eval sfdx force:package:version:list -v $DEVHUB_USERNAME -p $SFDX_PACKAGE_NAME --json --concise |
    jq '.result | sort_by(-.MajorVersion, -.MinorVersion, -.PatchVersion, -.BuildNumber) | .[0] // ""')"

  IS_RELEASED=$(jq -r '.IsReleased?' <<< $PACKAGE_VERSION_JSON)
  MAJOR_VERSION=$(jq -r '.MajorVersion?' <<< $PACKAGE_VERSION_JSON)
  MINOR_VERSION=$(jq -r '.MinorVersion?' <<< $PACKAGE_VERSION_JSON)
  PATCH_VERSION=$(jq -r '.PatchVersion?' <<< $PACKAGE_VERSION_JSON)
  BUILD_VERSION="NEXT"

  if [ -z $MAJOR_VERSION ]; then MAJOR_VERSION=1; fi;
  if [ -z $MINOR_VERSION ]; then MINOR_VERSION=0; fi;
  if [ -z $PATCH_VERSION ]; then PATCH_VERSION=0; fi;
  if [ "$IS_RELEASED" = "true" ]; then MINOR_VERSION=$(($MINOR_VERSION+1)); fi;
  VERSION_NUMBER="$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION.$BUILD_VERSION"

  echo "$VERSION_NUMBER"
}
