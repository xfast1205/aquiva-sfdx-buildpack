#!/usr/bin/env bash
# SFDC dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_auth_store_url() {
  log "Authenticating org ..."
  REFRESH_TOKEN=${1:-}
  INSTANCE_URL=${2:-}

  echo "force://$REFRESH_TOKEN@$INSTANCE_URL" > sfdx.url

  sfdx force:auth:sfdxurl:store \
    -f ./sfdx.url \
    -a "$INSTANCE_URL"
}

sfdx_create_scratch() {
  log "Creating scratch org ..."
  USERNAME=${1:-}
  ALIAS=${2:-}

  sfdx force:org:create \
    -v "$USERNAME" \
    -a "$ALIAS" \
    -f ./config/project-scratch-def.json \
    -c
}

sfdx_source_push() {
  log "Pushing source to the scratch ..."
  USERNAME=${1:-}

  sfdx force:source:push \
    -u "$USERNAME"
}

add_trap() {
  trap 'sfdx_delete_scratch \
    "$TARGET_SCRATCH_ORG_ALIAS" \
    "$DEV_HUB_INSTANCE_URL"' \
  ERR
}

sfdx_run_test() {
  log "Running org tests ..."
  USERNAME=${1:-}

  add_trap

  sfdx force:apex:test:run \
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
    jq -r '.packageDirectories[]
      | select(.default==true)
      | .path')"

  if [ ! "$STAGE" == "DEV" ]; then
    NEW_PROJECT_FILE="$(jq -r --arg NAMESPACE "$PACKAGE_NAMESPACE" '.namespace=$NAMESPACE' sfdx-project.json)"
    echo "$NEW_PROJECT_FILE" > "./sfdx-project.json"
  fi

  sfdx force:package:create \
    -r "$PACKAGE_PATH" \
    -n "$PACKAGE_NAME" \
    -t "$PACKAGE_TYPE" \
    -v "$USERNAME"
}

# Validation if the package exists on Dev Hub
check_package_on_devhub() {
  log "Searching Package on Dev Hub ..."
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
    echo "Creating package on Dev Hub ..."
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

# Validation if the package exists in sfdx-project.json file
check_package_in_project_file() {
  log "Searching Package in project files ..."
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

  # Create package if it's not exists
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
              \"versionNumber\": \"1.0.0.NEXT\", \
              \"ancestorId\": \"\"
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

install_package_version() {
  log "Installing new package version ..."
  SFDX_PACKAGE_NAME=${1:-}
  DEVHUB_USERNAME=${2:-}
  TARGET_USERNAME=${3:-}

  VERSION_NUMBER=$(get_package_version $SFDX_PACKAGE_NAME $DEVHUB_USERNAME)
  echo "$VERSION_NUMBER"
  LATEST_VERSION="$(eval sfdx force:package:version:list \
    -v $DEVHUB_USERNAME \
    -p $SFDX_PACKAGE_NAME \
    --concise \
    --json |
    jq -r '.result
      | sort_by(-.MajorVersion, -.MinorVersion, -.PatchVersion, -.BuildNumber)
      | .[0].SubscriberPackageVersionId')"

  if [[ ! "$LATEST_VERSION" == "null" && ! "$STAGE" == "DEV" ]]; then
    UPDATED_PROJECT_FILE="$(cat sfdx-project.json | jq -r --arg ANCESTOR "$LATEST_VERSION" '.packageDirectories[].ancestorId=$ANCESTOR')"
  else
    UPDATED_PROJECT_FILE="$(cat sfdx-project.json | jq -r 'del(.packageDirectories[].ancestorId)')"
  fi
  echo "$UPDATED_PROJECT_FILE" > "./sfdx-project.json"

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

  if [ ! "$STAGE" == "DEV" ]; then
    sfdx force:package:version:promote \
      -p "$PACKAGE_VERSION_ID" \
      -v "$DEVHUB_USERNAME" \
      -n
  fi

  sfdx force:package:install \
    -p "$PACKAGE_VERSION_ID" \
    -u "$TARGET_USERNAME" \
    -w 100 \
    -b 100 \
    -r

  echo "Package installation URL: https://login.salesforce.com/packaging/installPackage.apexp?p0=$PACKAGE_VERSION_ID"
}

get_package_version() {
  SFDX_PACKAGE_NAME=${1:-}
  DEVHUB_USERNAME=${2:-}

  if [ "$STAGE" == "DEV" ]; then
    MANAGED_PACKAGE_ID="$(sfdx force:package:list \
      -v $DEVHUB_USERNAME --json | jq -r --arg PACKAGE_NAME "$PACKAGE_NAME" '.result[]
        | select(.Name==$PACKAGE_NAME)
        | select(.ContainerOptions=="Managed").Id')"
  fi

  if [ ! -z $MANAGED_PACKAGE_ID ]; then
    MANAGED_MINOR_VERSION="$(eval sfdx force:package:version:list \
      -v $DEVHUB_USERNAME \
      -p $MANAGED_PACKAGE_ID \
      --concise \
      --json |
      jq -r '.result
        | sort_by(-.MajorVersion, -.MinorVersion, -.PatchVersion, -.BuildNumber) | .[0].MinorVersion')"
  fi

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

  if [ ! -z $MANAGED_MINOR_VERSION ]; then MINOR_VERSION=$MANAGED_MINOR_VERSION; fi;
  if [ "$IS_RELEASED" == "true" ]; then MINOR_VERSION=$(($MINOR_VERSION+1)); fi;

  VERSION_NUMBER="$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION.$BUILD_VERSION"

  echo "$VERSION_NUMBER"
}
