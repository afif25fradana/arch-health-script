#!/usr/bin/env bash
# ============================================================================
# Health Check Suite - Master Launcher v1.0
# Author: Afif
# Description: Detects the running OS and executes the appropriate
#              specialized health check script.
# ============================================================================

set -euo pipefail

# --- Helper: Get the directory where the script is located ---
# This makes it runnable from anywhere on the system.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# --- OS Detection ---
if command -v pacman &>/dev/null; then
    # Arch-based system detected
    SPECIALIZED_SCRIPT="$SCRIPT_DIR/arch_health_check.sh"
elif command -v apt-get &>/dev/null; then
    # Debian/Ubuntu-based system detected
    SPECIALIZED_SCRIPT="$SCRIPT_DIR/Ubuntu_health_check.sh"
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
# This is efficient and passes all arguments ($@) transparently.
echo "--> Detected $(basename "$SPECIALIZED_SCRIPT"). Launching..."
exec "$SPECIALIZED_SCRIPT" "$@"
