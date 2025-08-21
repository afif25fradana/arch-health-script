#!/usr/bin/env bash
# ============================================================================
# Health Check Suite Installer v1.2 (Path Fixed)
# Installs the suite for system-wide or user-local usage.
# ============================================================================

set -euo pipefail

# --- FIXED: More robust way to find the source directory ---
# This ensures that no matter how the script is called, it finds its own location.
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Source common functions for logging and colors
COMMON_FUNCTIONS="$SOURCE_DIR/common/functions.sh"
if [[ ! -f "$COMMON_FUNCTIONS" ]]; then
    echo "Error: Common functions library not found at $COMMON_FUNCTIONS" >&2
    exit 1
fi
source "$COMMON_FUNCTIONS"

# Setup colors for logging
setup_colors

# --- Configuration ---
# Define installation paths and required files
declare -A PATHS
PATHS["system_bin"]="/usr/local/bin"
PATHS["system_share"]="/usr/local/share/health-check"
PATHS["system_conf"]="/etc/health-check"
PATHS["user_bin"]="$HOME/.local/bin"
PATHS["user_share"]="$HOME/.local/share/health-check"
PATHS["user_conf"]="$HOME/.config/health-check"

REQUIRED_FILES=(
    "health-check.sh"
    "health-check.conf"
    "scripts/arch_health_check.sh"
    "scripts/Ubuntu_health_check.sh"
    "common/functions.sh"
)

# --- Helper Functions ---
# A single function to run a command, with sudo if needed.
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
    TARGET_CONF_DIR="${PATHS[system_conf]}"
    log_info "Running as root. Installing for all users..."
else
    INSTALL_MODE="user"
    TARGET_BIN_DIR="${PATHS[user_bin]}"
    TARGET_SHARE_DIR="${PATHS[user_share]}"
    TARGET_CONF_DIR="${PATHS[user_conf]}"
    log_info "Running as a regular user. Installing locally..."
fi

# --- Main Installation Logic ---
install_suite() {
    log_section "Health Check Suite Installer"

    # 1. Verify required files exist before we start creating directories
    log_info "Verifying required files..."
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "$SOURCE_DIR/$file" ]]; then
            log_error "Required file not found: '$SOURCE_DIR/$file'"
            log_error "Please run this script from the root of the repository."
            exit 1
        fi
    done

    # 2. Create target directories
    log_info "Creating directories..."
    run_cmd mkdir -p "$TARGET_BIN_DIR" "$TARGET_SHARE_DIR" "$TARGET_CONF_DIR"

    # 3. Copy files
    log_info "Installing files..."
    run_cmd cp "$SOURCE_DIR/health-check.sh" "$TARGET_BIN_DIR/health-check"
    run_cmd cp -r "$SOURCE_DIR/scripts" "$SOURCE_DIR/common" "$TARGET_SHARE_DIR/"

    # 4. Install configuration file, but don't overwrite an existing one
    local target_conf_file="$TARGET_CONF_DIR/health-check.conf"
    if [[ -f "$target_conf_file" ]]; then
        log_warn "Configuration file already exists at '$target_conf_file'. Skipping."
    else
        log_info "Installing configuration to '$target_conf_file'..."
        run_cmd cp "$SOURCE_DIR/health-check.conf" "$target_conf_file"
    fi

    # 5. Set executable permissions
    log_info "Setting executable permissions..."
    run_cmd chmod +x "$TARGET_BIN_DIR/health-check"
    run_cmd chmod +x "$TARGET_SHARE_DIR/scripts"/*.sh

    # 6. Final success message
    echo
    log_info "✅ Health Check Suite installed successfully!"
    echo

    if [[ "$INSTALL_MODE" == "user" ]]; then
        log_warn "IMPORTANT: Make sure '$TARGET_BIN_DIR' is in your PATH."
        log_warn "You can do this by adding the following line to your ~/.bashrc or ~/.zshrc:"
        echo -e "${YELLOW}  export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo
    fi

    log_info "You can now run the tool from anywhere by typing:"
    log_info "  health-check --help"
}

# Run the installer
install_suite
