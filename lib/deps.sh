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

# Check if there is sfdx-project.json file in the repository
verify_project_file() {
  log "Checking project files ..."
  BUILD_DIR=${1:-}
  FILE="$BUILD_DIR/sfdx-project.json"

  if [ ! -f "$FILE" ]; then
    echo "Please provide sfdx-project.json file"
    exit 1
  fi
}
