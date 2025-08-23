#!/usr/bin/env bash
# ============================================================================
# Common Functions Library for Health Check Suite
# ============================================================================


setup_colors() {
    if [[ -t 1 && "${opt_no_color:-false}" == "false" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        NC=""
    fi
}

log() {
    local type="$1"
    local message="$2"
    local color="$3"
    echo -e "${color}[$type]${NC} $message"
}

log_info() { log "INFO" "$1" "$GREEN"; }
log_warn() { log "WARN" "$1" "$YELLOW"; }
log_error() { log "ERROR" "$1" "$RED"; }
log_subsection() { echo -e "${BLUE}--- $1 ---${NC}"; }

log_section() {
    local title=" $1 "
    local padding_char="─"
    local terminal_width
    terminal_width=$(tput cols 2>/dev/null || echo 80)
    local title_len=${#title}
    local padding_len=$(((terminal_width - title_len) / 2))

    ((padding_len < 0)) && padding_len=0

    local padding
    padding=$(printf "%${padding_len}s" | tr ' ' "$padding_char")

    local right_padding="$padding"
    if (((title_len + 2 * padding_len) < terminal_width)); then
        right_padding="${padding}${padding_char}"
    fi

    echo -e "\n${BLUE}┌${padding}${title}${right_padding}┐${NC}"
}

get_config() {
    local config_file="$1"
    local key="$2"
    local default_value="$3"
    local value

    if [[ ! -f "$config_file" ]]; then
        echo "$default_value"
        return
    fi

    value=$(grep -E "^\s*${key}\s*=" "$config_file" | cut -d'=' -f2- | sed 's/^\s*//;s/\s*$//')

    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

load_config() {
    local config_file="$1"
    shift
    while (($# > 0)); do
        local key="$1"
        local default_value="$2"
        declare -g "$key"="$(get_config "$config_file" "$key" "$default_value")"
        shift 2
    done
}

load_config_array() {
    local config_file="$1"
    shift
    while (($# > 0)); do
        local key="$1"
        local default_value="$2"
        local value
        value=$(get_config "$config_file" "$key" "$default_value")
        read -r -a "$key" <<<"$(echo "$value" | tr ',' ' ')"
        declare -g "$key"
        shift 2
    done
}

check_dependencies() {
    local missing_packages=""
    for item in "$@"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages+="$pkg "
        fi
    done
    echo "$missing_packages"
}

run_check() {
    local check_func="$1"
    local log_file="$2"
    local skip_flag="$3"

    if [[ "$skip_checks" == *"$skip_flag"* ]]; then
        log_info "Skipping $skip_flag check as per config." >"$log_file" 2>&1
        return
    fi

    "$check_func" "$log_file"
}
