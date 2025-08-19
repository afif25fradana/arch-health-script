#!/usr/bin/env bash
# ============================================================================
# Health Check Suite - Master Launcher v2.0
# Author: Afif & Luna
# Description: Detects the running OS and executes the appropriate
#              specialized health check script from the 'scripts' directory.
# ============================================================================

set -euo pipefail

# Source common functions
# Get the absolute path of the script itself, even if it's a symlink or invoked from PATH.
INSTALLED_SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}")
INSTALLED_SCRIPT_DIR=$(dirname "$INSTALLED_SCRIPT_PATH")

# Determine the shared directory based on the script's installed path
# If installed system-wide, INSTALLED_SCRIPT_DIR will be /usr/local/bin
# If installed user-local, INSTALLED_SCRIPT_DIR will be ~/.local/bin
# In both cases, the shared directory is typically one level up from bin, then into share/health-check
if [[ "$INSTALLED_SCRIPT_DIR" == "/usr/local/bin" ]]; then
    SHARE_DIR="/usr/local/share/health-check"
elif [[ "$INSTALLED_SCRIPT_DIR" == "$HOME/.local/bin" ]]; then
    SHARE_DIR="$HOME/.local/share/health-check"
else
    # Fallback for development or unusual installations (e.g., running from source repo)
    # In this case, assume common/ and scripts/ are relative to the script's location
    SHARE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
fi

COMMON_FUNCTIONS="$SHARE_DIR/common/functions.sh"

if [[ ! -f "$COMMON_FUNCTIONS" ]]; then
    echo "Error: Common functions library not found at $COMMON_FUNCTIONS" >&2
    exit 1
fi
source "$COMMON_FUNCTIONS"

# Setup colors for logging
setup_colors

log_info "Health Check Suite - Master Launcher v2.0"
log_info "Detecting OS and launching appropriate health check script..."

# --- OS Detection ---
if command -v pacman &>/dev/null; then
    SPECIALIZED_SCRIPT="$SHARE_DIR/scripts/arch_health_check.sh"
elif command -v apt-get &>/dev/null; then
    SPECIALIZED_SCRIPT="$SHARE_DIR/scripts/Ubuntu_health_check.sh"
elif command -v dnf &>/dev/null; then
    log_info "Fedora/RHEL based system detected. No specialized script is available yet."
    exit 0 # Exit gracefully, not an error
else
    log_error "Unsupported distribution. This suite currently supports Arch and Debian/Ubuntu based systems."
    exit 1
fi

# Check if the specialized script actually exists and is executable
if [[ ! -x "$SPECIALIZED_SCRIPT" ]]; then
    log_error "The script for your distribution was not found or is not executable."
    log_error "Looked for: $SPECIALIZED_SCRIPT"
    exit 1
fi

# --- Execution ---
# Use 'exec' to replace this launcher process with the specialized script.
# This is efficient and passes all command-line arguments ($@) transparently.
log_info "Detected $(basename "$SPECIALIZED_SCRIPT"). Launching..."
log_info "-----------------------------------------------------"
exec "$SPECIALIZED_SCRIPT" "$@"
