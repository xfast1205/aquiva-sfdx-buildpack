#!/usr/bin/env bash
# SFDC deps for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_create_scratch() {
  log "Creating scratch org ..."

  sfdx force:org:create -v $1 -f ./config/project-scratch-def.json -a $2
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

  sfdx force:org:delete -u $1 -v $2 -p
}

install_package_version() {
  PACKAGE_VERSION_JSON="$(eval sfdx force:package:version:list -v $2 -p $1 --json --concise | jq '.result | sort_by(-.MajorVersion, -.MinorVersion, -.PatchVersion, -.BuildNumber) | .[0] // ""')"
  echo $PACKAGE_VERSION_JSON

  IS_RELEASED=$(jq -r '.IsReleased?' <<< $PACKAGE_VERSION_JSON)
  MAJOR_VERSION=$(jq -r '.MajorVersion?' <<< $PACKAGE_VERSION_JSON)
  MINOR_VERSION=$(jq -r '.MinorVersion?' <<< $PACKAGE_VERSION_JSON)
  PATCH_VERSION=$(jq -r '.PatchVersion?' <<< $PACKAGE_VERSION_JSON)
  BUILD_VERSION="NEXT"
  echo "Minor version: $MINOR_VERSION"
  sfdx force:package:list -v $2

  if [ -z $MAJOR_VERSION ]; then MAJOR_VERSION=1; fi;
  if [ -z $MINOR_VERSION ]; then MINOR_VERSION=0; fi;
  if [ -z $PATCH_VERSION ]; then PATCH_VERSION=0; fi;
  if [ "$IS_RELEASED" == "true" ]; then MINOR_VERSION=$(($MINOR_VERSION+1)); fi;
  VERSION_NUMBER="$MAJOR_VERSION.$MINOR_VERSION.$PATCH_VERSION.$BUILD_VERSION"
  echo "Version number: $VERSION_NUMBER"

  export PACKAGE_VERSION_ID="$(eval sfdx force:package:version:create -p $1 --versionnumber $VERSION_NUMBER --installationkeybypass -v $2 --wait 100 --json | jq -r '.result.SubscriberPackageVersionId')"
  echo "Package version: $PACKAGE_VERSION_ID"

  sfdx force:package:install --package $PACKAGE_VERSION_ID --wait 100 --publishwait 100 --noprompt -u $3
}

make_soap_request() {
  SOAP_FILE="<?xml version=\"1.0\" encoding=\"utf-8\" ?> \
    <env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" \
        xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" \
        xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"> \
      <env:Body> \
        <n1:login xmlns:n1=\"urn:partner.soap.sforce.com\"> \
          <n1:username>$1</n1:username> \
          <n1:password>$2$3</n1:password> \
        </n1:login> \
      </env:Body> \
    </env:Envelope>"
  
  echo "$SOAP_FILE" > "login.txt"

  if [ "$4" == "true" ]; then
    SF_URL="test"
  else
    SF_URL="login"
  fi

  echo $(curl https://$SF_URL.salesforce.com/services/Soap/u/47.0 \
      -H "Content-Type: text/xml; charset=UTF-8" -H "SOAPAction: login" -d @login.txt)
}

get_session_id() {
  AUTH_SESSION=$(make_soap_request $1 $2 $3 $4)

  echo "$AUTH_SESSION" > "resp.xml"
  echo $(sed -n '/sessionId/{s/.*<sessionId>//;s/<\/sessionId.*//;p;}' resp.xml)
}

get_instance_url() {
  AUTH_SERVER=$(make_soap_request $1 $2 $3 $4)

  echo "$AUTH_SERVER" > "resp.xml"
  IFS="/"
  read -ra ADDR <<< "$(sed -n '/serverUrl/{s/.*<serverUrl>//;s/<\/serverUrl.*//;p;}' resp.xml)"
  echo "${ADDR[2]}"
}