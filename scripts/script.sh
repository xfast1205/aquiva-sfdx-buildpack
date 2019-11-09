#!/usr/bin/env bash

set -o errexit    # always exit on error
set -o pipefail   # don't ignore exit codes when piping output
set -o nounset    # fail on unset variables

#################################################################
# Script to setup a fully configured pipeline for Salesforce DX #
#################################################################

### Declare values

# Descriptive name for the Heroku app (e.g. gifter)
APP_NAME="packaging-wizard"

# Name of the Heroku apps you'll use
HEROKU_QA_APP_NAME="$APP_NAME-qa"
HEROKU_STAGING_APP_NAME="$APP_NAME-staging"
HEROKU_PROD_APP_NAME="$APP_NAME-prod"

# Pipeline
HEROKU_PIPELINE_NAME="$APP_NAME-pipeline"

# Usernames or aliases of the orgs you're using
DEV_HUB_USERNAME="brave"
QA_USERNAME="brave"
STAGING_USERNAME="badger"
PROD_USERNAME="badger"

# Repository with your code (e.g. wadewegner/GIFter)
GITHUB_REPO="xfast1205/herokupipe"

# Your package name (e.g. GIFter)
PACKAGE_NAME="mypipedemo"

### Setup script

# Clean up script (in case something goes wrong)
echo "heroku pipelines:destroy $HEROKU_PIPELINE_NAME
heroku apps:destroy -a $HEROKU_QA_APP_NAME -c $HEROKU_QA_APP_NAME
heroku apps:destroy -a $HEROKU_STAGING_APP_NAME -c $HEROKU_STAGING_APP_NAME
heroku apps:destroy -a $HEROKU_PROD_APP_NAME -c $HEROKU_PROD_APP_NAME
rm -- \"destroy$APP_NAME.sh\"" > destroy-$APP_NAME.sh

echo ""
echo "Run ./destroy-$APP_NAME.sh to remove resources"
echo ""

chmod +x "destroy-$APP_NAME.sh"

# Create three Heroku apps to map to orgs
heroku apps:create $HEROKU_QA_APP_NAME
heroku apps:create $HEROKU_STAGING_APP_NAME
heroku apps:create $HEROKU_PROD_APP_NAME

# Set the stage (since STAGE isn't required, review apps don't get one)
heroku config:set STAGE=DEV -a $HEROKU_QA_APP_NAME
heroku config:set STAGE=STAGING -a $HEROKU_STAGING_APP_NAME
heroku config:set STAGE=PROD -a $HEROKU_PROD_APP_NAME

# Set whether or not to use DCP packaging
heroku config:set SFDX_INSTALL_PACKAGE_VERSION=true -a $HEROKU_QA_APP_NAME
heroku config:set SFDX_INSTALL_PACKAGE_VERSION=true -a $HEROKU_STAGING_APP_NAME
heroku config:set SFDX_INSTALL_PACKAGE_VERSION=true -a $HEROKU_PROD_APP_NAME

# Set whether to create package version
heroku config:set SFDX_CREATE_PACKAGE_VERSION=true -a $HEROKU_QA_APP_NAME
heroku config:set SFDX_CREATE_PACKAGE_VERSION=false -a $HEROKU_STAGING_APP_NAME
heroku config:set SFDX_CREATE_PACKAGE_VERSION=false -a $HEROKU_PROD_APP_NAME

# Package name
heroku config:set SFDX_PACKAGE_NAME="$PACKAGE_NAME" -a $HEROKU_QA_APP_NAME
heroku config:set SFDX_PACKAGE_NAME="$PACKAGE_NAME" -a $HEROKU_STAGING_APP_NAME
heroku config:set SFDX_PACKAGE_NAME="$PACKAGE_NAME" -a $HEROKU_PROD_APP_NAME

# Turn on debug logging
heroku config:set SFDX_BUILDPACK_DEBUG=true -a $HEROKU_QA_APP_NAME
heroku config:set SFDX_BUILDPACK_DEBUG=false -a $HEROKU_STAGING_APP_NAME
heroku config:set SFDX_BUILDPACK_DEBUG=false -a $HEROKU_PROD_APP_NAME

# Setup sfdxUrl's for Dev Hub auth
devHubSfdxAuthUrl=$(sfdx force:org:display --verbose -u $DEV_HUB_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl -a $HEROKU_QA_APP_NAME
heroku config:set SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl -a $HEROKU_STAGING_APP_NAME
heroku config:set SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl -a $HEROKU_PROD_APP_NAME

# Setup sfdxUrl's for Org auth
devSfdxAuthUrl=$(sfdx force:org:display --verbose -u $QA_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$devSfdxAuthUrl -a $HEROKU_QA_APP_NAME

stagingSfdxAuthUrl=$(sfdx force:org:display --verbose -u $STAGING_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$stagingSfdxAuthUrl -a $HEROKU_STAGING_APP_NAME

prodSfdxAuthUrl=$(sfdx force:org:display --verbose -u $PROD_USERNAME --json | jq -r .result.sfdxAuthUrl)
heroku config:set SFDX_AUTH_URL=$prodSfdxAuthUrl -a $HEROKU_PROD_APP_NAME

# Add buildpacks to apps (to use latest remove version info)
heroku buildpacks:add -i 1 https://github.com/xfast1205/aquiva-sfdx-buildpack -a $HEROKU_QA_APP_NAME
heroku buildpacks:add -i 1 https://github.com/xfast1205/aquiva-sfdx-buildpack -a $HEROKU_STAGING_APP_NAME
heroku buildpacks:add -i 1 https://github.com/xfast1205/aquiva-sfdx-buildpack -a $HEROKU_PROD_APP_NAME

# Create Pipeline
heroku pipelines:create $HEROKU_PIPELINE_NAME -a $HEROKU_QA_APP_NAME -s development
heroku pipelines:add $HEROKU_PIPELINE_NAME -a $HEROKU_STAGING_APP_NAME -s staging
heroku pipelines:add $HEROKU_PIPELINE_NAME -a $HEROKU_PROD_APP_NAME -s production

heroku config:set -a $HEROKU_QA_APP_NAME SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl
heroku config:set -a $HEROKU_QA_APP_NAME SFDX_AUTH_URL=$devSfdxAuthUrl
heroku config:set -a $HEROKU_QA_APP_NAME SFDX_BUILDPACK_DEBUG=false
heroku config:set -a $HEROKU_QA_APP_NAME SFDX_INSTALL_PACKAGE_VERSION=true
heroku config:set -a $HEROKU_QA_APP_NAME SFDX_CREATE_PACKAGE_VERSION=true
heroku config:set -a $HEROKU_QA_APP_NAME SFDX_PACKAGE_NAME="$PACKAGE_NAME"
heroku config:set -a $HEROKU_QA_APP_NAME APP_NAME="$APP_NAME"
heroku config:set -a $HEROKU_QA_APP_NAME DEV_HUB_USERNAME="$DEV_HUB_USERNAME"
heroku config:set -a $HEROKU_QA_APP_NAME QA_USERNAME="$QA_USERNAME"
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_AUTH_URL=$stagingSfdxAuthUrl
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_BUILDPACK_DEBUG=false
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_INSTALL_PACKAGE_VERSION=true
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_CREATE_PACKAGE_VERSION=false
heroku config:set -a $HEROKU_STAGING_APP_NAME SFDX_PACKAGE_NAME="$PACKAGE_NAME"
heroku config:set -a $HEROKU_STAGING_APP_NAME APP_NAME="$APP_NAME"
heroku config:set -a $HEROKU_STAGING_APP_NAME DEV_HUB_USERNAME="$DEV_HUB_USERNAME"
heroku config:set -a $HEROKU_STAGING_APP_NAME QA_USERNAME="$QA_USERNAME"
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_AUTH_URL=$prodSfdxAuthUrl
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_BUILDPACK_DEBUG=false
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_INSTALL_PACKAGE_VERSION=true
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_CREATE_PACKAGE_VERSION=false
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_PACKAGE_NAME="$PACKAGE_NAME"
heroku config:set -a $HEROKU_PROD_APP_NAME APP_NAME="$APP_NAME"
heroku config:set -a $HEROKU_PROD_APP_NAME DEV_HUB_USERNAME="$DEV_HUB_USERNAME"
heroku config:set -a $HEROKU_PROD_APP_NAME QA_USERNAME="$QA_USERNAME"
heroku config:set -a $HEROKU_PROD_APP_NAME SFDX_DEV_HUB_AUTH_URL=$devHubSfdxAuthUrl
heroku ci:config:set -p $HEROKU_PIPELINE_NAME SFDX_AUTH_URL=$prodSfdxAuthUrl
heroku ci:config:set -p $HEROKU_PIPELINE_NAME SFDX_BUILDPACK_DEBUG=false
heroku ci:config:set -p $HEROKU_PIPELINE_NAME SFDX_INSTALL_PACKAGE_VERSION=true
heroku ci:config:set -p $HEROKU_PIPELINE_NAME SFDX_CREATE_PACKAGE_VERSION=false
heroku ci:config:set -a $HEROKU_PROD_APP_NAME SFDX_PACKAGE_NAME="$PACKAGE_NAME"
heroku ci:config:set -p $HEROKU_PIPELINE_NAME APP_NAME="$APP_NAME"
heroku ci:config:set -p $HEROKU_PIPELINE_NAME DEV_HUB_USERNAME="$DEV_HUB_USERNAME"
heroku ci:config:set -p $HEROKU_PIPELINE_NAME QA_USERNAME="$QA_USERNAME"

# Setup your pipeline
heroku pipelines:connect $HEROKU_PIPELINE_NAME --repo $GITHUB_REPO
heroku reviewapps:enable -p $HEROKU_PIPELINE_NAME -a $HEROKU_QA_APP_NAME --autodeploy --autodestroy