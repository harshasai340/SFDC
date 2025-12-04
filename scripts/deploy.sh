#!/usr/bin/env bash
# GitHub Actions version of deploy.sh
# Handles Salesforce deployment with GitHub Actions environment variables

set -x
sf_target_org=$1
sf_job_id=$2
publish_path=$3
testClasses=$4

base_dir="/tmp/deployment"

echo "BASE DIR: $base_dir"
echo "=== DEPLOYMENT INPUT VALIDATION ==="
echo "sf_target_org: $sf_target_org"
echo "sf_job_id: $sf_job_id"
echo "testClasses: $testClasses"
echo "publish_path: $publish_path"

if [ ! -d "${base_dir}/force-app/main/default" ] || [ -z "$(find ${base_dir}/force-app/main/default -type f -print -quit)" ]; then
    echo "[[INFO]]: No changes found in ${base_dir}/force-app/main/default. Skipping Salesforce Deployment."
    # Set GitHub Actions output
    echo "deploy-status=skipped" >> $GITHUB_OUTPUT
    exit 0
fi

cd ${base_dir}
echo "Deploying Salesforce manifest....."
echo "Deployment ID: ${sf_job_id}"
echo "[[ TESTS INFO ]]: $testClasses"

# Check for ApexClass or ApexTrigger in manifest/package.xml
has_apex_in_package=$(grep -E "<name>(ApexClass|ApexTrigger)</name>" manifest/package.xml | wc -l)
run_apex_tests=true
if [[ "$has_apex_in_package" == "0" && ( -z "$testClasses" || "$testClasses" == "" ) ]]; then
  echo "manifest/package.xml does not contain ApexClass or testClasses. Skipping Run Apex Tests."
  run_apex_tests=false
fi

# Handle bypass deployments for safe metadata types (WebLinks, Flows) in problematic orgs
if [[ "$sf_job_id" =~ ^(weblink|flow|metadata)-(bypass|force)- ]]; then
  echo "🚨 Detected metadata bypass deployment ID: $sf_job_id"
  echo "📋 Proceeding with direct metadata deployment (bypassing validation)"
  
  # Check if this is indeed safe metadata-only package
  is_weblink_only=$(grep -E "<name>WebLink</name>" manifest/package.xml | wc -l)
  is_flow_only=$(grep -E "<name>Flow</name>" manifest/package.xml | wc -l)
  has_apex_in_package=$(grep -E "<name>(ApexClass|ApexTrigger)</name>" manifest/package.xml | wc -l)
  is_safe_metadata=$((is_weblink_only + is_flow_only))
  
  # Determine metadata type for messaging
  metadata_type=""
  if [[ "$is_weblink_only" -gt "0" ]]; then
    metadata_type="${metadata_type}WebLink "
  fi
  if [[ "$is_flow_only" -gt "0" ]]; then
    metadata_type="${metadata_type}Flow "
  fi
  
  if [[ "$is_safe_metadata" -gt "0" && "$has_apex_in_package" == "0" ]]; then
    echo "✅ Confirmed ${metadata_type}deployment - safe to deploy without validation"
    
    sf project deploy start --manifest manifest/package.xml \
      --target-org ${sf_target_org} \
      --ignore-warnings \
      --wait 60 \
      --json > ${publish_path}/deploy.json
    
    deploymentStatus=$(jq -r '.status' ${publish_path}/deploy.json)
    if [[ "$deploymentStatus" == "0" ]]; then
      echo "✅ ${metadata_type}deployment succeeded"
      echo "deploy-status=success" >> $GITHUB_OUTPUT
      exit 0
    else
      echo "❌ ${metadata_type}deployment failed"
      cat ${publish_path}/deploy.json
      echo "deploy-status=failed" >> $GITHUB_OUTPUT
      exit 1
    fi
  else
    echo "⚠️  Bypass deployment ID used for non-safe-metadata package - falling back to normal deployment"
    sf_job_id=""
  fi
fi

# Since validation succeeds but quick deploy fails consistently,
# bypass quick deploy and use direct deployment for reliability
echo "🔄 Bypassing quick deploy - using direct deployment for better reliability with delta changes."
sf_job_id=""

max_retries=3
attempt=1
success=0

while [ $attempt -le $max_retries ]; do
  echo "🚀 Deployment attempt $attempt of $max_retries"

  if [[ "$run_apex_tests" == "false" ]]; then
    echo "📋 No Apex components detected; deploying without running any test classes (NoTestRun)."
    sf project deploy start --manifest manifest/package.xml \
      --target-org ${sf_target_org} \
      --test-level NoTestRun \
      --ignore-warnings \
      --wait 60 \
      --json > ${publish_path}/deploy.json
  else
    if [[ -n "${sf_job_id}" && "${sf_job_id}" != "" ]]; then
      echo "📦 Using quick deploy with validation ID: ${sf_job_id}"
      # Try quick deploy first
      sf project deploy quick --job-id ${sf_job_id} --target-org ${sf_target_org} --json > ${publish_path}/deploy.json
      deploymentStatus=$(jq -r '.status' ${publish_path}/deploy.json)
      
      if [[ "$deploymentStatus" == "0" ]]; then
        echo "✅ Quick deployment succeeded on attempt $attempt"
        success=1
        break
      else
        echo "⚠️  Quick deploy failed on attempt $attempt, trying regular deployment"
        # Quick deploy failed, fall back to regular deployment
        if [[ -n "${testClasses}" && "${testClasses}" != "" ]]; then
          echo "📋 Fallback: Running regular deployment with specific test classes: ${testClasses}"
          sf project deploy start --manifest manifest/package.xml \
            --target-org ${sf_target_org} \
            --test-level RunSpecifiedTests \
            --tests ${testClasses} \
            --ignore-warnings \
            --wait 60 \
            --json > ${publish_path}/deploy.json
        else
          echo "📋 Fallback: Running regular deployment with RunLocalTests"
          sf project deploy start --manifest manifest/package.xml \
            --target-org ${sf_target_org} \
            --test-level RunLocalTests \
            --ignore-warnings \
            --wait 60 \
            --json > ${publish_path}/deploy.json
        fi
      fi
    else
      echo "🔄 No valid deploy ID, using direct deployment with manifest"
      # Determine test level based on available test classes
      if [[ -n "${testClasses}" && "${testClasses}" != "" ]]; then
        echo "📋 Running deployment with specific test classes: ${testClasses}"
        sf project deploy start --manifest manifest/package.xml \
          --target-org ${sf_target_org} \
          --test-level RunSpecifiedTests \
          --tests ${testClasses} \
          --ignore-warnings \
          --wait 60 \
          --json > ${publish_path}/deploy.json
      else
        echo "📋 Running deployment with RunLocalTests"
        sf project deploy start --manifest manifest/package.xml \
          --target-org ${sf_target_org} \
          --test-level RunLocalTests \
          --ignore-warnings \
          --wait 60 \
          --json > ${publish_path}/deploy.json
      fi
    fi
  fi

  cat ${publish_path}/deploy.json
  deploymentStatus=$(jq -r '.status' ${publish_path}/deploy.json)

  if [[ "$deploymentStatus" == "0" ]]; then
    echo "✅ Deployment succeeded on attempt $attempt"
    success=1
    break
  else
    echo "❌ Deployment failed on attempt $attempt"
    if [ $attempt -lt $max_retries ]; then
      echo "⏳ Waiting 30 seconds before retry..."
      sleep 30
    fi
  fi

  attempt=$((attempt + 1))
done

if [[ "$success" == "1" ]]; then
  echo "🎉 Deployment completed successfully!"
  echo "deploy-status=success" >> $GITHUB_OUTPUT
else
  echo "💥 Deployment failed after $max_retries attempts"
  echo "deploy-status=failed" >> $GITHUB_OUTPUT

  # Additional error information
  echo "=== DEPLOYMENT ERROR DETAILS ==="
  if [ -f "${publish_path}/deploy.json" ]; then
    jq -r '.message' ${publish_path}/deploy.json 2>/dev/null || echo "Could not parse deployment error message"
  fi
  echo "================================"

  exit 1
fi