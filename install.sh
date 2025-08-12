#!/usr/bin/env bash
# ============================================================================
# Health Check Suite Installer v1.1
# Installs the suite for system-wide or user-local usage.
# ============================================================================

set -euo pipefail

# --- Pretty Colors ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# --- Logging Functions ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Get the directory of the installer script itself ---
# This allows running it from anywhere, e.g., ./installers/install.sh
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# --- Determine Installation Mode (System vs. User) ---
if [[ $EUID -eq 0 ]]; then
    # Running as root, install system-wide
    INSTALL_MODE="system"
    TARGET_BIN_DIR="/usr/local/bin"
    TARGET_SHARE_DIR="/usr/local/share/health-check"
    log_info "Running with sudo. Installing for all users..."
else
    # Running as a regular user, install locally
    INSTALL_MODE="user"
    TARGET_BIN_DIR="$HOME/.local/bin"
    TARGET_SHARE_DIR="$HOME/.local/share/health-check"
    log_info "Running as user. Installing locally into $HOME/.local..."
fi

# --- Main Installation Logic ---
install_suite() {
    echo -e "${BLUE}=== Health Check Suite Installer ===${NC}"

    # 1. Create target directories
    log_info "Creating directories..."
    mkdir -p "$TARGET_BIN_DIR"
    mkdir -p "$TARGET_SHARE_DIR"

    # 2. Check for required files before copying
    log_info "Verifying required files..."
    required_files=("health-check.sh" "scripts/arch_health_check.sh" "scripts/Ubuntu_health_check.sh" "common/functions.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SOURCE_DIR/$file" ]]; then
            log_error "Required file not found: '$SOURCE_DIR/$file'. Make sure you run this from the repo root."
            exit 1
        fi
    done

    # 3. Copy files
    log_info "Installing launcher to '$TARGET_BIN_DIR/health-check'..."
    cp "$SOURCE_DIR/health-check.sh" "$TARGET_BIN_DIR/health-check"

    log_info "Installing library and scripts to '$TARGET_SHARE_DIR'..."
    # Copy the contents of the directories
    cp -r "$SOURCE_DIR/scripts" "$SOURCE_DIR/common" "$TARGET_SHARE_DIR/"

    # 4. Set executable permissions
    log_info "Setting executable permissions..."
    chmod +x "$TARGET_BIN_DIR/health-check"
    chmod +x "$TARGET_SHARE_DIR/scripts"/*.sh

    # 5. Final success message
    echo
    log_info "✅ Health Check Suite installed successfully!"
    echo

    if [[ $INSTALL_MODE == "user" ]]; then
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
