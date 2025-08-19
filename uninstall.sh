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
    setup_colors
fi

# --- Determine Installation Mode (System vs. User) ---
if [[ $EUID -eq 0 ]]; then
    # Running as root, uninstall from system-wide locations
    INSTALL_MODE="system"
    TARGET_BIN_DIR="/usr/local/bin"
    TARGET_SHARE_DIR="/usr/local/share/health-check"
    log_info "Running with sudo. Uninstalling from system locations..."
else
    # Running as a regular user, uninstall from local locations
    INSTALL_MODE="user"
    TARGET_BIN_DIR="$HOME/.local/bin"
    TARGET_SHARE_DIR="$HOME/.local/share/health-check"
    log_info "Running as user. Uninstalling from local user locations..."
fi

# --- Main Uninstallation Logic ---
uninstall_suite() {
    log_section "Health Check Suite Uninstaller"

    # Use a function for removal to handle sudo correctly
    remove_file() {
        if [[ ! -e "$1" ]]; then
            log_info "Already removed: $1"
            return
        fi
        log_info "Removing '$1'..."
        if [[ "$INSTALL_MODE" == "system" ]]; then
            sudo rm -rf "$1"
        else
            rm -rf "$1"
        fi
    }

    # 1. Remove the main executable
    remove_file "$TARGET_BIN_DIR/health-check"

    # 2. Remove the shared scripts and libraries
    remove_file "$TARGET_SHARE_DIR"
    
    # 3. Remove the user configuration file (ask first)
    local config_file="$HOME/.config/health-check/health-check.conf"
    if [[ -f "$config_file" ]]; then
        echo
        log_warn "A user configuration file was found at '$config_file'."
        read -p "Do you want to remove it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing user configuration..."
            rm -rf "$(dirname "$config_file")"
        else
            log_info "Skipping user configuration removal."
        fi
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
