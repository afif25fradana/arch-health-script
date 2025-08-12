#!/usr/bin/env bash
# ============================================================================
# Ubuntu/Debian Health & Troubleshoot Report - v1.0
# A robust version adapted from the Arch Health Script.
# Features parallel execution, dependency checks, and rich reports.
# Built by Luna & Afif.
# ============================================================================

# Stop on error, unset variable, or pipe failure
set -euo pipefail

# --- Configuration ---
SCRIPT_NAME="ubuntu-health-check"
SCRIPT_VERSION="1.0"
LOG_DIR="$HOME/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# --- CLI Options ---
opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir="$LOG_DIR"

show_usage() {
    echo "Usage: $0 [options]"
    echo "  -f, --fast        Skip slower checks (like debsums)."
    echo "  -c, --no-color    Disable colorized output."
    echo "  -s, --summary     Display only a brief summary on the terminal."
    echo "  -o, --output-dir  Specify a directory for reports (default: ~/logs)."
    echo "  -v, --version     Show script version and exit."
    echo "  -h, --help        Show this help message."
    exit 0
}

# --- Robust CLI Argument Parsing with getopt ---
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

# --- Temporary Working Directory & Cleanup ---
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
    local dependencies_map=(
        "lspci:pciutils"
        "sensors:lm-sensors"
        "deborphan:deborphan"
        "debsums:debsums"
    )
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
    echo
    log_info "Kernel: $(uname -r)"
    log_info "Distro: $(lsb_release -ds)"
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
    log_section "PACKAGE STATUS (APT)"
    echo "--- Upgradable Packages ---"
    local upgradable_count
    upgradable_count=$(apt list --upgradable 2>/dev/null | grep -vc "Listing...")
    if [[ "$upgradable_count" -gt 0 ]]; then
        log_warn "${upgradable_count} packages can be upgraded."
        log_info "Run 'sudo apt update && sudo apt upgrade' to update them."
    else
        log_info "System is up-to-date."
    fi

    echo -e "\n--- Orphaned/Autoremovable Packages ---"
    if command -v deborphan &>/dev/null; then
        local orphans; orphans=$(deborphan || true)
        if [[ -n "$orphans" ]]; then
            log_warn "Orphaned packages found by deborphan:"
            echo "$orphans"
        else
            log_info "No orphaned packages found by deborphan."
        fi
    else
        log_warn "deborphan not found. For a more accurate orphan check, please install it."
    fi

    if ! $opt_fast_mode; then
        echo -e "\n--- Changed/Missing Package Files ---"
        if command -v debsums &>/dev/null; then
            local debsums_output; debsums_output=$(debsums -c 2>/dev/null || true)
            if [[ -n "$debsums_output" ]]; then
                log_warn "Found changed configuration files (this can be normal):"
                echo "$debsums_output"
            else
                log_info "No changed or missing package files found."
            fi
        else
            log_warn "debsums not found. Skipping package file integrity check."
        fi
    fi
}

check_services_and_logs() {
    exec > "$1" 2>&1
    log_section "SERVICES & SYSTEM LOGS"
    echo "--- Failed Systemd Services ---"
    if ! systemctl is-system-running --quiet; then
        log_warn "System is not in a running state. Checking for failed services."
        systemctl --failed --no-pager
    else log_info "No failed systemd services."; fi
    
    echo -e "\n--- Recent System Logs (Errors/Warnings) ---"
    local syslog_errors; syslog_errors=$(grep -E '(?i)error|warn|fail' /var/log/syslog | tail -n 10 || true)
    if [[ -n "$syslog_errors" ]]; then
        log_warn "Found potential errors/warnings in /var/log/syslog:"
        echo "$syslog_errors"
    else
        log_info "No recent errors or warnings found in syslog."
    fi
}

# --- Main Logic ---
main() {
    echo -e "${BLUE}=== Ubuntu/Debian Health Check v${SCRIPT_VERSION} ===${NC}"
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
    local upgradable_pkgs; upgradable_pkgs=$(grep -o '^[0-9]\+' "$final_log_plain" | head -n1 || echo 0)
    
    score=$((score - failed_services * 25 - unclaimed_devices * 10 - upgradable_pkgs * 1))
    [[ $score -lt 0 ]] && score=0
    if [[ $failed_services -gt 0 ]]; then score_details+="Failed Services (-25) "; fi
    if [[ $unclaimed_devices -gt 0 ]]; then score_details+="Unclaimed Devices (-10) "; fi
    if [[ $upgradable_pkgs -gt 0 ]]; then score_details+="${upgradable_pkgs} Upgradable Pkgs (-${upgradable_pkgs}) "; fi

    local score_report="${WORK_DIR}/99-score.log"
    {
        log_section "HEALTH SCORE"
        log_info "System Health Score: ${score}/100"
        if [[ -n "$score_details" ]]; then log_warn "Deductions from: ${score_details}"; else log_info "No major issues detected."; fi
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
    # Generate MD and HTML reports...

    echo -e "\n${GREEN}✔ Reports saved successfully to '${opt_output_dir}'${NC}"
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}NOTE: Some optional dependencies were not found.${NC}"
        echo "For a full report, run: ${GREEN}sudo apt update && sudo apt install ${missing_pkgs}${NC}"
    fi
}

main "$@"