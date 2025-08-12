#!/usr/bin/env bash
# ============================================================================
# Common Functions Library for Health Check Suite v2.0
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

# --- NEW: Config File Parser ---
# Reads a value from a .conf file. Simple but effective.
# Usage: get_config "path/to/file.conf" "key_name" "default_value"
get_config() {
    local file="$1" key="$2" default="$3"
    if [[ -f "$file" ]]; then
        # Find the key, remove comments/whitespace, get value after '='
        local value
        value=$(grep -E "^\s*${key}\s*=" "$file" | cut -d'=' -f2 | sed 's/^\s*//;s/\s*$//')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

# --- Shared Dependency Checker (with bug fix) ---
check_dependencies() {
    # If called without an argument, exit safely.
    if [[ $# -eq 0 ]]; then echo ""; return; fi
    
    local missing_packages_str=""
    local -n dependencies_map_ref=$1

    for item in "${dependencies_map_ref[@]}"; do
        local cmd="${item%%:*}"; local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages_str+="$pkg "
        fi
    done
    echo "$missing_packages_str"
}
