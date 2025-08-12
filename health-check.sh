#!/usr/bin/env bash
# ============================================================================
# Health Check Suite - Master Launcher v2.0
# Author: Afif & Luna
# Description: Detects the running OS and executes the appropriate
#              specialized health check script from the 'scripts' directory.
# ============================================================================

set -euo pipefail

# This makes the script runnable from anywhere on the system.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# --- OS Detection ---
if command -v pacman &>/dev/null; then
    SPECIALIZED_SCRIPT="$SCRIPT_DIR/scripts/arch_health_check.sh"
elif command -v apt-get &>/dev/null; then
    SPECIALIZED_SCRIPT="$SCRIPT_DIR/scripts/Ubuntu_health_check.sh"
elif command -v dnf &>/dev/null; then
    echo "Info: Fedora/RHEL based system detected. No specialized script is available yet." >&2
    exit 0 # Exit gracefully, not an error
else
    echo "Error: Unsupported distribution. This suite currently supports Arch and Debian/Ubuntu based systems." >&2
    exit 1
fi

# Check if the specialized script actually exists and is executable
if [[ ! -x "$SPECIALIZED_SCRIPT" ]]; then
    echo "Error: The script for your distribution was not found or is not executable." >&2
    echo "Looked for: $SPECIALIZED_SCRIPT" >&2
    exit 1
fi

# --- Execution ---
# Use 'exec' to replace this launcher process with the specialized script.
# This is efficient and passes all command-line arguments ($@) transparently.
echo "--> Detected $(basename "$SPECIALIZED_SCRIPT"). Launching..."
echo "-----------------------------------------------------"
exec "$SPECIALIZED_SCRIPT" "$@"
