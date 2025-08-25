#!/usr/bin/env bash
# ============================================================================
# Health Check Suite Installer
# Installs the suite for system-wide or user-local usage.
# ============================================================================

set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

COMMON_FUNCTIONS="$SOURCE_DIR/src/common/functions.sh"
if [[ ! -f "$COMMON_FUNCTIONS" ]]; then
    echo "Error: Common functions library not found at $COMMON_FUNCTIONS" >&2
    exit 1
fi
source "$COMMON_FUNCTIONS"

setup_colors

declare -A PATHS
PATHS["system_bin"]="/usr/local/bin"
PATHS["system_share"]="/usr/local/share/health-check"
PATHS["system_conf"]="/etc/health-check"
PATHS["user_bin"]="$HOME/.local/bin"
PATHS["user_share"]="$HOME/.local/share/health-check"
PATHS["user_conf"]="$HOME/.config/health-check"

REQUIRED_FILES=(
    "src/health-check.sh"
    "src/health-check.conf"
    "src/scripts/arch_health_check.sh"
    "src/scripts/Ubuntu_health_check.sh"
    "src/common/functions.sh"
)

run_cmd() {
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

set_install_mode() {
    if (($EUID == 0)); then
        INSTALL_MODE="system"
        TARGET_BIN_DIR="${PATHS[system_bin]}"
        TARGET_SHARE_DIR="${PATHS[system_share]}"
        TARGET_CONF_DIR="${PATHS[system_conf]}"
        log_info "Running as root. System-wide installation."
    else
        INSTALL_MODE="user"
        TARGET_BIN_DIR="${PATHS[user_bin]}"
        TARGET_SHARE_DIR="${PATHS[user_share]}"
        TARGET_CONF_DIR="${PATHS[user_conf]}"
        log_info "Running as user. Local installation."
    fi

    if [[ "$INSTALL_MODE" == "system" && ! -x "/usr/bin/sudo" ]]; then
        log_error "sudo is required for system-wide installation, but it's not installed or not in PATH."
        exit 1
    fi
}

verify_files() {
    log_info "Verifying required files..."
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "$SOURCE_DIR/$file" ]]; then
            log_error "Required file not found: '$SOURCE_DIR/$file'"
            exit 1
        fi
    done
}

create_dirs() {
    log_info "Creating directories..."
    run_cmd mkdir -p "$TARGET_BIN_DIR" "$TARGET_SHARE_DIR" "$TARGET_CONF_DIR"
}

copy_files() {
    log_info "Installing files..."

    if [[ ! -d "$SOURCE_DIR/src/scripts" ]]; then
        log_error "Source directory for scripts not found: $SOURCE_DIR/src/scripts"
        exit 1
    fi
    if [[ ! -d "$SOURCE_DIR/src/common" ]]; then
        log_error "Source directory for common functions not found: $SOURCE_DIR/src/common"
        exit 1
    fi

    run_cmd cp "$SOURCE_DIR/src/health-check.sh" "$TARGET_BIN_DIR/health-check"
    run_cmd cp -r "$SOURCE_DIR/src/scripts" "$SOURCE_DIR/src/common" "$TARGET_SHARE_DIR/"

    local target_conf_file="$TARGET_CONF_DIR/health-check.conf"
    if [[ -f "$target_conf_file" ]]; then
        log_warn "Configuration file already exists at '$target_conf_file'. Skipping."
    else
        log_info "Installing configuration to '$target_conf_file'..."
        run_cmd cp "$SOURCE_DIR/src/health-check.conf" "$target_conf_file"
    fi
}

set_permissions() {
    log_info "Setting executable permissions..."
    run_cmd chmod +x "$TARGET_BIN_DIR/health-check"
    if compgen -G "$TARGET_SHARE_DIR/scripts/*.sh" >/dev/null; then
        run_cmd chmod +x "$TARGET_SHARE_DIR/scripts"/*.sh
    else
        log_warn "No scripts found in '$TARGET_SHARE_DIR/scripts' to set permissions."
    fi
}

main() {
    log_section "Health Check Suite Installer"
    set_install_mode
    verify_files
    create_dirs
    copy_files
    set_permissions

    echo
    log_info "✅ Health Check Suite installed successfully!"
    echo

    if [[ "$INSTALL_MODE" == "user" ]]; then
        log_warn "Make sure '$TARGET_BIN_DIR' is in your PATH."
        log_warn "Add to your ~/.bashrc or ~/.zshrc:"
        echo -e "${YELLOW}  export PATH=\"$HOME/.local/bin:$PATH\"${NC}"
        echo
    fi

    log_info "Run the tool from anywhere by typing:"
    log_info "  health-check --help"
}

main
