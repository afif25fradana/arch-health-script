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

# --- Determine Installation Mode (System vs. User) ---
if [[ $EUID -eq 0 ]]; then
    # Running as root, install system-wide
    INSTALL_MODE="system"
    TARGET_BIN_DIR="/usr/local/bin"
    TARGET_SHARE_DIR="/usr/local/share/health-check"
    TARGET_CONF_DIR="/etc/health-check"
    log_info "Running with sudo. Installing for all users..."
else
    # Running as a regular user, install locally
    INSTALL_MODE="user"
    TARGET_BIN_DIR="$HOME/.local/bin"
    TARGET_SHARE_DIR="$HOME/.local/share/health-check"
    TARGET_CONF_DIR="$HOME/.config/health-check"
    log_info "Running as user. Installing locally into $HOME/.local..."
fi

# --- Main Installation Logic ---
install_suite() {
    log_section "Health Check Suite Installer"

    # 1. Create target directories
    log_info "Creating directories..."
    # Use sudo only if installing system-wide
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo mkdir -p "$TARGET_BIN_DIR"
        sudo mkdir -p "$TARGET_SHARE_DIR"
        sudo mkdir -p "$TARGET_CONF_DIR"
    else
        mkdir -p "$TARGET_BIN_DIR"
        mkdir -p "$TARGET_SHARE_DIR"
        mkdir -p "$TARGET_CONF_DIR"
    fi

    # 2. Check for required files before copying
    log_info "Verifying required files..."
    required_files=("health-check.sh" "health-check.conf" "scripts/arch_health_check.sh" "scripts/Ubuntu_health_check.sh" "common/functions.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SOURCE_DIR/$file" ]]; then
            log_error "Required file not found: '$SOURCE_DIR/$file'"
            log_error "Please make sure you are running this from the root of the cloned repository."
            exit 1
        fi
    done

    # 3. Copy files using the correct permissions
    log_info "Installing launcher to '$TARGET_BIN_DIR/health-check'..."
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo cp "$SOURCE_DIR/health-check.sh" "$TARGET_BIN_DIR/health-check"
        sudo cp -r "$SOURCE_DIR/scripts" "$SOURCE_DIR/common" "$TARGET_SHARE_DIR/"
    else
        cp "$SOURCE_DIR/health-check.sh" "$TARGET_BIN_DIR/health-check"
        cp -r "$SOURCE_DIR/scripts" "$SOURCE_DIR/common" "$TARGET_SHARE_DIR/"
    fi

    # 4. Install configuration file
    log_info "Installing configuration to '$TARGET_CONF_DIR/health-check.conf'..."
    local target_conf_file="$TARGET_CONF_DIR/health-check.conf"
    if [[ -f "$target_conf_file" ]]; then
        log_warn "Configuration file already exists at '$target_conf_file'. Skipping."
    else
        if [[ "$INSTALL_MODE" == "system" ]]; then
            sudo cp "$SOURCE_DIR/health-check.conf" "$target_conf_file"
        else
            cp "$SOURCE_DIR/health-check.conf" "$target_conf_file"
        fi
    fi

    # 5. Set executable permissions
    log_info "Setting executable permissions..."
    if [[ "$INSTALL_MODE" == "system" ]]; then
        sudo chmod +x "$TARGET_BIN_DIR/health-check"
        sudo chmod +x "$TARGET_SHARE_DIR/scripts"/*.sh
        sudo chmod +x "$TARGET_SHARE_DIR/common/functions.sh" # Ensure common functions are executable
    else
        chmod +x "$TARGET_BIN_DIR/health-check"
        chmod +x "$TARGET_SHARE_DIR/scripts"/*.sh
        chmod +x "$TARGET_SHARE_DIR/common/functions.sh" # Ensure common functions are executable
    fi

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
