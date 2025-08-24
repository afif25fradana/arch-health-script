#!/usr/bin/env bash
# ============================================================================
# Health Check Suite Uninstaller
# Removes the suite from system-wide or user-local locations.
# ============================================================================

set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
COMMON_FUNCTIONS="$SOURCE_DIR/src/common/functions.sh"
if [[ -f "$COMMON_FUNCTIONS" ]]; then
    source "$COMMON_FUNCTIONS"
    setup_colors
else
    setup_colors() { RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""; }
    log_info() { echo "[INFO] $1"; }
    log_warn() { echo "${YELLOW}[WARN]${NC} $1"; }
    log_error(){ echo "${RED}[ERROR]${NC} $1"; }
    log_section() { echo -e "\n=== $1 ===\n"; }
fi

declare -A PATHS
PATHS["system_bin"]="/usr/local/bin"
PATHS["system_share"]="/usr/local/share/health-check"
PATHS["system_conf"]="/etc/health-check"
PATHS["user_bin"]="$HOME/.local/bin"
PATHS["user_share"]="$HOME/.local/share/health-check"
PATHS["user_conf"]="$HOME/.config/health-check"

run_cmd() {
    if [[ "$UNINSTALL_MODE" == "system" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

set_uninstall_mode() {
    if [[ -f "${PATHS[system_bin]}/health-check" ]]; then
        UNINSTALL_MODE="system"
        TARGET_BIN_DIR="${PATHS[system_bin]}"
        TARGET_SHARE_DIR="${PATHS[system_share]}"
        log_info "System-wide installation detected."
        if (($EUID != 0)); then
            log_warn "Sudo is required to remove system-wide files."
        fi
    elif [[ -f "${PATHS[user_bin]}/health-check" ]]; then
        UNINSTALL_MODE="user"
        TARGET_BIN_DIR="${PATHS[user_bin]}"
        TARGET_SHARE_DIR="${PATHS[user_share]}"
        log_info "Local user installation detected."
    else
        UNINSTALL_MODE="none"
    fi
}

remove_path() {
    local path_to_remove="$1"
    if [[ ! -e "$path_to_remove" ]]; then
        log_info "Already removed: $path_to_remove"
        return
    fi
    log_info "Removing '$path_to_remove'..."
    run_cmd rm -rf "$path_to_remove"
}

remove_files() {
    if [[ "$UNINSTALL_MODE" == "none" ]]; then
        log_info "No installation found to remove."
        return
    fi
    remove_path "$TARGET_BIN_DIR/health-check"
    remove_path "$TARGET_SHARE_DIR"
}

prompt_for_config_removal() {
    local config_dir="$1"
    local dir_owner="$2"
    local requires_sudo=${3:-false}

    if [[ -d "$config_dir" ]]; then
        echo
        log_warn "Found $dir_owner configuration directory at '$config_dir'."
        local prompt="Do you want to remove it?"
        $requires_sudo && prompt+=" (requires sudo)"
        read -p "$prompt [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if $requires_sudo; then
                sudo rm -rf "$config_dir"
            else
                remove_path "$config_dir"
            fi
        else
            log_info "Skipping $dir_owner configuration removal."
        fi
    fi
}

main() {
    log_section "Health Check Suite Uninstaller"
    set_uninstall_mode

    if [[ "$UNINSTALL_MODE" == "none" ]]; then
        log_info "Health Check Suite is not installed."
        exit 0
    fi

    remove_files

    prompt_for_config_removal "${PATHS[user_conf]}" "user"
    if (($EUID == 0)); then
        prompt_for_config_removal "${PATHS[system_conf]}" "system"
    else
        prompt_for_config_removal "${PATHS[system_conf]}" "system" true
    fi

    echo
    log_info "✅ Health Check Suite uninstalled successfully!"
    echo

    if [[ "$UNINSTALL_MODE" == "user" ]]; then
        log_warn "Consider removing '$HOME/.local/bin' from your PATH in"
        log_warn "~/.bashrc or ~/.zshrc if no longer needed."
        echo
    fi
}

main
