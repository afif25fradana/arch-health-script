#!/usr/bin/env bash
# ============================================================================
# Health Check Suite - Master Launcher v2.0
# Author: Afif & Luna
# Description: Detects the running OS and executes the appropriate
#              specialized health check script from the 'scripts' directory.
# ============================================================================

set -euo pipefail

# Source common functions
# Determine the script's absolute directory to reliably locate other files.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
SHARE_DIR="$SCRIPT_DIR" # Default to the script's own directory

# If the script is installed, the share directory will be in a different location.
# We check if the 'common' directory exists relative to the script. If not, we assume
# it's an installed version and look in the standard share locations.
if [[ ! -d "$SCRIPT_DIR/common" ]]; then
    if [[ -d "/usr/local/share/health-check" ]]; then
        SHARE_DIR="/usr/local/share/health-check"
    elif [[ -d "$HOME/.local/share/health-check" ]]; then
        SHARE_DIR="$HOME/.local/share/health-check"
    fi
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
# Use /etc/os-release for a more reliable and portable way to identify the OS.
if [[ -f /etc/os-release ]]; then
    # Source the file to get access to variables like ID and ID_LIKE
    . /etc/os-release
else
    log_error "Cannot determine OS: /etc/os-release not found."
    exit 1
fi

# Check the OS ID and its "like" values (e.g., ubuntu is "like" debian)
case "${ID_LIKE:-$ID}" in
    *arch*)
        SPECIALIZED_SCRIPT="$SHARE_DIR/scripts/arch_health_check.sh"
        ;;
    *debian*|*ubuntu*)
        SPECIALIZED_SCRIPT="$SHARE_DIR/scripts/Ubuntu_health_check.sh"
        ;;
    *fedora*|*rhel*)
        log_info "Fedora/RHEL based system detected. No specialized script is available yet."
        exit 0 # Exit gracefully, not an error
        ;;
    *)
        log_error "Unsupported distribution: ${PRETTY_NAME:-$ID}. This suite currently supports Arch and Debian/Ubuntu based systems."
        exit 1
        ;;
esac

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
