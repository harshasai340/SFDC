#!/usr/bin/env bash
# GitHub Actions version of sfdelta.sh
# Handles delta deployment preparation with GitHub Actions environment variables

set -x
echo "Preparing Salesforce and Vlocity deployments..."
repo_name="apm0013074-asf-cloudrunner"

# Create required directories
mkdir -p /tmp/deployment/force-app/main/default
mkdir -p /tmp/deployment/vlocity
base_dir="/tmp/deployment"
sf_base_dir="${base_dir}"
vlocity_dir="${base_dir}/vlocity"

# Accept branch parameters dynamically (these can be passed from GitHub Actions)
source_branch=$1
target_branch=$2
delta_mode=$3

echo "Source Branch: $source_branch"
echo "Target Branch: $target_branch"
echo "Delta Mode: $delta_mode"

# --- PR branch conversion ---
# If the source_branch is a PR merge ref (e.g. refs/pull/6/merge), convert it to the PR head ref
if [[ "$source_branch" =~ ^refs/pull/([0-9]+)/merge$ ]]; then
    pr_number=${BASH_REMATCH[1]}
    echo "Detected PR merge ref for PR number $pr_number. Converting to PR head ref."
    source_branch="pull/${pr_number}/merge"
    echo "Updated source branch: $source_branch"
fi

# Also fetch all PR head refs so that they are available locally:
git fetch origin +refs/pull/*/head:refs/remotes/origin/pr/*

echo "Source Branch: $source_branch"
echo "Target Branch: $target_branch"

##############################################
# FUNCTIONS (Adapted for GitHub Actions)
##############################################

# Get the latest merge commit from the target branch
function getLatestMergeCommit() {
    cd ${GITHUB_WORKSPACE}/${repo_name}
    git pull origin ${source_branch} > /dev/null 2>&1
    git fetch --all > /dev/null 2>&1
    latest_commit=${GITHUB_SHA}
    echo "$latest_commit"
}

# Update meta XML files list if missing
function updateMetaxmlfiles(){
    cd ${GITHUB_WORKSPACE}/${repo_name}
    for file_path in $(cat $base_dir/latest_commit_delta.txt); do
        check_file_path=$(grep "${file_path}-meta.xml" $base_dir/latest_commit_delta.txt)
        if [ -z "$check_file_path" ]; then
            echo "${file_path}-meta.xml" >> $base_dir/latest_commit_delta.txt
        else
            echo "Meta for the ${file_path} exists in latest_commit_delta.txt"
        fi 
    done
}

function findTestClasses(){
    changed_files_list="$1"
    output_file="$2"

    if [[ -z "$changed_files_list" || -z "$output_file" ]]; then
    echo "Usage: $0 <changed_files.txt> <output_file.txt>"
    exit 1
    fi

    > "$output_file"

    # Test class naming patterns
    test_patterns=(
    "%s_test.cls"
    "%sTest.cls"
    "%s_Test.cls"
    "%sTests.cls"
    )

    while IFS= read -r changed_file; do
    [[ -z "$changed_file" ]] && continue

    # Only process .cls files
    if [[ "$changed_file" != *.cls ]]; then
        continue
    fi

    echo "$changed_file" >> "$output_file"

    dir_path=$(dirname "$changed_file")
    base_name=$(basename "$changed_file" .cls)

    for pattern in "${test_patterns[@]}"; do
        test_file=$(printf "$pattern" "$base_name")
        test_file_path="$dir_path/$test_file"

        if [[ -f "$test_file_path" ]]; then
        echo "$test_file_path" >> "$output_file"
        break
        fi
    done
    done < "$changed_files_list"

    sort "$output_file" -o "$output_file"
}

# Deploy latest commit changes
function deployLatestMergeCommitChanges() {
    cd ${GITHUB_WORKSPACE}/${repo_name}
    
    # Get the latest merge commit
    latest_commit=$(getLatestMergeCommit)
    echo "Latest commit from ${target_branch}: $latest_commit"
    
    # Use GitHub Actions environment variables instead of Azure DevOps
    if [ "$delta_mode" = "pr" ]; then
        echo "PR mode - finding changes between base and PR head"
        # For PR, compare against the base branch
        git diff --name-only origin/${target_branch}...HEAD > $base_dir/latest_commit_delta.txt
    else
        echo "Commit mode - finding changes in latest commit"
        # For direct commits, show changes in the latest commit
        git diff --name-only HEAD~1 HEAD > $base_dir/latest_commit_delta.txt
    fi
    
    echo "=== DELTA FILES FOUND ==="
    cat $base_dir/latest_commit_delta.txt
    echo "Total delta files: $(wc -l < $base_dir/latest_commit_delta.txt)"
    echo "Class files in delta: $(grep -c '\.cls$' $base_dir/latest_commit_delta.txt || echo 0)"
    echo "Trigger files in delta: $(grep -c '\.trigger$' $base_dir/latest_commit_delta.txt || echo 0)"
    echo "========================="
    
    rm -rf "$base_dir/force-app/main/default/lwc/"*
    mkdir -p "$base_dir/force-app/main/default/lwc/"
    
    # Copy changed files to the deployment directory, handling LWC parent folders
    echo "Copying delta files from $(pwd) to $sf_base_dir..."
    
    declare -A lwc_parents
    while IFS= read -r change; do
        [[ -z "$change" ]] && continue
        echo "Processing file: $change"
        
        if [[ "$change" == force-app/main/default/lwc/*/* ]]; then
            lwc_parent=$(echo "$change" | awk -F'/' '{print $1"/"$2"/"$3"/"$4"/"$5}')
            lwc_parents["$lwc_parent"]=1
            echo "Marked LWC parent for copying: $lwc_parent"
        else
            if [ -e "$change" ]; then
                echo "Copying file: $change"
                mkdir -p "$sf_base_dir/$(dirname "$change")"
                cp "$change" "$sf_base_dir/$change"
                
                # Copy corresponding meta.xml if it exists
                if [ -e "${change}-meta.xml" ]; then
                    echo "Copying meta file: ${change}-meta.xml"
                    cp "${change}-meta.xml" "$sf_base_dir/${change}-meta.xml"
                fi
            else
                echo "File not found, might be deleted: $change"
            fi
        fi
    done < $base_dir/latest_commit_delta.txt
    
    # Copy entire LWC parent folders
    for lwc_parent in "${!lwc_parents[@]}"; do
        if [ -d "$lwc_parent" ]; then
            echo "Copying entire LWC folder: $lwc_parent"
            mkdir -p "$sf_base_dir/$(dirname "$lwc_parent")"
            cp -r "$lwc_parent" "$sf_base_dir/$lwc_parent"
        fi
    done
    
    updateMetaxmlfiles
    
    echo "=== DEPLOYMENT PREPARATION COMPLETE ==="
    echo "Source files copied to: $sf_base_dir"
    echo "Vlocity files prepared in: $vlocity_dir"
}

##############################################
# MAIN EXECUTION
##############################################

echo "Starting delta deployment preparation..."
deployLatestMergeCommitChanges

echo "✅ Delta deployment preparation completed successfully"