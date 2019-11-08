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

prepare_packs() {
  log "Preparing NPM packs ..."

  npm install -g n
  npm i -g yarn
  n latest
}

install_aquiva_plugin() {
  NPM_TOKEN=$NPM_TOKEN
  log "Installing SFDX Aquiva plugin ..."

  mkdir aquiva_temp && cd aquiva_temp && touch .npmrc && chmod -R 755 ".npmrc" && echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc
  pwd
  npm install @steplyakov/sfdx-aquiva-plugin
  sfdx plugins:link node_modules/@steplyakov/sfdx-aquiva-plugin
}