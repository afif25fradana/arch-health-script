#!/usr/bin/env bash
# ============================================================================
# Ubuntu/Debian Health Check - v2.1
# ============================================================================

set -euo pipefail

# --- Source common library & setup directories ---
SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR_SELF/../common/functions.sh"

# --- Temp directory & safety trap ---
WORK_DIR=$(mktemp -d "/tmp/ubuntu-check.XXXXXX")
trap 'echo -e "\nScript interrupted. Cleaning up temp files..."; rm -rf "$WORK_DIR"; exit 1' SIGINT SIGTERM
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Default Config & CLI Parsing ---
SCRIPT_VERSION="2.1"
opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir=""

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

OPTS=$(getopt -o fcso:vh --long fast,no-color,summary,output-dir:,version,help -n "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed parsing options." >&2; exit 1; fi
eval set -- "$OPTS"
while true; do
    case "$1" in
        -f|--fast) opt_fast_mode=true; shift ;;
        -c|--no-color) opt_no_color=true; shift ;;
        -s|--summary) opt_summary_mode=true; shift ;;
        -o|--output-dir) opt_output_dir="$2"; shift 2;;
        -v|--version) echo "ubuntu-health-check v$SCRIPT_VERSION"; exit 0 ;;
        -h|--help) show_usage ;;
        --) shift; break ;;
        *) echo "Internal error!"; exit 1 ;;
    esac
done

# --- Check Functions ---
check_system_info() { 
    exec > "$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo
    log_info "Kernel: $(uname -r)"
    log_info "Distro: $(lsb_release -ds)"
}

check_hardware() { 
    if [[ "$skip_checks" == *hardware* ]]; then log_info "Skipping hardware check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "HARDWARE"
    lscpu | grep -E 'Model name|CPU\(s\)' || log_warn "can't find lscpu"
    log_subsection "Memory"
    free -h
    log_subsection "Storage"
    lsblk -f
    log_subsection "Temps"
    if command -v sensors &>/dev/null; then sensors; else log_warn "lm-sensors not found."; fi
}

check_drivers() { 
    if [[ "$skip_checks" == *drivers* ]]; then log_info "Skipping drivers check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "DRIVERS"
    if ! command -v lspci >/dev/null; then log_warn "pciutils not found."; return; fi
    lspci -nnk | grep -A3 'VGA\|Network\|Audio'
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then
        log_warn "Unclaimed PCI devices found. These may lack proper drivers."
        lspci -nnk | grep -i "UNCLAIMED"
        touch "${WORK_DIR}/issue_unclaimed_devices"
    else
        log_info "All PCI devices appear to have drivers."
    fi
}

check_packages() { 
    if [[ "$skip_checks" == *packages* ]]; then log_info "Skipping packages check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "PACKAGES (APT)"
    local upgradable_count
    upgradable_count=$(apt list --upgradable 2>/dev/null | grep -vc "Listing...")
    if [[ "$upgradable_count" -gt 0 ]]; then
        log_warn "$upgradable_count packages can be upgraded."
        log_info "Tip: run 'sudo apt update && sudo apt upgrade' to fix."
        echo "$upgradable_count" > "${WORK_DIR}/issue_upgradable_pkgs"
    else
        log_info "System is up-to-date."
    fi
    
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
    if [[ "$skip_checks" == *services* || "$skip_checks" == *logs* ]]; then log_info "Skipping services/logs check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "SERVICES & LOGS"
    if ! systemctl is-system-running --quiet; then
        log_warn "System state is degraded. Checking for failed services..."
        systemctl --failed --no-pager
        touch "${WORK_DIR}/issue_failed_services"
    else
        log_info "Systemd state is running normally."
    fi
    
    local l; l=$(grep -E -i 'error|warn|fail' /var/log/syslog | tail -n 10 || true)
    if [[ -n "$l" ]]; then 
        log_warn "Found some errors/warnings in syslog:"
        echo "$l"
    else 
        log_info "No recent errors or warnings in syslog."; fi
}

# --- Main Logic ---
main() {
    setup_colors

    local system_config_file="/etc/health-check/health-check.conf"
    local user_config_file="$HOME/.config/health-check/health-check.conf"
    local config_file=""
    if [[ -f "$user_config_file" ]]; then
        config_file="$user_config_file"
    elif [[ -f "$system_config_file" ]]; then
        config_file="$system_config_file"
    fi
    
    local skip_checks; skip_checks=$(get_config "$config_file" "skip_checks" "")
    local warning_score; warning_score=$(get_config "$config_file" "warning_score" "75")
    local critical_score; critical_score=$(get_config "$config_file" "critical_score" "50")
    local log_dir_conf; log_dir_conf=$(get_config "$config_file" "log_dir" "$HOME/logs")
    local final_output_dir=${opt_output_dir:-$log_dir_conf}
    
    local TIMESTAMP; TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    echo -e "${BLUE}=== Kicking off the Ubuntu/Debian Health Check v${SCRIPT_VERSION} ===${NC}"
    mkdir -p "$final_output_dir"

    local ubuntu_deps=("lspci:pciutils" "sensors:lm-sensors" "deborphan:deborphan" "debsums:debsums")
    local missing_pkgs; missing_pkgs=$(check_dependencies ubuntu_deps)

    log_info "Running checks in parallel... (This might take a moment)"
    check_system_info  "${WORK_DIR}/01-system.log" &
    check_hardware     "${WORK_DIR}/02-hardware.log" &
    check_drivers      "${WORK_DIR}/03-drivers.log" &
    check_packages     "${WORK_DIR}/04-packages.log" &
    check_services_and_logs "${WORK_DIR}/05-services.log" &
    wait
    
    local final_log_plain="${WORK_DIR}/final_plain.log"
    cat "${WORK_DIR}"/*.log > "$final_log_plain"
    
    # --- Scoring ---
    local score=100
    local score_details=""

    declare -A DEDUCTIONS
    DEDUCTIONS["failed_services"]=25
    DEDUCTIONS["unclaimed_devices"]=10
    DEDUCTIONS["upgradable_pkgs"]=1

    if [[ -f "${WORK_DIR}/issue_failed_services" ]]; then
        score=$((score - DEDUCTIONS["failed_services"]))
        score_details+="Failed Services (-${DEDUCTIONS[failed_services]}) "
    fi
    if [[ -f "${WORK_DIR}/issue_unclaimed_devices" ]]; then
        score=$((score - DEDUCTIONS["unclaimed_devices"]))
        score_details+="Unclaimed Devices (-${DEDUCTIONS[unclaimed_devices]}) "
    fi
    if [[ -f "${WORK_DIR}/issue_upgradable_pkgs" ]]; then
        local upgradable_count; upgradable_count=$(<"${WORK_DIR}/issue_upgradable_pkgs")
        local deduction=$((upgradable_count * DEDUCTIONS["upgradable_pkgs"]))
        score=$((score - deduction))
        score_details+="${upgradable_count} Upgradable Pkgs (-${deduction}) "
    fi
    
    [[ $score -lt 0 ]] && score=0

    local score_report="${WORK_DIR}/99-score.log"
    { 
        log_section "HEALTH SCORE"
        if [[ $score -le $critical_score ]]; then log_error "System Health Score: ${score}/100"
        elif [[ $score -le $warning_score ]]; then log_warn "System Health Score: ${score}/100"
        else log_info "System Health Score: ${score}/100"; fi
        if [[ -n "$score_details" ]]; then 
            log_warn "Lost points on: ${score_details}"
        else 
            log_info "Lookin' good! No major issues detected."; fi
    } > "$score_report"
    
    local final_log_colored; final_log_colored=$(mktemp)
    cat "${WORK_DIR}"/*.log "$score_report" > "$final_log_colored"

    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "$score_report"
    else
        cat "$final_log_colored"
    fi

    local report_base_name="${final_output_dir}/ubuntu-health-check-${TIMESTAMP}"
    mv "$final_log_colored" "${report_base_name}.log"

    echo -e "\n${GREEN}✔ All done. Report saved to '${report_base_name}.log'${NC}"
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}PSST: For a better report, install these: ${GREEN}sudo apt update && sudo apt install ${missing_pkgs}${NC}"
    fi
}

main "$@"
