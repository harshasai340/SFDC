#!/usr/bin/env bash
# GitHub Actions version of auth.sh
# Handles Salesforce authentication with GitHub Actions environment variables

client_id=$1
client_secret=$2
environment=$3
password=$4
username="cicduser@attone.com.${environment}"

echo "🔐 Authenticating to Salesforce org: ${environment}"

#Get the access token from the salesforce org
salesforce_cred="$(curl --location --request POST "https://test.salesforce.com/services/oauth2/token?grant_type=password&client_id=${client_id}&client_secret=${client_secret}&username=${username}&password=${password}" )"

# Check if authentication was successful
if [ $? -ne 0 ]; then
    echo "❌ Failed to authenticate with Salesforce"
    exit 1
fi

echo "Salesforce Credential Response: $salesforce_cred"

access_token=$(echo ${salesforce_cred} | jq -r .access_token)
instance_url=$(echo ${salesforce_cred} | jq -r .instance_url)

echo "ACCESS TOKEN: $access_token"
echo "INSTANCE URL:instance_url"

# Validate that we got valid tokens
if [ "$access_token" == "null" ] || [ "$instance_url" == "null" ]; then
    echo "❌ Failed to retrieve access token or instance URL"
    echo "Response: $salesforce_cred"
    exit 1
fi

echo $salesforce_cred
echo "$access_token\n${instance_url}"

# Set GitHub Actions environment variables
echo "SF_ACCESS_TOKEN=${access_token}" >> $GITHUB_ENV
echo "SF_INSTANCE_URL=${instance_url}" >> $GITHUB_ENV

# Export for current script context
export SF_ACCESS_TOKEN="${access_token}"
export SF_INSTANCE_URL="${instance_url}"

# Login to Salesforce CLI
sf org login access-token --instance-url ${instance_url} --no-prompt --set-default --alias ${environment}

if [ $? -eq 0 ]; then
    echo "✅ Successfully authenticated to Salesforce org: ${environment}"
else
    echo "❌ Failed to login to Salesforce CLI"
    exit 1
fi