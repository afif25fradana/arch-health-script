#!/usr/bin/env bash
# ============================================================================
# Common Functions Library for Health Check Suite v2.1
# ============================================================================


# --- Color Handling ---
# Sets up color variables for script output, but only if stdout is a terminal
# and the --no-color flag is not set.
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
log_subsection() { echo -e "${BLUE}--- $1 ---${NC}"; }
log_section() {
    local title=" $1 "
    local padding_char="─"
    local terminal_width
    terminal_width=$(tput cols 2>/dev/null || echo 80) # Default to 80 if tput fails
    local title_len=${#title}
    local padding_len=$(( (terminal_width - title_len) / 2 ))
    
    # Ensure padding is not negative
    if (( padding_len < 0 )); then padding_len=0; fi

    local left_padding
    left_padding=$(printf "%${padding_len}s" | tr ' ' "$padding_char")
    local right_padding
    right_padding=$(printf "%${padding_len}s" | tr ' ' "$padding_char")
    
    # Adjust for odd/even width to fill the line
    if (( (title_len + 2 * padding_len) < terminal_width )); then
        right_padding="${right_padding}${padding_char}"
    fi

    echo -e "\n${BLUE}┌${left_padding}${title}${right_padding}┐${NC}"
}

# --- Config File Parser ---
# Reads a key's value from a simple .conf file (key = value).
# Usage: get_config "path/to/file.conf" "key_name" "default_value"
get_config() {
    local file="$1" key="$2" default="$3"
    if [[ -f "$file" ]]; then
        # Find the line with the key, cut the value after '=', and trim whitespace.
        local value
        value=$(grep -E "^\s*${key}\s*=" "$file" | cut -d'=' -f2 | sed 's/^\s*//;s/\s*$//')
        if [[ -n "$value" ]]; then
            echo "$value"
            return
        fi
    fi
    echo "$default"
}

# --- Shared Dependency Checker ---
# Checks for the existence of commands and returns a space-separated string
# of corresponding package names that are missing.
# This version is more portable and avoids namerefs.
# Usage:
#   local my_deps=("cmd1:pkg1" "cmd2:pkg2")
#   local missing; missing=$(check_dependencies "${my_deps[@]}")
check_dependencies() {
    local missing_packages_str=""
    for item in "$@"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages_str+="$pkg "
        fi
    done
    echo "$missing_packages_str"
}
