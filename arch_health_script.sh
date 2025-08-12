#!/usr/bin/env bash
# ============================================================================
# Arch Linux Health & Troubleshoot Report
# A robust version with safe parallel execution, dependency checks, and rich reports.
# Im just too lazy
# ============================================================================

# Stop on error, unset variable, or pipe failure
set -euo pipefail

# --- Configuration ---
SCRIPT_NAME="arch-health-check"
SCRIPT_VERSION="3.1"
LOG_DIR="$HOME/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# --- CLI Options ---
# Default values
opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir="$LOG_DIR"

# --- Function: Show script usage ---
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -f, --fast        Skip slower checks (like pacman -Qk)."
    echo "  -c, --no-color    Disable colorized output."
    echo "  -s, --summary     Display only a brief summary on the terminal."
    echo "  -o, --output-dir  Specify a directory for reports (default: ~/logs)."
    echo "  -h, --help        Show this help message."
    exit 0
}

# --- Robust CLI Argument Parsing with getopts ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--fast) opt_fast_mode=true; shift ;;
        -c|--no-color) opt_no_color=true; shift ;;
        -s|--summary) opt_summary_mode=true; shift ;;
        -o|--output-dir) opt_output_dir="$2"; shift 2 ;;
        -h|--help) show_usage ;;
        *) echo "Unknown option: $1"; show_usage ;;
    esac
done

# --- Color Handling ---
if $opt_no_color; then
    RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
fi

# --- Temporary Working Directory for Parallel Execution ---
WORK_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")

# --- Cleanup function to run on exit ---
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# --- Helper Functions ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# --- Function: Check for optional dependencies ---
check_dependencies() {
    local missing_packages=()
    # Map of commands to the packages that provide them
    local dependencies_map=(
        "lspci:pciutils"
        "lsusb:usbutils"
        "sensors:lm-sensors"
        "stress-ng:stress-ng"
    )

    for item in "${dependencies_map[@]}"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    # Return a space-separated string of missing packages
    echo "${missing_packages[*]}"
}


# --- Check Functions (Parallelized) ---
# Each function now accepts an output file path ($1) and redirects all its output there.

check_system_info() {
    exec > "$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo
    local kernel
    kernel=$(uname -r)
    if [[ $kernel == *zen* ]]; then
        log_info "Kernel Zen detected: $kernel"
    elif [[ $kernel == *lts* ]]; then
        log_info "Kernel LTS detected: $kernel. Optimized for stability."
    else
        log_info "Standard kernel detected: $kernel"
    fi
}

check_hardware() {
    exec > "$1" 2>&1
    log_section "HARDWARE"
    echo "--- CPU Info ---"
    lscpu | grep -E 'Model name|CPU\(s\)|Thread|Core\(s\) per socket' || log_warn "lscpu not found"
    echo -e "\n--- Memory Info ---"
    free -h || log_warn "free not found"
    echo -e "\n--- Storage Devices ---"
    lsblk -f || log_warn "lsblk not found"
    echo -e "\n--- Temperature ---"
    if command -v sensors &>/dev/null; then
        sensors
    else
        log_warn "lm-sensors not found. Skipping temperature check."
    fi
}

check_drivers() {
    exec > "$1" 2>&1
    log_section "DRIVERS & DEVICES"
    if ! command -v lspci >/dev/null; then
        log_warn "pciutils (lspci) not found. Skipping driver checks."
        return
    fi
    echo "--- Key Devices (VGA, Network, Audio) ---"
    lspci -nnk | grep -A3 'VGA\|Network\|Audio'
    echo -e "\n--- Unclaimed Devices ---"
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then
        log_warn "Unclaimed devices found! These may not be working correctly."
        lspci -nnk | grep -i "UNCLAIMED"
    else
        log_info "All PCI devices seem to have drivers."
    fi
}

check_packages() {
    exec > "$1" 2>&1
    log_section "PACKAGE STATUS"
    if ! command -v pacman >/dev/null; then
        log_warn "pacman not found. Not an Arch-based system?"
        return
    fi

    echo "--- Orphaned Packages ---"
    local orphans
    orphans=$(pacman -Qdtq || true)
    if [[ -n "$orphans" ]]; then
        local orphan_count
        orphan_count=$(echo "$orphans" | wc -l)
        log_warn "${orphan_count} orphaned packages found."
        echo "$orphans" | head -n 10
        log_info "Tip: Remove all with 'sudo pacman -Rns \$(pacman -Qdtq)'"
    else
        log_info "No orphaned packages found."
    fi

    if ! $opt_fast_mode; then
        echo -e "\n--- Missing Package Files ---"
        local missing_files
        missing_files=$(pacman -Qk 2>/dev/null | grep -v " 0 missing files" || true)
        if [[ -n "$missing_files" ]]; then
            log_warn "Packages with missing files detected."
            echo "$missing_files" | head -n 10
        else
            log_info "No missing package files found."
        fi
    fi
}

check_services_and_logs() {
    exec > "$1" 2>&1
    log_section "SERVICES & KERNEL LOGS"
    echo "--- Failed Systemd Services ---"
    if ! systemctl is-system-running --quiet; then
        log_warn "System is not in a running state. Checking for failed services."
        systemctl --failed --no-pager
    else
        log_info "No failed systemd services."
    fi

    echo -e "\n--- Recent Kernel Errors & Warnings ---"
    local kernel_logs
    kernel_logs=$(journalctl -p err..warn -n 10 --no-pager --output=short-monotonic || true)
    if [[ -n "$kernel_logs" ]]; then
        log_warn "Kernel errors or warnings found in recent logs."
        echo "$kernel_logs"
    else
        log_info "No recent kernel errors or warnings."
    fi
}

# --- Main Logic ---
main() {
    # 1. Initialization
    echo -e "${BLUE}=== Arch Linux Health Check v${SCRIPT_VERSION} ===${NC}"
    echo "Running checks... Reports will be saved to '$opt_output_dir'"
    mkdir -p "$opt_output_dir"
    local missing_pkgs; missing_pkgs=$(check_dependencies)

    # 2. Run checks in parallel
    check_system_info  "${WORK_DIR}/01-system.log" &
    check_hardware     "${WORK_DIR}/02-hardware.log" &
    check_drivers      "${WORK_DIR}/03-drivers.log" &
    check_packages     "${WORK_DIR}/04-packages.log" &
    check_services_and_logs "${WORK_DIR}/05-services.log" &

    wait

    # 3. Consolidate logs
    local final_log_plain="${WORK_DIR}/final_plain.log"
    {
        echo "Arch Linux Health Check Report - ${TIMESTAMP}"
        echo "=================================================="
        cat "${WORK_DIR}"/*.log
    } > "$final_log_plain"

    # 4. Calculate Health Score
    local warnings; warnings=$(grep -c '\[WARN\]' "$final_log_plain" || true)
    local score; score=$((100 - warnings * 5))
    [[ $score -lt 0 ]] && score=0

    {
        echo -e "\n${BLUE}=== HEALTH SCORE ===${NC}"
        echo -e "${GREEN}[INFO]${NC} System Health Score: ${score}/100 (Warnings: ${warnings})"
    } | tee -a "${WORK_DIR}/99-score.log"
    cat "${WORK_DIR}/99-score.log" >> "$final_log_plain"

    # 5. Generate final colored log
    local final_log_colored="${WORK_DIR}/final_colored.log"
    {
        echo "Arch Linux Health Check Report - ${TIMESTAMP}"
        echo "=================================================="
        cat "${WORK_DIR}"/*.log
    } > "$final_log_colored"

    # 6. Display output to terminal
    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "${WORK_DIR}/99-score.log"
    else
        cat "$final_log_colored"
    fi

    # 7. Export reports
    local report_base_name="${opt_output_dir}/${SCRIPT_NAME}-${TIMESTAMP}"
    cp "$final_log_colored" "${report_base_name}.log"
    {
        echo "# Arch Health Report - ${TIMESTAMP}"
        sed -e 's/=== \(.*\) ===/## \1/' -e 's/--- \(.*\) ---/### \1\n```bash/' "$final_log_plain" | sed '$a```' > "${report_base_name}.md"
    }
    {
        echo "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><title>Arch Health Report</title>"
        echo "<style>body{font-family:monospace;background:#282a36;color:#f8f8f2;padding:1em;}h1{color:#50fa7b;}h2{color:#bd93f9;}pre{background:#44475a;padding:1em;border-radius:5px;white-space:pre-wrap;}</style>"
        echo "</head><body><h1>Arch Health Report - ${TIMESTAMP}</h1><pre>"
        sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$final_log_plain"
        echo "</pre></body></html>"
    } > "${report_base_name}.html"

    echo -e "\n${GREEN}✔ Reports saved successfully:${NC}"
    echo "  - Log: ${report_base_name}.log"
    echo "  - MD:  ${report_base_name}.md"
    echo "  - HTML: ${report_base_name}.html"

    # 8. Report missing dependencies if any
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}NOTE: Some optional dependencies were not found.${NC}"
        echo "For a complete report, please install them by running:"
        echo -e "  ${GREEN}sudo pacman -Syu ${missing_pkgs}${NC}"
    fi
}

# --- Run Main Function ---
main
