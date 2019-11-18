#!/usr/bin/env bash
# dev dependencies for aquiva buildpack

source $BP_DIR/lib/lib.sh

install_sfdx_cli() {
  BUILD_DIR=${1:-}
  log "Downloading Salesforce CLI tarball ..."
  mkdir sfdx && curl --silent --location "https://developer.salesforce.com/media/salesforce-cli/sfdx-cli/channels/stable/sfdx-cli-linux-x64.tar.xz" | tar xJ -C sfdx --strip-components 1

  log "Copying Salesforce CLI binary ..."

  rm -rf "$BUILD_DIR/vendor/sfdx"
  mkdir -p "$BUILD_DIR/vendor/sfdx"
  cp -r sfdx "$BUILD_DIR/vendor/sfdx/cli"
  chmod -R 755 "$BUILD_DIR/vendor/sfdx/cli"
}

install_jq() {
  BUILD_DIR=${1:-}
  log "Downloading jq ..."
  mkdir -p "$BUILD_DIR/vendor/sfdx/jq"
  cd "$BUILD_DIR/vendor/sfdx/jq"
  wget --quiet -O jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
  chmod +x jq
}

install_npm() {
  log "Installing NPM ..."

  mkdir npm_temp && cd npm_temp && curl -O -L https://npmjs.org/install.sh
  sh install.sh
  npm install npm@latest
}

install_xmllint() {
  BUILD_DIR=${1:-}
  log "Installing xmllint ..."
  mkdir -p "$BUILD_DIR/vendor/xmllint"
  cd "$BUILD_DIR/vendor/xmllint"

  wget --quiet -O xmllint http://xmlsoft.org/sources/libxml2-2.7.2.tar.gz
  chmod +x xmllint
}