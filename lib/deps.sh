#!/usr/bin/env bash
# dev dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

install_sfdx_cli() {
  log "Installing Salesforce CLI ..."
  BUILD_DIR=${1:-}

  mkdir sfdx && curl \
    --silent \
    --location "https://developer.salesforce.com/media/salesforce-cli/sfdx-cli/channels/stable/sfdx-cli-linux-x64.tar.xz" |
    tar xJ -C sfdx --strip-components 1

  rm -rf "$BUILD_DIR/vendor/sfdx"
  mkdir -p "$BUILD_DIR/vendor/sfdx"
  cp -r sfdx "$BUILD_DIR/vendor/sfdx/cli"
  chmod -R 755 "$BUILD_DIR/vendor/sfdx/cli"
}

install_jq() {
  log "Installing jq ..."
  BUILD_DIR=${1:-}

  mkdir -p "$BUILD_DIR/vendor/sfdx/jq"
  cd "$BUILD_DIR/vendor/sfdx/jq"
  wget --quiet -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  chmod +x jq
}

verify_project_file() {
  log "Checking project files ..."
  BUILD_DIR=${1:-}
  FILE="$BUILD_DIR/sfdx-project.json"

  if [ ! -f "$FILE" ]; then
    echo "Please provide sfdx-project.json file"
    exit 1
  fi
}

make_soap_request() {
  log "Making SOAP request ..."
  USERNAME=${1:-}
  PASSWORD=${2:-}
  TOKEN=${3:-}
  IS_SANDBOX=${4:-}

  SOAP_FILE="<?xml version=\"1.0\" encoding=\"utf-8\" ?> \
    <env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" \
        xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" \
        xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\"> \
      <env:Body> \
        <n1:login xmlns:n1=\"urn:partner.soap.sforce.com\"> \
          <n1:username>$USERNAME</n1:username> \
          <n1:password>$PASSWORD$TOKEN</n1:password> \
        </n1:login> \
      </env:Body> \
    </env:Envelope>"
  
  echo "$SOAP_FILE" > "login.txt"

  if [ "$IS_SANDBOX" == "true" ]; then
    SF_URL="test"
  else
    SF_URL="login"
  fi

  echo $(curl https://$SF_URL.salesforce.com/services/Soap/u/47.0 \
    -H "Content-Type: text/xml; charset=UTF-8" -H "SOAPAction: login" -d @login.txt)
}

get_session_id() {
  RESPONSE=${1:-}

  echo "$RESPONSE" > "resp.xml"

  echo $(sed -n '/sessionId/{s/.*<sessionId>//;s/<\/sessionId.*//;p;}' resp.xml)
}

get_instance_url() {
  RESPONSE=${1:-}

  echo "$RESPONSE" > "resp.xml"

  IFS="/"
  read -ra ADDR <<< "$(sed -n '/serverUrl/{s/.*<serverUrl>//;s/<\/serverUrl.*//;p;}' resp.xml)"
  echo "${ADDR[2]}"
}

remove_temp_files() {
  rm -rf ./login.txt
  rm -rf ./resp.xml
}