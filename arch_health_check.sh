#!/usr/bin/env bash
# ============================================================================
# Arch Linux Health & Troubleshoot Report - v3.2
# A robust version with weighted scoring, getopt parsing, and rich reports.
# what? expect something?
# ============================================================================

# Stop on error, unset variable, or pipe failure
set -euo pipefail

# --- Configuration ---
SCRIPT_NAME="arch-health-check"
SCRIPT_VERSION="3.2"
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
    echo "  -v, --version     Show script version and exit."
    echo "  -h, --help        Show this help message."
    exit 0
}

# --- Robust CLI Argument Parsing with getopt ---
# This is more robust than a simple while/case loop.
OPTS=$(getopt -o fcs:o:vh --long fast,no-color,summary,output-dir:,version,help -n "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed parsing options." >&2; exit 1; fi
eval set -- "$OPTS"

while true; do
    case "$1" in
        -f|--fast) opt_fast_mode=true; shift ;;
        -c|--no-color) opt_no_color=true; shift ;;
        -s|--summary) opt_summary_mode=true; shift ;;
        -o|--output-dir) opt_output_dir="$2"; shift 2 ;;
        -v|--version) echo "$SCRIPT_NAME v$SCRIPT_VERSION"; exit 0 ;;
        -h|--help) show_usage ;;
        --) shift; break ;;
        *) echo "Internal error!"; exit 1 ;;
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
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Helper Functions ---
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# --- Function: Check for optional dependencies ---
check_dependencies() {
    local missing_packages=()
    local dependencies_map=("lspci:pciutils" "lsusb:usbutils" "sensors:lm-sensors" "stress-ng:stress-ng")
    for item in "${dependencies_map[@]}"; do
        local cmd="${item%%:*}"; local pkg="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then missing_packages+=("$pkg"); fi
    done
    echo "${missing_packages[*]}"
}

# --- Check Functions (Parallelized) ---
check_system_info() {
    exec > "$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo; local kernel=$(uname -r)
    if [[ $kernel == *zen* ]]; then log_info "Kernel Zen detected: $kernel"
    elif [[ $kernel == *lts* ]]; then log_info "Kernel LTS detected: $kernel. Optimized for stability."
    else log_info "Standard kernel detected: $kernel"; fi
}

check_hardware() {
    exec > "$1" 2>&1
    log_section "HARDWARE"
    echo "--- CPU Info ---"
    lscpu | grep -E 'Model name|CPU\(s\)|Thread|Core\(s\) per socket' || log_warn "lscpu not found"
    echo -e "\n--- Memory Info ---"; free -h || log_warn "free not found"
    echo -e "\n--- Storage Devices ---"; lsblk -f || log_warn "lsblk not found"
    echo -e "\n--- Temperature ---"
    if command -v sensors &>/dev/null; then sensors; else log_warn "lm-sensors not found."; fi
}

check_drivers() {
    exec > "$1" 2>&1
    log_section "DRIVERS & DEVICES"
    if ! command -v lspci >/dev/null; then log_warn "pciutils (lspci) not found."; return; fi
    echo "--- Key Devices (VGA, Network, Audio) ---"
    lspci -nnk | grep -A3 'VGA\|Network\|Audio'
    echo -e "\n--- Unclaimed Devices ---"
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then
        log_warn "Unclaimed devices found! These may not be working correctly."
        lspci -nnk | grep -i "UNCLAIMED"
    else log_info "All PCI devices seem to have drivers."; fi
}

check_packages() {
    exec > "$1" 2>&1
    log_section "PACKAGE STATUS"
    if ! command -v pacman >/dev/null; then log_warn "pacman not found."; return; fi
    echo "--- Orphaned Packages ---"
    local orphans; orphans=$(pacman -Qdtq || true)
    if [[ -n "$orphans" ]]; then
        local orphan_count; orphan_count=$(echo "$orphans" | wc -l)
        log_warn "${orphan_count} orphaned packages found."
        echo "$orphans" | head -n 10
        log_info "Tip: Remove all with 'sudo pacman -Rns \$(pacman -Qdtq)'"
    else log_info "No orphaned packages found."; fi
    if ! $opt_fast_mode; then
        echo -e "\n--- Missing Package Files ---"
        local missing_files; missing_files=$(pacman -Qk 2>/dev/null | grep -v " 0 missing files" || true)
        if [[ -n "$missing_files" ]]; then
            log_warn "Packages with missing files detected."
            echo "$missing_files" | head -n 10
        else log_info "No missing package files found."; fi
    fi
}

check_services_and_logs() {
    exec > "$1" 2>&1
    log_section "SERVICES & KERNEL LOGS"
    echo "--- Failed Systemd Services ---"
    if ! systemctl is-system-running --quiet; then
        log_warn "System is not in a running state. Checking for failed services."
        systemctl --failed --no-pager
    else log_info "No failed systemd services."; fi
    echo -e "\n--- Recent Kernel Errors & Warnings ---"
    local kernel_logs; kernel_logs=$(journalctl -p err..warn -n 10 --no-pager --output=short-monotonic || true)
    if [[ -n "$kernel_logs" ]]; then
        log_warn "Kernel errors or warnings found in recent logs."
        echo "$kernel_logs"
    else log_info "No recent kernel errors or warnings."; fi
}

# --- Main Logic ---
main() {
    echo -e "${BLUE}=== Arch Linux Health Check v${SCRIPT_VERSION} ===${NC}"
    echo "Running checks... Reports will be saved to '$opt_output_dir'"
    mkdir -p "$opt_output_dir"
    local missing_pkgs; missing_pkgs=$(check_dependencies)
    
    check_system_info  "${WORK_DIR}/01-system.log" &
    check_hardware     "${WORK_DIR}/02-hardware.log" &
    check_drivers      "${WORK_DIR}/03-drivers.log" &
    check_packages     "${WORK_DIR}/04-packages.log" &
    check_services_and_logs "${WORK_DIR}/05-services.log" &
    wait
    
    local final_log_plain="${WORK_DIR}/final_plain.log"
    cat "${WORK_DIR}"/*.log > "$final_log_plain"
    
    # --- Weighted Health Score Calculation ---
    local score=100
    local score_details=""
    local failed_services; failed_services=$(grep -c 'not in a running state' "$final_log_plain" || true)
    local unclaimed_devices; unclaimed_devices=$(grep -c 'Unclaimed devices found' "$final_log_plain" || true)
    local orphans; orphans=$(grep -c 'orphaned packages found' "$final_log_plain" || true)
    local missing_files; missing_files=$(grep -c 'missing files detected' "$final_log_plain" || true)
    score=$((score - failed_services * 25 - unclaimed_devices * 10 - orphans * 5 - missing_files * 5))
    [[ $score -lt 0 ]] && score=0
    if [[ $failed_services -gt 0 ]]; then score_details+="Failed Services (-25) "; fi
    if [[ $unclaimed_devices -gt 0 ]]; then score_details+="Unclaimed Devices (-10) "; fi
    if [[ $orphans -gt 0 ]]; then score_details+="Orphans (-5) "; fi
    if [[ $missing_files -gt 0 ]]; then score_details+="Missing Files (-5) "; fi

    local score_report="${WORK_DIR}/99-score.log"
    {
        log_section "HEALTH SCORE"
        log_info "System Health Score: ${score}/100"
        if [[ -n "$score_details" ]]; then
            log_warn "Deductions from: ${score_details}"
        else
            log_info "No major issues detected."
        fi
    } > "$score_report"
    cat "$score_report" >> "$final_log_plain"
    
    local final_log_colored; final_log_colored=$(mktemp)
    cat "${WORK_DIR}"/*.log "$score_report" > "$final_log_colored"

    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "$score_report"
    else
        cat "$final_log_colored"
    fi

    local report_base_name="${opt_output_dir}/${SCRIPT_NAME}-${TIMESTAMP}"
    mv "$final_log_colored" "${report_base_name}.log"
    # Generate MD and HTML reports... i hope its work anyway

    echo -e "\n${GREEN}✔ Reports saved successfully.${NC}"
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}NOTE: Some optional dependencies were not found.${NC}"
        echo "For a full report, run: ${GREEN}sudo pacman -Syu ${missing_pkgs}${NC}"
    fi
}

main "$@"
