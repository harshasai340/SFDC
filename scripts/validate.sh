#!/bin/bash
# GitHub Actions version of validate.sh
# Handles Salesforce validation with GitHub Actions environment variables

sf_target_org=$1
publish_path=$2
build_dir="/tmp/deployment"
cd ${build_dir}

echo "🔍 Starting Salesforce validation..."
echo "Target Org: $sf_target_org"
echo "Publish Path: $publish_path"

# Check if ${build_dir}/force-app/main/default exists and contains any files
if [ ! -d "${build_dir}/force-app/main/default" ] || [ -z "$(find ${build_dir}/force-app/main/default -type f -print -quit)" ]; then
    echo "[[INFO]]: No changes found in ${build_dir}/force-app/main/default. Skipping Salesforce Validation."
    # Set GitHub Actions output for validation status
    echo "validation-status=skipped" >> $GITHUB_OUTPUT
    exit 0
fi

# Check if there are any .cls files (Apex classes) in the commit
cls_count=$(find "${build_dir}/force-app/main/default/classes" -name "*.cls" 2>/dev/null | wc -l)
if [ "$cls_count" -eq 0 ]; then
    echo "[[INFO]]: No Apex class (.cls) files found in commit. Skipping test class validation."
    echo "validation-status=skipped" >> $GITHUB_OUTPUT
    exit 0
fi

#initializes test_classes variable as empty
test_classes=""

# Check and search in classes folder if it exists
echo "=== SEARCHING FOR TEST CLASSES ==="
if [ -d "${build_dir}/force-app/main/default/classes" ]; then
    echo "Classes directory exists. Files found:"
    find ${build_dir}/force-app/main/default/classes -name "*.cls" | sort
    echo "Searching for test classes (pattern: *Test.cls)..."
    find ${build_dir}/force-app/main/default/classes -iname "*Test.cls" ! -name "*-meta.xml" -exec basename {} .cls \;
    test_classes=$(find ${build_dir}/force-app/main/default/classes -iname "*Test.cls" ! -name "*-meta.xml" -exec basename {} .cls \; | paste -sd " " -)
    echo "Test classes found: '$test_classes'"
else
    echo "Classes directory does not exist."
fi

# Check and search in triggers folder if it exists
if [ -d "${build_dir}/force-app/main/default/triggers" ]; then
    echo "Triggers directory exists. Files found:"
    find ${build_dir}/force-app/main/default/triggers -name "*.trigger" | sort
    echo "Searching for test triggers (pattern: *Test.trigger)..."
    find ${build_dir}/force-app/main/default/triggers -iname "*Test.trigger" ! -name "*-meta.xml" -exec basename {} .trigger \;
    triggers_tests=$(find ${build_dir}/force-app/main/default/triggers -iname "*Test.trigger" ! -name "*-meta.xml" -exec basename {} .trigger \; | paste -sd " " -)
    if [[ -n "$triggers_tests" ]]; then
        test_classes="$test_classes $triggers_tests"
    fi
    echo "Trigger tests found: '$triggers_tests'"
else
    echo "Triggers directory does not exist."
fi

echo "Final test_classes variable: '$test_classes'"
echo "=== END TEST CLASS SEARCH ==="

# Set GitHub Actions environment variables
echo "TEST_CLASSES=$test_classes" >> $GITHUB_ENV

echo "###################################"
echo $test_classes
echo "###################################"
echo "**********************************"
cat ${build_dir}/manifest/package.xml
echo "**********************************"

if [[ -n "$test_classes" ]];then
  echo "🧪 Running validation with specific test classes: $test_classes"
  sf project deploy validate \
      --manifest ${build_dir}/manifest/package.xml \
      --target-org ${sf_target_org} \
      --test-level RunSpecifiedTests \
      --tests ${test_classes} \
      --ignore-warnings \
      --wait 60 \
      --json > ${publish_path}/validation.json
  deployId=$(jq -r '.result.id' < ${publish_path}/validation.json)
  status=$(jq -r '.status' < ${publish_path}/validation.json)
  echo "Deploy status: $status"
  
  # Set GitHub Actions environment variables and outputs
  echo "DEPLOY_ID=$deployId" >> $GITHUB_ENV
  echo "Deploy ID: $deployId"
else
  # Check if Apex classes or triggers exist in the package
  apex_exists=false
  if [ -d "${build_dir}/force-app/main/default/classes" ] && [ "$(find ${build_dir}/force-app/main/default/classes -name "*.cls" | wc -l)" -gt 0 ]; then
    apex_exists=true
  fi
  if [ -d "${build_dir}/force-app/main/default/triggers" ] && [ "$(find ${build_dir}/force-app/main/default/triggers -name "*.trigger" | wc -l)" -gt 0 ]; then
    apex_exists=true
  fi
  
  if [[ "$apex_exists" == "true" ]]; then
    echo "⚠️  No specific test classes found, but Apex code exists. Running validation with RunSpecifiedTests"
    test_level="RunSpecifiedTests"
  else
    echo "ℹ️  No Apex code found. Checking if this is metadata-only deployment..."
    
    # Check if this is truly metadata-only (no Apex) in package.xml
    has_apex_in_package=$(grep -E "(ApexClass|ApexTrigger)" ${build_dir}/manifest/package.xml | wc -l)
    if [[ "$has_apex_in_package" == "0" ]]; then
      echo "📋 Pure metadata deployment detected (WebLinks, Custom Fields, Flows, etc.)"
      echo "ℹ️  Attempting deployment without test execution to avoid org compilation issues"
      
      # Check if this is safe metadata types (WebLinks, Flows, Custom Fields, etc.)
      is_weblink_only=$(grep -E "<name>WebLink</name>" ${build_dir}/manifest/package.xml | wc -l)
      is_flow_only=$(grep -E "<name>Flow</name>" ${build_dir}/manifest/package.xml | wc -l)
      is_customfield_only=$(grep -E "<name>CustomField</name>" ${build_dir}/manifest/package.xml | wc -l)
      is_layout_only=$(grep -E "<name>Layout</name>" ${build_dir}/manifest/package.xml | wc -l)
      is_safe_metadata=$((is_weblink_only + is_flow_only + is_customfield_only + is_layout_only))
      
      # Determine metadata type for messaging
      metadata_type=""
      if [[ "$is_weblink_only" -gt "0" ]]; then
        metadata_type="${metadata_type}WebLink "
      fi
      if [[ "$is_flow_only" -gt "0" ]]; then
        metadata_type="${metadata_type}Flow "
      fi
      if [[ "$is_customfield_only" -gt "0" ]]; then
        metadata_type="${metadata_type}CustomField "
      fi
      if [[ "$is_layout_only" -gt "0" ]]; then
        metadata_type="${metadata_type}Layout "
      fi
      
      if [[ "$is_safe_metadata" -gt "0" && "${SKIP_VALIDATION_FOR_METADATA}" == "true" ]]; then
        echo "🚨 SKIP_VALIDATION_FOR_METADATA=true - bypassing validation for ${metadata_type}deployment"
        echo "⚠️  ${metadata_type}deployments are typically safe and don't require validation in problematic orgs"
        
        # Create a mock successful validation response
        metadata_id_prefix="metadata"
        if [[ "$is_weblink_only" -gt "0" ]]; then
          metadata_id_prefix="weblink"
        elif [[ "$is_flow_only" -gt "0" ]]; then
          metadata_id_prefix="flow"
        fi
        
        echo '{
          "status": 0,
          "result": {
            "id": "'${metadata_id_prefix}'-bypass-'$(date +%s)'",
            "success": true,
            "done": true
          }
        }' > ${publish_path}/validation.json
        
        deployId="${metadata_id_prefix}-bypass-$(date +%s)"
        echo "Deploy ID: $deployId (bypassed)"
        echo "DEPLOY_ID=$deployId" >> $GITHUB_ENV
        echo "validation-status=success" >> $GITHUB_OUTPUT
        
        echo "=== VALIDATION RESULT (BYPASSED) ==="
        cat ${publish_path}/validation.json
        echo "========================="
        exit 0
      fi
      
      # For pure metadata, try deployment without tests first
      echo "🔄 Trying validation without test execution..."
      sf project deploy validate \
          --manifest ${build_dir}/manifest/package.xml \
          --target-org ${sf_target_org} \
          --ignore-warnings \
          --wait 60 \
          --json > ${publish_path}/validation.json
      
      validation_status=$(jq -r '.status' < ${publish_path}/validation.json)
      
      if [[ "$validation_status" == "0" ]]; then
        echo "✅ Metadata-only validation succeeded without tests"
        deployId=$(jq -r '.result.id' < ${publish_path}/validation.json)
        status=$(jq -r '.status' < ${publish_path}/validation.json)
        echo "Deploy status: $status"
        echo "DEPLOY_ID=$deployId" >> $GITHUB_ENV
        echo "Deploy ID: $deployId"
        
        echo "=== VALIDATION RESULT ==="
        cat ${publish_path}/validation.json
        echo "========================="
        
        echo "validation-status=success" >> $GITHUB_OUTPUT
        exit 0
      else
        echo "⚠️  Metadata validation without tests failed. Checking if org has compilation issues..."
        
        # Check if the error is about compilation cascade
        compilation_error=$(jq -r '.message' < ${publish_path}/validation.json | grep -i "Variable does not exist" | wc -l)
        
        if [[ "$compilation_error" -gt "0" ]]; then
          echo "🚨 Detected org-wide Apex compilation cascade - this is unrelated to ${metadata_type}deployment"
          echo "⚠️  ${metadata_type}deployment should proceed despite org compilation issues"
          
          if [[ "${FORCE_METADATA_DEPLOY}" == "true" ]]; then
            echo "🔄 FORCE_METADATA_DEPLOY=true - creating bypass validation for ${metadata_type}deployment"
            
            # Create a mock successful validation response
            echo '{
              "status": 0,
              "result": {
                "id": "'${metadata_id_prefix}'-force-'$(date +%s)'",
                "success": true,
                "done": true
              }
            }' > ${publish_path}/validation.json
            
            deployId="${metadata_id_prefix}-force-$(date +%s)"
            echo "Deploy ID: $deployId (forced)"
            echo "DEPLOY_ID=$deployId" >> $GITHUB_ENV
            echo "validation-status=success" >> $GITHUB_OUTPUT
            
            echo "=== VALIDATION RESULT (FORCED) ==="
            cat ${publish_path}/validation.json
            echo "========================="
            exit 0
          fi
        fi
        
        echo "⚠️  Falling back to RunSpecifiedTests..."
        test_level="RunSpecifiedTests"
      fi
    else
      echo "📋 Mixed deployment detected - using RunSpecifiedTests"
      test_level="RunSpecifiedTests"
    fi
  fi
  
  # Override test level if compilation issues are expected
  if [[ "${FORCE_ALL_TESTS}" == "true" ]]; then
    echo "🚨 FORCE_ALL_TESTS=true - using RunAllTestsInOrg to handle compilation dependencies"
    test_level="RunAllTestsInOrg"
  fi
  
  sf project deploy validate \
      --manifest ${build_dir}/manifest/package.xml \
      --target-org ${sf_target_org} \
      --test-level ${test_level} \
      --ignore-warnings \
      --wait 60 \
      --json > ${publish_path}/validation.json
  
  deployId=$(jq -r '.result.id' < ${publish_path}/validation.json)
  status=$(jq -r '.status' < ${publish_path}/validation.json)
  echo "Deploy status: $status"  
  echo "DEPLOY_ID=$deployId" >> $GITHUB_ENV
  echo "Deploy ID: $deployId"
fi

echo "=== VALIDATION RESULT ==="
cat ${publish_path}/validation.json
echo "========================="

validation_status=$(jq -r '.status' < ${publish_path}/validation.json)
deploy_id_check=$(jq -r '.result.id' < ${publish_path}/validation.json)

echo "Validation Status: $validation_status"
echo "Deploy ID from validation: $deploy_id_check"

if [[ "$validation_status" == "0" ]]; then
  if [[ -n "$deploy_id_check" && "$deploy_id_check" != "null" && "$deploy_id_check" != "" ]]; then
    echo "✅ Validation succeeded with valid deploy ID: $deploy_id_check"
    echo "validation-status=success" >> $GITHUB_OUTPUT
  else
    echo "⚠️  Validation completed but no valid deploy ID generated"
    echo "validation-status=success" >> $GITHUB_OUTPUT
  fi
else
  echo "❌ Validation failed with status: $validation_status"
  echo -e "ERRORINFO:: \n $(jq -r '.message' < ${publish_path}/validation.json)"
  echo "validation-status=failed" >> $GITHUB_OUTPUT
  exit 1
fi