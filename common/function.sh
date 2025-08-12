#!/usr/bin/env bash
# ============================================================================
# Common Functions Library for Health Check Suite
# This file is sourced by specialized scripts. Do not run it directly.
# ============================================================================

# --- Color Handling ---
# This allows individual scripts to enable/disable color via an option.
setup_colors() {
    if [[ -t 1 && "${opt_no_color:-false}" == false ]]; then
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

# --- Logging Functions ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
