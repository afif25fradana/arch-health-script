#!/usr/bin/env bash
# ============================================================================
# Health Check Suite - Master Launcher
# ============================================================================

set -euo pipefail

find_share_dir() {
    local script_path
    script_path=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
    local script_dir
    script_dir=$(dirname "$script_path")

    if [[ -d "$script_dir/common" ]]; then
        echo "$script_dir"
        return
    fi

    local potential_dirs=(
        "/usr/local/share/health-check"
        "$HOME/.local/share/health-check"
    )

    for dir in "${potential_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return
        fi
    done

    echo ""
}

detect_and_run_os_script() {
    local share_dir="$1"
    shift

    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine OS: /etc/os-release not found."
        return 1
    fi
    source /etc/os-release

    local os_id="${ID_LIKE:-$ID}"
    local specialized_script=""

    case "$os_id" in
        *arch*)
            specialized_script="$share_dir/scripts/arch_health_check.sh"
            ;;
        *debian*|*ubuntu*)
            specialized_script="$share_dir/scripts/Ubuntu_health_check.sh"
            ;;
        *fedora*|*rhel*)
            log_info "Fedora/RHEL based system detected. No specialized script is available yet."
            return 0
            ;;
        *)
            log_error "Unsupported distribution: ${PRETTY_NAME:-$ID}."
            return 1
            ;;
    esac

    if [[ ! -x "$specialized_script" ]]; then
        log_error "Script for your distribution not found or not executable at $specialized_script"
        return 1
    fi

    log_info "Detected $(basename "$specialized_script"). Launching..."
    log_info "-----------------------------------------------------"
    exec "$specialized_script" "$@"
}

main() {
    local share_dir
    share_dir=$(find_share_dir)

    if [[ -z "$share_dir" ]]; then
        echo "Error: Could not find the health-check share directory." >&2
        exit 1
    fi

    local common_functions="$share_dir/common/functions.sh"
    if [[ ! -f "$common_functions" ]]; then
        echo "Error: Common functions library not found at $common_functions" >&2
        exit 1
    fi
    source "$common_functions"
    setup_colors

    log_info "Health Check Suite - Master Launcher"

    log_info "Detecting OS and launching the appropriate health check script..."
    detect_and_run_os_script "$share_dir" "$@"
}

main "$@"
