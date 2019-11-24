#!/usr/bin/env bash
# SFDC dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_create_scratch() {
  log "Creating scratch org ..."

  sfdx force:org:create \
    -v $1 \
    -f ./config/project-scratch-def.json \
    -a $2
}

sfdx_source_push() {
  log "Pushing source to the scratch ..."

  sfdx force:source:push \
    -u $1
}

sfdx_run_test() {
  log "Running org tests ..."

  sfdx force:apex:test:run \
    -u $1 \
    -r human \
    -y \
    -w 1000 \
    --verbose \
    -l RunLocalTests
}

sfdx_delete_scratch() {
  log "Removing scratch org ..."

  sfdx force:org:delete \
    -u $1 \
    -v $2 \
    -p
}

create_package() {
  log "Creating Package ..."

  PACKAGE_PATH="$(cat sfdx-project.json |
    jq -r --arg PACKAGE_NAME "$1" '.packageDirectories[]
      | select(.package==$PACKAGE_NAME)
      | .path')"

  sfdx force:package:create \
    --path "$PACKAGE_PATH" \
    --name $1 \
    --packagetype $2 \
    -v $3
}

is_package_exists_on_devhub() {
  log "Checking Package on Dev Hub ..."

  IS_PACKAGE_EXISTS="$(eval sfdx force:package:list -v $1 --json |
    jq -r --arg PACKAGE_NAME "$2" '.result[]
      | select(.Name==$PACKAGE_NAME)')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    echo "Please install your package in your Dev Hub"
    exit 1
  fi
}

is_package_exists_in_project_file() {
  log "Checking Package in project files ..."

  IS_PACKAGE_EXISTS="$(cat sfdx-project.json |
    jq -r --arg PACKAGE_NAME "$1" '.packageDirectories[]
      | select(.package==$PACKAGE_NAME)')"

  if [ -z "$IS_PACKAGE_EXISTS" ]; then
    echo "Please update sfdx-project.json file with package name"
    exit 1
  fi
}

is_namespace_exists_in_project_file() {
  IS_NAMESPACE_EXISTS="$(cat sfdx-project.json |
    jq -r --arg NAMESPACE "$1" '.packageDirectories[]
      | select(.namespace==$NAMESPACE)')"

  if [ -z "$IS_NAMESPACE_EXISTS" ]; then
    echo "Please link namespace to your Dev Hub and update sfdx-project.json file"
    exit 1
  fi
}

prepare_sfdc_environment() {
  SF_URL="https://$1"

  sfdx force:config:set \
    instanceUrl="$SF_URL"

  sfdx force:config:set \
    defaultusername="$2"
}

prepare_proc() {
  if [ ! -f $5/Procfile ]; then
    log "Creating Procfile ..."

    echo "# Deploy source to prodyuction org.
    release: chmod a+x ./lib/release.sh \"$1\" \"$2\" \"$3\" \"$4\" \"$5\"" > $5/Procfile

    mkdir $5/lib/
    cp $6/lib/release.sh $5/lib/
    cp $6/lib/deps.sh $5/lib/
    cp $6/lib/sfdc.sh $5/lib/
    cp $6/lib/lib.sh $5/lib/

  fi
}

install_package_version() {
  log "Installing new package version ..."

  VERSION_NUMBER=$(get_package_version $1 $2)

  # PACKAGE_VERSION_ID="$(eval sfdx force:package:version:create -p $1 --versionnumber $VERSION_NUMBER --installationkeybypass -v $2 --wait 100 --json |
  #   jq -r '.result.SubscriberPackageVersionId')"

  prepare_proc "$1" "$PACKAGE_VERSION_ID" "$3" "$4" "$5" "$6"

  prepare_sfdc_environment "$4" "$3"
  # sfdx force:package:install \
  #   --package $PACKAGE_VERSION_ID \
  #   --wait 100 \
  #   --publishwait 100 \
  #   --noprompt \
  #   -u $3
}

get_package_version() {
  PACKAGE_VERSION_JSON="$(eval sfdx force:package:version:list -v $2 -p $1 --json --concise |
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
