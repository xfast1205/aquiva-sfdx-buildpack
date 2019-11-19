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
HEROKU_STAGING_APP_NAME="$APP_NAME-staging"
HEROKU_PROD_APP_NAME="$APP_NAME-prod"

# Pipeline
HEROKU_PIPELINE_NAME="$APP_NAME-pipeline"

# Usernames or aliases of the orgs you're using
DEV_HUB_USERNAME="brave"
STAGING_USERNAME="brave"
PROD_USERNAME="badger"

# Repository with your code (e.g. wadewegner/GIFter)
GITHUB_REPO="xfast1205/herokupipe"

# Your package name (e.g. GIFter)
PACKAGE_NAME="mypipedemo"

### Setup script

# Clean up script (in case something goes wrong)
echo "heroku pipelines:destroy $HEROKU_PIPELINE_NAME
heroku apps:destroy -a $HEROKU_STAGING_APP_NAME -c $HEROKU_STAGING_APP_NAME
heroku apps:destroy -a $HEROKU_PROD_APP_NAME -c $HEROKU_PROD_APP_NAME
rm -- \"destroy-$APP_NAME.sh\"" > destroy-$APP_NAME.sh

echo ""
echo "Run ./destroy-$APP_NAME.sh to remove resources"
echo ""

chmod +x "destroy-$APP_NAME.sh"

# Create three Heroku apps to map to orgs
heroku apps:create $HEROKU_STAGING_APP_NAME
heroku apps:create $HEROKU_PROD_APP_NAME

# Set the stage (since STAGE isn't required, review apps don't get one)
heroku config:set STAGE=STAGING -a $HEROKU_STAGING_APP_NAME
heroku config:set STAGE=PROD -a $HEROKU_PROD_APP_NAME

# Package name
heroku config:set PACKAGE_NAME="$PACKAGE_NAME" -a $HEROKU_STAGING_APP_NAME
heroku config:set PACKAGE_NAME="$PACKAGE_NAME" -a $HEROKU_PROD_APP_NAME

# Setup sfdxUrl's for Dev Hub auth
heroku config:set DEV_HUB_USERNAME="aryzhkov@brave-bear-ga55ho.com" -a $HEROKU_STAGING_APP_NAME
heroku config:set DEV_HUB_PASSWORD="Lifeisgame1" -a $HEROKU_STAGING_APP_NAME
heroku config:set DEV_HUB_TOKEN="9hhDuN8r3AfJxI1qepBLEcJKD" -a $HEROKU_STAGING_APP_NAME
heroku config:set DEV_HUB_IS_SANDBOX=false -a $HEROKU_STAGING_APP_NAME
heroku config:set DEV_HUB_USERNAME="aryzhkov@brave-bear-ga55ho.com" -a $HEROKU_PROD_APP_NAME
heroku config:set DEV_HUB_PASSWORD="Lifeisgame1" -a $HEROKU_PROD_APP_NAME
heroku config:set DEV_HUB_TOKEN="9hhDuN8r3AfJxI1qepBLEcJKD" -a $HEROKU_PROD_APP_NAME
heroku config:set DEV_HUB_IS_SANDBOX=false -a $HEROKU_PROD_APP_NAME
heroku config:set STAGING_USERNAME="aryzhkov@brave-bear-ga55ho.com" -a $HEROKU_STAGING_APP_NAME
heroku config:set STAGING_PASSWORD="Lifeisgame1" -a $HEROKU_STAGING_APP_NAME
heroku config:set STAGING_TOKEN="9hhDuN8r3AfJxI1qepBLEcJKD" -a $HEROKU_STAGING_APP_NAME
heroku config:set STAGING_IS_SANDBOX=false -a $HEROKU_STAGING_APP_NAME
heroku config:set PROD_USERNAME="aryzhkov@curious-badger-oa5jdm.com" -a $HEROKU_PROD_APP_NAME
heroku config:set PROD_PASSWORD="lifeisgame1" -a $HEROKU_PROD_APP_NAME
heroku config:set PROD_TOKEN="1vwkH2RPVsqgjv5Qyb2Dcfvg" -a $HEROKU_PROD_APP_NAME
heroku config:set PROD_IS_SANDBOX=false -a $HEROKU_PROD_APP_NAME
heroku config:set SFDX_PACKAGE_NAME=mypipedemo -a $HEROKU_PROD_APP_NAME
heroku config:set SFDX_PACKAGE_NAME=mypipedemo -a $HEROKU_STAGING_APP_NAME

# Add buildpacks to apps (to use latest remove version info)
heroku buildpacks:add -i 1 https://github.com/xfast1205/aquiva-sfdx-buildpack -a $HEROKU_STAGING_APP_NAME
heroku buildpacks:add -i 1 https://github.com/xfast1205/aquiva-sfdx-buildpack -a $HEROKU_PROD_APP_NAME

# Create Pipeline
heroku pipelines:create $HEROKU_PIPELINE_NAME -a $HEROKU_STAGING_APP_NAME -s staging
heroku pipelines:add $HEROKU_PIPELINE_NAME -a $HEROKU_PROD_APP_NAME -s production

# Setup your pipeline
heroku pipelines:connect $HEROKU_PIPELINE_NAME --repo $GITHUB_REPO