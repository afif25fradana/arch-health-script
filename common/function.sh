#!/usr/bin/env bash
# ============================================================================
# Common Functions Library for Health Check Suite v1.1
# ============================================================================

# --- Color Handling ---
setup_colors() {
    if [[ -t 1 && "${opt_no_color:-false}" == false ]]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    else
        RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
    fi
}

# --- Logging Functions ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# --- NEW: Shared Dependency Checker ---
# Takes a list of "command:package" pairs and checks if the command exists.
# Returns a space-separated string of missing packages.
check_dependencies() {
    local missing_packages_str=""
    # The first argument is a reference to the array passed from the caller
    local -n dependencies_map_ref=$1

    for item in "${dependencies_map_ref[@]}"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages_str+="$pkg "
        fi
    done
    # Return the string of missing packages
    echo "$missing_packages_str"
}
