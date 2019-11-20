#!/usr/bin/env bash
# dev dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

install_sfdx_cli() {
  BUILD_DIR=${1:-}
  log "Installing Salesforce CLI ..."

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
  BUILD_DIR=${1:-}
  log "Installing jq ..."

  mkdir -p "$BUILD_DIR/vendor/sfdx/jq"
  cd "$BUILD_DIR/vendor/sfdx/jq"
  wget --quiet -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  chmod +x jq
}

verify_project_file() {
  FILE="$1/sfdx-project.json"

  if [ ! -f "$FILE" ]; then
    echo "Please provide sfdx-project.json file"
    exit 1
  fi
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
  echo "$1" > "resp.xml"

  echo $(sed -n '/sessionId/{s/.*<sessionId>//;s/<\/sessionId.*//;p;}' resp.xml)
}

get_instance_url() {
  echo "$1" > "resp.xml"

  IFS="/"
  read -ra ADDR <<< "$(sed -n '/serverUrl/{s/.*<serverUrl>//;s/<\/serverUrl.*//;p;}' resp.xml)"
  echo "${ADDR[2]}"
}