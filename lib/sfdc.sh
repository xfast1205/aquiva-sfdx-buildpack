#!/usr/bin/env bash
# SFDC deps for aquiva buildpack

source $BP_DIR/lib/lib.sh

sfdx_auth_devhub() {
  log "Starting auth DevHub ..."

  sfdx force:auth:logout -a -p
  sfdx force:auth:jwt:grant \
  --clientid $CONSUMER_KEY  \
  --jwtkeyfile $SERVER_KEY  \
  --username $SF_USERNAME   \
  --setdefaultdevhubusername
}

sfdx_create_scratch() {
  log "Creating scratch org ..."

  sfdx force:org:create                  \
    -u $SF_USERNAME                      \
    -f ./config/project-scratch-def.json \
    -a scratch_org_1
}

sfdx_deploy() {
  log "Deploy started ..."

  sfdx aquiva:deploy  \
    -u scratch_org_1  \
    -t $SF_TEST_LEVEL \
    -p $SRC_FOLDER
}

sfdx_pmd() {
  log "Code analysis started ..."

  sfdx aquiva:pmd \
    -d force-app  \
    -r rulesets
}

sfdx_remove_scratch() {
  sfdx force:org:delete \
    -u scratch_org_1    \
    -p
}