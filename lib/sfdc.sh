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

  if [ ! "$STAGE" == "DEV" ]; then
    NEW_PROJECT_FILE="$(jq --arg NAMESPACE "$PACKAGE_NAMESPACE" '.namespace=$NAMESPACE' sfdx-project.json)"
    echo "$NEW_PROJECT_FILE" > "./sfdx-project.json"
  fi

  sfdx force:package:create \
    -r "$PACKAGE_PATH" \
    -n "$PACKAGE_NAME" \
    -t "$PACKAGE_TYPE" \
    -v "$USERNAME"
}

check_package_on_devhub() {
  log "Checking Package on Dev Hub ..."
  USERNAME=${1:-}
  PACKAGE_NAME=${2:-}

  if [ "$STAGE" == "DEV" ]; then
    PACKAGE_TYPE="Unlocked"
  else
    PACKAGE_TYPE="Managed"
  fi

  IS_PACKAGE_EXISTS="$(sfdx force:package:list -v $USERNAME --json |
    jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" --arg PACKAGE_TYPE "$PACKAGE_TYPE" '.result[]
      | select(.Name==$PACKAGE_NAME)
      | select(.ContainerOptions==$PACKAGE_TYPE)')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    echo "Installing package on Dev Hub ..."
    create_package \
      "$PACKAGE_NAME" \
      "$PACKAGE_TYPE" \
      "$USERNAME"
  fi

  check_package_in_project_file \
    "$PACKAGE_NAME" \
    "$PACKAGE_TYPE" \
    "$USERNAME"
}

check_package_in_project_file() {
  log "Checking Package in project files ..."
  PACKAGE_NAME=${1:-}
  PACKAGE_TYPE=${2:-}
  USERNAME=${3:-}
  NAMESPACE="$PACKAGE_NAMESPACE"

  IS_PACKAGE_EXISTS="$(cat sfdx-project.json |
    jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" '.packageDirectories[]
      | select(.package==$PACKAGE_NAME)')"

  PACKAGE_ID="$(sfdx force:package:list -v "$USERNAME" --json |
      jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" --arg PACKAGE_TYPE "$PACKAGE_TYPE" '.result[]
        | select(.Name==$PACKAGE_NAME)
        | select(.ContainerOptions==$PACKAGE_TYPE)
        .Id')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    PACKAGE_PATH="$(cat sfdx-project.json |
      jq -r '.packageDirectories[]
        | select(.default==true)
        .path')"
    API_VERSION="$(cat sfdx-project.json | jq -r '.sourceApiVersion')"
    LOGIN_URL="$(cat sfdx-project.json | jq -r '.sfdcLoginUrl')"
    if [ "$STAGE" == "DEV" ]; then
      NAMESPACE=""
    fi
    SFDX_PROJECT_TEMPLATE="{ \
      \"packageDirectories\": [ \
          { \
              \"path\": \"$PACKAGE_PATH\", \
              \"default\": true, \
              \"package\": \"$PACKAGE_NAME\", \
              \"versionName\": \"ver 0.1\", \
              \"versionNumber\": \"0.1.0.NEXT\" \
          } \
      ], \
      \"namespace\": \"$NAMESPACE\", \
      \"sfdcLoginUrl\": \"$LOGIN_URL\", \
      \"sourceApiVersion\": \"$API_VERSION\", \
      \"packageAliases\": { \
          \"$PACKAGE_NAME\": \"$PACKAGE_ID\" \
      } \
    }"

    echo "$SFDX_PROJECT_TEMPLATE" > "./sfdx-project.json"
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
    DEVHUB_USERNAME=${7:-}
    DEV_HUB_INSTANCE_URL=${8:-}

    echo "release: bash ./lib/release.sh \
      \"$SFDX_PACKAGE_NAME\" \
      \"$PACKAGE_VERSION_ID\" \
      \"$DEV_SESSION_ID\" \
      \"$DEV_INSTANCE_URL\" \
      \"$DEVHUB_USERNAME\" \
      \"$DEV_HUB_INSTANCE_URL\"" > $BUILD_DIR/Procfile

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
  TARGET_USERNAME=${3:-}
  TARGET_INSTANCE_URL=${4:-}
  BUILD_DIR=${5:-}
  BP_DIR=${6:-}
  DEV_HUB_INSTANCE_URL=${7:-}

  VERSION_NUMBER=$(get_package_version $SFDX_PACKAGE_NAME $DEVHUB_USERNAME)
  COMMAND_CREATE="sfdx force:package:version:create \
    -p $SFDX_PACKAGE_NAME \
    -n $VERSION_NUMBER \
    -v $DEVHUB_USERNAME \
    -w 100 \
    --json -x "

  if [ ! "$STAGE" == "DEV" ]; then
    COMMAND_CREATE="${COMMAND_CREATE}-c"
  fi

  PACKAGE_VERSION_ID="$(eval $COMMAND_CREATE |
    jq -r '.result.SubscriberPackageVersionId')"

  # prepare_proc \
  #   "$SFDX_PACKAGE_NAME" \
  #   "$PACKAGE_VERSION_ID" \
  #   "$USERNAME" \
  #   "$INSTANCE_URL" \
  #   "$BUILD_DIR" \
  #   "$BP_DIR" \
  #   "$DEVHUB_USERNAME" \
  #   "$DEV_HUB_INSTANCE_URL"

  sfdx force:package:version:promote \
    -p "$PACKAGE_VERSION_ID" \
    -v "$DEVHUB_USERNAME" \
    -n

  prepare_sfdc_environment \
    "$TARGET_INSTANCE_URL" \
    "$TARGET_USERNAME"

  sfdx force:package:install \
    -p "$PACKAGE_VERSION_ID" \
    -u "$TARGET_USERNAME" \
    -w 100 \
    -b 100 \
    -r
}

get_package_version() {
  SFDX_PACKAGE_NAME=${1:-}
  DEVHUB_USERNAME=${2:-}

  PACKAGE_VERSION_JSON="$(eval sfdx force:package:version:list \
    -v $DEVHUB_USERNAME \
    -p $SFDX_PACKAGE_NAME \
    --concise \
    --json |
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
