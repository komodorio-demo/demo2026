#!/bin/bash
# prep-deploy-single.sh - Run prep-break for all scenarios marked with demo: true
# for a single executor slot. Designed to run inside a Kubernetes CronJob container.
#
# Environment variables:
#   EXECUTOR_NUM  - Executor slot number (1-20), set by the CronJob
#   GITHUB_TOKEN  - GitHub personal access token for PR cleanup (optional)
#
# Steps:
#   1. Clean up existing namespaces for this executor slot
#   2. Clean up GitHub PRs matching the pattern (if GITHUB_TOKEN provided)
#   3. Clone / update evaluation-scenarios repo
#   4. Discover scenarios with demo: true
#   5. Run main.sh prep-break demo{N}-{epoch} for each scenario

set -euo pipefail

#==============================================================================
# PARAMETERS
#==============================================================================

EXECUTOR_NUM="${EXECUTOR_NUM:-}"
SCENARIO_LIMIT="${SCENARIO_LIMIT:-0}"  # 0 means no limit
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

if [[ -z "$EXECUTOR_NUM" ]]; then
    echo "ERROR: EXECUTOR_NUM env var is required" >&2
    exit 1
fi

if [[ "$EXECUTOR_NUM" != "default" ]]; then
    if ! [[ "$EXECUTOR_NUM" =~ ^[0-9]+$ ]] || [[ "$EXECUTOR_NUM" -lt 1 || "$EXECUTOR_NUM" -gt 20 ]]; then
        echo "ERROR: EXECUTOR_NUM must be between 1 and 20 or 'default', got: '$EXECUTOR_NUM'" >&2
        exit 1
    fi
fi

EPOCH=$(date +%s)
SUFFIX="demo${EXECUTOR_NUM}-${EPOCH}"

#==============================================================================
# CONFIGURATION
#==============================================================================

REPO_URL="git@github.com:komodorio/evaluation-scenarios.git"
REPO_DIR="/tmp/evaluation-scenarios"
SSH_KEY_PATH="${SSH_KEY_PATH:-/ssh/id_rsa}"

# GitHub PR cleanup configuration
GITHUB_REPO="komodorio-demo/demo2026"
GITHUB_API="https://api.github.com"

# Output formatting
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[0;32m"
COLOR_RED="\033[0;31m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_BOLD="\033[1m"

print_success() { echo -e "${COLOR_GREEN}✓${COLOR_RESET} $1"; }
print_error()   { echo -e "${COLOR_RED}✗${COLOR_RESET} $1"; }
print_warning() { echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $1"; }
print_info()    { echo -e "${COLOR_BLUE}→${COLOR_RESET} $1"; }
print_header()  {
    echo ""
    echo -e "${COLOR_BOLD}$1${COLOR_RESET}"
    echo "================================================================="
}

#==============================================================================
# PREREQUISITES
#==============================================================================

print_header "Installing prerequisites"
apk add --no-cache git openssh-client util-linux curl jq 2>&1 | tail -1
print_success "git, openssh-client, curl, and jq ready"

#==============================================================================
# SSH SETUP
#==============================================================================

print_header "Configuring SSH"

mkdir -p /root/.ssh
chmod 700 /root/.ssh

if [[ -f "$SSH_KEY_PATH" ]]; then
    cp "$SSH_KEY_PATH" /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    ssh-keyscan -H github.com >> /root/.ssh/known_hosts 2>/dev/null
    print_success "SSH key configured"
else
    print_error "SSH key not found at ${SSH_KEY_PATH}"
    exit 1
fi

#==============================================================================
# CLEANUP EXISTING NAMESPACES FOR THIS EXECUTOR SLOT (ALL EPOCHS)
#==============================================================================

print_header "Cleaning up existing namespaces for demo${EXECUTOR_NUM} (all epochs)"

existing_ns=$(kubectl get ns --no-headers -o custom-columns=':metadata.name' \
    | grep -E "\-demo${EXECUTOR_NUM}-[0-9]+$" || true)

if [[ -z "$existing_ns" ]]; then
    print_info "No existing namespaces found matching demo${EXECUTOR_NUM}"
else
    print_info "Found namespaces to delete:"
    echo "$existing_ns" | while read -r ns; do
        echo "  - ${ns}"
    done
    echo "$existing_ns" | xargs kubectl delete ns --ignore-not-found=true --wait=false
    print_info "Waiting for namespaces to fully terminate..."
    while kubectl get ns --no-headers -o custom-columns=':metadata.name' \
            | grep -qE "\-demo${EXECUTOR_NUM}-[0-9]+$"; do
        sleep 3
    done
    print_success "All demo${EXECUTOR_NUM} namespaces terminated"
fi

#==============================================================================
# CLEANUP GITHUB PRS MATCHING PATTERN
#==============================================================================

if [[ -n "$GITHUB_TOKEN" ]]; then
    print_header "Cleaning up GitHub PRs matching *-demo${EXECUTOR_NUM}-* pattern"
    
    # Search for open PRs with matching labels or branch names
    pr_count=0
    page=1
    
    while true; do
        prs=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "${GITHUB_API}/repos/${GITHUB_REPO}/pulls?state=open&per_page=100&page=${page}")
        
        # Check if we got any PRs
        pr_page_count=$(echo "$prs" | jq '. | length')
        if [[ "$pr_page_count" -eq 0 ]]; then
            break
        fi
        
        # Find PRs with matching labels or branch names
        matching_prs=$(echo "$prs" | jq -r --arg pattern "demo${EXECUTOR_NUM}" \
            '.[] | select(
                (.head.ref | contains("-" + $pattern + "-")) or
                (.labels[]?.name? | contains("-" + $pattern + "-"))
            ) | .number')
        
        if [[ -n "$matching_prs" ]]; then
            echo "$matching_prs" | while read -r pr_number; do
                if [[ -n "$pr_number" ]]; then
                    pr_info=$(echo "$prs" | jq -r --arg num "$pr_number" \
                        '.[] | select(.number == ($num | tonumber)) | "\(.title) (branch: \(.head.ref))"')
                    
                    print_info "Closing PR #${pr_number}: ${pr_info}"
                    
                    # Close the PR with a comment
                    curl -s -X PATCH \
                        -H "Authorization: token $GITHUB_TOKEN" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "${GITHUB_API}/repos/${GITHUB_REPO}/pulls/${pr_number}" \
                        -d '{"state":"closed"}' > /dev/null
                    
                    curl -s -X POST \
                        -H "Authorization: token $GITHUB_TOKEN" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "${GITHUB_API}/repos/${GITHUB_REPO}/issues/${pr_number}/comments" \
                        -d "{\"body\":\"Automatically closed by demo${EXECUTOR_NUM} cleanup script during prep-deploy run.\"}" > /dev/null
                    
                    ((pr_count++))
                fi
            done
        fi
        
        ((page++))
    done
    
    if [[ $pr_count -eq 0 ]]; then
        print_info "No matching PRs found"
    else
        print_success "Closed ${pr_count} PR(s) matching demo${EXECUTOR_NUM} pattern"
    fi
else
    print_warning "GITHUB_TOKEN not provided, skipping PR cleanup"
fi

#==============================================================================
# CLONE / UPDATE REPOSITORY
#==============================================================================

print_header "Setting up evaluation-scenarios repository"

if [[ -d "${REPO_DIR}/.git" ]]; then
    print_info "Updating existing repo at ${REPO_DIR}..."
    git -C "$REPO_DIR" pull --ff-only
    print_success "Repository updated"
else
    print_info "Cloning ${REPO_URL}..."
    git clone "$REPO_URL" "$REPO_DIR"
    print_success "Repository cloned"
fi

#==============================================================================
# DISCOVER SCENARIOS WITH demo: true
#==============================================================================

print_header "Discovering scenarios with demo: true"

scenarios=()

for metadata_file in "${REPO_DIR}/scenarios/"*/metadata.yaml; do
    [[ ! -f "$metadata_file" ]] && continue

    scenario_dir="$(dirname "$metadata_file")"
    scenario_name="$(basename "$scenario_dir")"
    main_sh="${scenario_dir}/main.sh"

    if [[ ! -x "$main_sh" ]]; then
        print_warning "Skipping '${scenario_name}': no executable main.sh"
        continue
    fi

    if grep -q "^demo: true" "$metadata_file" 2>/dev/null; then
        scenarios+=("$main_sh")
        print_info "  Found: ${scenario_name}"
    fi
done

if [[ ${#scenarios[@]} -eq 0 ]]; then
    print_error "No scenarios found with demo: true"
    exit 1
fi

# Apply scenario limit if set
total_found="${#scenarios[@]}"
if [[ "$SCENARIO_LIMIT" -gt 0 && "$SCENARIO_LIMIT" -lt "$total_found" ]]; then
    scenarios=("${scenarios[@]:0:$SCENARIO_LIMIT}")
    print_warning "Limiting to ${SCENARIO_LIMIT} of ${total_found} scenario(s)"
fi

print_success "Running ${#scenarios[@]} scenario(s) marked as demo"

#==============================================================================
# RUN SCENARIOS IN PARALLEL
#==============================================================================

print_header "Running ${#scenarios[@]} scenario(s) in parallel with suffix: ${SUFFIX}"
echo "Epoch: ${EPOCH}"
echo ""

pids=()
scenario_names=()

for main_sh in "${scenarios[@]}"; do
    scenario_name="$(basename "$(dirname "$main_sh")")"
    print_info "Starting: ${scenario_name}"
    "$main_sh" prep-break "$SUFFIX" &
    pids+=($!)
    scenario_names+=("$scenario_name")
done

failed=0
for idx in "${!pids[@]}"; do
    pid="${pids[$idx]}"
    name="${scenario_names[$idx]}"
    if wait "$pid"; then
        print_success "${name}"
    else
        print_error "${name} FAILED"
        failed=1
    fi
done

#==============================================================================
# SUMMARY
#==============================================================================

print_header "Summary"
echo ""
echo "Executor:           demo${EXECUTOR_NUM}"
echo "Suffix:             ${SUFFIX}"
if [[ "$SCENARIO_LIMIT" -gt 0 ]]; then
    echo "Scenarios run:      ${#scenarios[@]} (limit: ${SCENARIO_LIMIT})"
else
    echo "Scenarios run:      ${#scenarios[@]}"
fi
if [[ -n "$GITHUB_TOKEN" ]]; then
    echo "PRs closed:         ${pr_count}"
fi
echo ""

if [[ $failed -eq 0 ]]; then
    print_success "All scenarios completed successfully"
else
    print_error "One or more scenarios failed"
    exit 1
fi