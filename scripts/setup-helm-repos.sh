#!/bin/bash
# scripts/setup-helm-repos.sh
# Setup Helm repositories from configuration file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HELM_REPOS_FILE="$REPO_ROOT/helm-repos.yaml"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

setup_repositories() {
    if [[ ! -f "$HELM_REPOS_FILE" ]]; then
        error "helm-repos.yaml not found at $HELM_REPOS_FILE"
        log "If your charts have dependencies, please create helm-repos.yaml"
        return 0
    fi

    log "Loading Helm repositories from $HELM_REPOS_FILE"
    
    # Check if yq is available for proper YAML parsing
    if command -v yq &>/dev/null; then
        log "Using yq for YAML parsing"
        yq eval '.repositories[] | .name + " " + .url' "$HELM_REPOS_FILE" | while read -r name url; do
            add_repository "$name" "$url"
        done
    else
        log "Using basic YAML parsing (yq not available)"
        # Fallback parsing for basic YAML structure
        grep -A1 "name:" "$HELM_REPOS_FILE" | grep -E "(name|url):" | \
        sed 's/.*name: *//g; s/.*url: *//g' | tr -d '"' | \
        paste - - | while read -r name url; do
            if [[ -n "$name" && -n "$url" ]]; then
                add_repository "$name" "$url"
            fi
        done
    fi
}

add_repository() {
    local name="$1"
    local url="$2"
    
    log "Adding repository: $name -> $url"
    if helm repo add "$name" "$url"; then
        log "✅ Successfully added $name"
    else
        error "Failed to add repository $name ($url)"
        return 1
    fi
}

update_repositories() {
    log "Updating repository index"
    if helm repo update; then
        log "✅ Repository index updated successfully"
    else
        error "Failed to update repository index"
        return 1
    fi
}

main() {
    log "Starting Helm repository setup"
    
    setup_repositories
    update_repositories
    
    log "Helm repository setup completed"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi