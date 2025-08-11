#!/bin/bash
# scripts/update-chart-dependencies.sh
# Update dependencies for all charts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHARTS_DIR="$REPO_ROOT/charts"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

update_chart_dependencies() {
    local chart_dir="$1"
    local chart_name
    chart_name=$(basename "$chart_dir")
    
    log "Updating dependencies for chart: $chart_name"
    
    cd "$chart_dir"
    
    # Remove existing Chart.lock to force fresh dependency resolution
    if [[ -f "Chart.lock" ]]; then
        log "Removing existing Chart.lock for $chart_name"
        rm Chart.lock
    fi
    
    # Check if chart has dependencies
    if ! grep -q "dependencies:" Chart.yaml 2>/dev/null; then
        log "No dependencies found for $chart_name, skipping"
        return 0
    fi
    
    # Update dependencies
    if helm dependency update; then
        log "✅ Dependencies updated successfully for $chart_name"
    else
        error "Failed to update dependencies for $chart_name"
        return 1
    fi
}

main() {
    log "Starting chart dependencies update"
    
    if [[ ! -d "$CHARTS_DIR" ]]; then
        error "Charts directory not found: $CHARTS_DIR"
        exit 1
    fi
    
    local failed_charts=()
    local updated_charts=()
    
    # Process each chart directory
    for chart_dir in "$CHARTS_DIR"/*/; do
        if [[ -f "$chart_dir/Chart.yaml" ]]; then
            chart_name=$(basename "$chart_dir")
            
            # Save current directory
            pushd "$REPO_ROOT" > /dev/null
            
            if update_chart_dependencies "$chart_dir"; then
                updated_charts+=("$chart_name")
            else
                failed_charts+=("$chart_name")
            fi
            
            # Restore directory
            popd > /dev/null
        fi
    done
    
    # Summary
    log "Chart dependencies update completed"
    log "Successfully updated: ${#updated_charts[@]} charts"
    if [[ ${#failed_charts[@]} -gt 0 ]]; then
        error "Failed to update: ${#failed_charts[@]} charts: ${failed_charts[*]}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi