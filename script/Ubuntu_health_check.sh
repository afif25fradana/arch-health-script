#!/usr/bin/env bash
# ============================================================================
# Ubuntu/Debian Health Check - v1.3 (Casual Edition)
# ============================================================================

set -euo pipefail

# --- Pull in the shared functions ---
SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=../common/functions.sh
source "$SCRIPT_DIR_SELF/../common/functions.sh"

# --- Script Config ---
SCRIPT_NAME="ubuntu-health-check"
SCRIPT_VERSION="1.3"
LOG_DIR="$HOME/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir="$LOG_DIR"

# --- CLI Options & Help ---
show_usage() {
    echo "Usage: $0 [options]"
    echo "  -f, --fast        Skip slower checks (like debsums)."
    echo "  -c, --no-color    Disable color output."
    echo "  -s, --summary     Only show a brief summary."
    echo "  -o, --output-dir  Where to save reports (default: ~/logs)."
    echo "  -v, --version     Show script version."
    echo "  -h, --help        Show this help message."
    exit 0
}

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

# --- Temp directory for parallel logs ---
WORK_DIR=$(mktemp -d "/tmp/${SCRIPT_NAME}.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Check Functions (run in parallel) ---
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
    lscpu | grep -E 'Model name|CPU\(s\)' || log_warn "can't find lscpu"
    echo -e "\n--- Memory ---"; free -h
    echo -e "\n--- Storage ---"; lsblk -f
    echo -e "\n--- Temps ---"
    if command -v sensors &>/dev/null; then sensors; else log_warn "lm-sensors not found."; fi
}
check_drivers() { 
    exec > "$1" 2>&1
    log_section "DRIVERS"
    if ! command -v lspci >/dev/null; then log_warn "pciutils not found."; return; fi
    lspci -nnk | grep -A3 'VGA\|Network\|Audio'
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then 
        log_warn "Whoa, unclaimed devices found. These might be broken."
        lspci -nnk | grep -i "UNCLAIMED"
    else 
        log_info "All PCI devices seem to have drivers."; fi
}
check_packages() { 
    exec > "$1" 2>&1
    log_section "PACKAGES (APT)"
    local u; u=$(apt list --upgradable 2>/dev/null | grep -vc "Listing...")
    if [[ "$u" -gt 0 ]]; then 
        log_warn "$u packages can be upgraded."
        log_info "Tip: run 'sudo apt update && sudo apt upgrade' to fix."
    else 
        log_info "System is up-to-date."; fi
    
    if command -v deborphan &>/dev/null; then
        local o; o=$(deborphan || true)
        if [[ -n "$o" ]]; then 
            log_warn "Orphans found by deborphan:"
            echo "$o"
        else 
            log_info "No orphans found by deborphan."; fi
    else
        log_warn "deborphan not found. For a better orphan check, install it."
    fi

    if ! $opt_fast_mode; then
        if command -v debsums &>/dev/null; then
            local d; d=$(debsums -c 2>/dev/null || true)
            if [[ -n "$d" ]]; then 
                log_warn "Found changed config files (this can be normal):"
                echo "$d"
            else 
                log_info "No changed package files found."; fi
        else
            log_warn "debsums not found. Skipping file integrity check."
        fi
    fi
}
check_services_and_logs() { 
    exec > "$1" 2>&1
    log_section "SERVICES & LOGS"
    if ! systemctl is-system-running --quiet; then 
        log_warn "System state is looking wonky. Checking failed services."
        systemctl --failed --no-pager
    else 
        log_info "No failed systemd services."; fi
    
    local l; l=$(grep -E '(?i)error|warn|fail' /var/log/syslog | tail -n 10 || true)
    if [[ -n "$l" ]]; then 
        log_warn "Found some errors/warnings in syslog:"
        echo "$l"
    else 
        log_info "No recent errors or warnings in syslog."; fi
}

# --- Main Logic ---
main() {
    setup_colors
    echo -e "${BLUE}=== Kicking off the Ubuntu/Debian Health Check v${SCRIPT_VERSION} ===${NC}"
    mkdir -p "$opt_output_dir"

    local ubuntu_deps=("lspci:pciutils" "sensors:lm-sensors" "deborphan:deborphan" "debsums:debsums")
    local missing_pkgs
    missing_pkgs=$(check_dependencies ubuntu_deps)

    # Run all checks in the background
    check_system_info  "${WORK_DIR}/01-system.log" &
    check_hardware     "${WORK_DIR}/02-hardware.log" &
    check_drivers      "${WORK_DIR}/03-drivers.log" &
    check_packages     "${WORK_DIR}/04-packages.log" &
    check_services_and_logs "${WORK_DIR}/05-services.log" &
    wait # Wait for them to finish
    
    # Combine logs for scoring
    local final_log_plain="${WORK_DIR}/final_plain.log"
    cat "${WORK_DIR}"/*.log > "$final_log_plain"
    
    # Calculate health score
    local score=100
    local score_details=""
    local failed_services; failed_services=$(grep -c 'not in a running state' "$final_log_plain" || true)
    local unclaimed_devices; unclaimed_devices=$(grep -c 'Unclaimed devices found' "$final_log_plain" || true)
    local upgradable_pkgs; upgradable_pkgs=$(grep -o '^[0-9]\+ packages can be upgraded' "$final_log_plain" | grep -o '^[0-9]\+' || echo 0)
    
    score=$((score - failed_services * 25 - unclaimed_devices * 10 - upgradable_pkgs * 1))
    [[ $score -lt 0 ]] && score=0
    if [[ $failed_services -gt 0 ]]; then score_details+="Failed Services (-25) "; fi
    if [[ $unclaimed_devices -gt 0 ]]; then score_details+="Unclaimed Devices (-10) "; fi
    if [[ $upgradable_pkgs -gt 0 ]]; then score_details+="${upgradable_pkgs} Upgradable Pkgs (-${upgradable_pkgs}) "; fi

    # Create the score report
    local score_report="${WORK_DIR}/99-score.log"
    { 
        log_section "HEALTH SCORE"
        log_info "System Health Score: ${score}/100"
        if [[ -n "$score_details" ]]; then 
            log_warn "Lost points on: ${score_details}"
        else 
            log_info "Lookin' good! No major issues."; fi
    } > "$score_report"
    
    # Combine all logs for final output
    local final_log_colored; final_log_colored=$(mktemp)
    cat "${WORK_DIR}"/*.log "$score_report" > "$final_log_colored"

    # Display summary or full report
    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "$score_report"
    else
        cat "$final_log_colored"
    fi

    # Save the final log file
    local report_base_name="${opt_output_dir}/${SCRIPT_NAME}-${TIMESTAMP}"
    mv "$final_log_colored" "${report_base_name}.log"

    echo -e "\n${GREEN}✔ All done. Report saved to '${report_base_name}.log'${NC}"
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}PSST: For an even better report, install these: ${GREEN}sudo apt update && sudo apt install ${missing_pkgs}${NC}"
    fi
}

main "$@"
