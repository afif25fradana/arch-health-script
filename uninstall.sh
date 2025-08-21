#!/usr/bin/env bash
# ============================================================================
# Health Check Suite Uninstaller v1.0
# Removes the suite from system-wide or user-local locations.
# ============================================================================

set -euo pipefail

# Source common functions for logging and colors
# This is a bit tricky since we are uninstalling. We'll try to find it
# but have fallbacks if it's already gone.
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
COMMON_FUNCTIONS="$SOURCE_DIR/common/functions.sh"
if [[ -f "$COMMON_FUNCTIONS" ]]; then
    source "$COMMON_FUNCTIONS"
    setup_colors
else
    # Fallback functions if common library is missing
    setup_colors() { RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""; }
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error(){ echo "[ERROR] $1"; }
    log_section() { echo -e "\n=== $1 ===\n"; }
fi
setup_colors

# --- Configuration ---
declare -A PATHS
PATHS["system_bin"]="/usr/local/bin"
PATHS["system_share"]="/usr/local/share/health-check"
PATHS["system_conf"]="/etc/health-check"
PATHS["user_bin"]="$HOME/.local/bin"
PATHS["user_share"]="$HOME/.local/share/health-check"
PATHS["user_conf"]="$HOME/.config/health-check"

# --- Helper Functions ---
run_cmd() {
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

# --- Determine Installation Mode (System vs. User) ---
if [[ $EUID -eq 0 ]]; then
    INSTALL_MODE="system"
    TARGET_BIN_DIR="${PATHS[system_bin]}"
    TARGET_SHARE_DIR="${PATHS[system_share]}"
    log_info "Running as root. Uninstalling from system locations..."
else
    INSTALL_MODE="user"
    TARGET_BIN_DIR="${PATHS[user_bin]}"
    TARGET_SHARE_DIR="${PATHS[user_share]}"
    log_info "Running as a regular user. Uninstalling from local locations..."
fi

# --- Main Uninstallation Logic ---
uninstall_suite() {
    log_section "Health Check Suite Uninstaller"

    # Use a function for removal to handle sudo correctly
    remove_path() {
        local path_to_remove="$1"
        if [[ ! -e "$path_to_remove" ]]; then
            log_info "Already removed: $path_to_remove"
            return
        fi
        log_info "Removing '$path_to_remove'..."
        run_cmd rm -rf "$path_to_remove"
    }

    # 1. Remove the main executable and shared files
    remove_path "$TARGET_BIN_DIR/health-check"
    remove_path "$TARGET_SHARE_DIR"
    
    # 2. Ask to remove configuration files
    prompt_for_config_removal() {
        local config_dir="$1"
        local dir_owner="$2"
        if [[ -d "$config_dir" ]]; then
            echo
            log_warn "A ${dir_owner} configuration directory was found at '$config_dir'."
            read -p "Do you want to remove it? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                remove_path "$config_dir"
            else
                log_info "Skipping ${dir_owner} configuration removal."
            fi
        fi
    }

    prompt_for_config_removal "${PATHS[user_conf]}" "user"
    if [[ "$INSTALL_MODE" == "system" ]]; then
        prompt_for_config_removal "${PATHS[system_conf]}" "system"
    fi

    echo
    log_info "✅ Health Check Suite uninstalled successfully!"
    echo

    if [[ "$INSTALL_MODE" == "user" ]]; then
        log_warn "You may want to remove '$HOME/.local/bin' from your PATH in"
        log_warn "your ~/.bashrc or ~/.zshrc if you no longer need it."
        echo
    fi
}

# Run the uninstaller
uninstall_suite
