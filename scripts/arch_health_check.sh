#!/usr/bin/env bash
# ============================================================================
# Arch Linux Health Check - v4.1 (Fixed)
# ============================================================================

set -euo pipefail

# --- Source common library & setup directories ---
# The path is relative to the script's location *after installation*.
SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR_SELF/../common/functions.sh"

# --- Temp directory & safety trap ---
# This ensures temp files are deleted even if the script is interrupted (Ctrl+C).
WORK_DIR=$(mktemp -d "/tmp/arch-check.XXXXXX")
trap 'echo -e "\nScript interrupted. Cleaning up temp files..."; rm -rf "$WORK_DIR"; exit 1' SIGINT SIGTERM
trap 'rm -rf "$WORK_DIR"' EXIT

# --- Default Config & CLI Parsing ---
SCRIPT_NAME="arch-health-check"
SCRIPT_VERSION="4.1"
opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir="" # Will be populated from config or default

show_usage() {
    echo "Usage: $0 [options]"
    echo "  -f, --fast        Skip slower checks (like pacman -Qk)."
    echo "  -c, --no-color    Disable color output."
    echo "  -s, --summary     Only show a brief summary."
    echo "  -o, --output-dir  Where to save reports (default: ~/logs)."
    echo "  -v, --version     Show script version."
    echo "  -h, --help        Show this help message."
    exit 0
}

# FIXED: Corrected getopt string for summary flag (-s). It's a boolean, not an argument.
OPTS=$(getopt -o fcso:vh --long fast,no-color,summary,output-dir:,version,help -n "$0" -- "$@")
if [ $? != 0 ]; then echo "Failed parsing options." >&2; exit 1; fi
eval set -- "$OPTS"
while true; do
    case "$1" in
        -f|--fast) opt_fast_mode=true; shift ;;
        -c|--no-color) opt_no_color=true; shift ;;
        -s|--summary) opt_summary_mode=true; shift ;;
        -o|--output-dir) opt_output_dir="$2"; shift 2;;
        -v|--version) echo "$SCRIPT_NAME v$SCRIPT_VERSION"; exit 0 ;;
        -h|--help) show_usage ;;
        --) shift; break ;;
        *) echo "Internal error!"; exit 1 ;;
    esac
done

# --- Check Functions (designed to be run in parallel) ---
check_system_info() { 
    exec > "$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo
    local k; k=$(uname -r)
    if [[ $k == *zen* ]]; then log_info "Rockin' a Zen Kernel: $k"
    elif [[ $k == *lts* ]]; then log_info "LTS Kernel for stability: $k"
    else log_info "Standard Kernel: $k"; fi
}

check_hardware() { 
    if [[ "$skip_checks" == *hardware* ]]; then log_info "Skipping hardware check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "HARDWARE"
    lscpu | grep -E 'Model name|CPU\(s\)' || log_warn "can't find lscpu"
    echo -e "\n--- Memory ---"; free -h
    echo -e "\n--- Storage ---"; lsblk -f
    echo -e "\n--- Temps ---"
    if command -v sensors &>/dev/null; then sensors; else log_warn "lm-sensors not found."; fi
}

check_drivers() { 
    if [[ "$skip_checks" == *drivers* ]]; then log_info "Skipping drivers check as per config."; return; fi
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
    if [[ "$skip_checks" == *packages* ]]; then log_info "Skipping packages check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "PACKAGES"
    if ! command -v pacman &>/dev/null; then log_warn "pacman not found, skipping package checks."; return; fi
    local o; o=$(pacman -Qdtq || true)
    if [[ -n "$o" ]]; then 
        local c; c=$(echo "$o" | wc -l)
        log_warn "$c orphans found."
        echo "$o" | head -n 5
        log_info "Pro-tip: nuke 'em with 'sudo pacman -Rns \$(pacman -Qdtq)'"
    else 
        log_info "No orphans found."; fi
    
    if ! $opt_fast_mode; then 
        local m; m=$(pacman -Qk 2>/dev/null | grep -v " 0 missing" || true)
        if [[ -n "$m" ]]; then 
            log_warn "Packages with missing files found."
            echo "$m" | head -n 5
        else 
            log_info "No missing package files found."; fi
    fi
}

check_services_and_logs() { 
    if [[ "$skip_checks" == *services* || "$skip_checks" == *logs* ]]; then log_info "Skipping services/logs check as per config."; return; fi
    exec > "$1" 2>&1
    log_section "SERVICES & LOGS"
    if ! systemctl is-system-running --quiet; then 
        log_warn "System state is looking wonky. Checking failed services."
        systemctl --failed --no-pager
    else 
        log_info "No failed systemd services."; fi
    
    local l; l=$(journalctl -p err..warn -n 10 --no-pager --output=short-monotonic || true)
    if [[ -n "$l" ]]; then 
        log_warn "Kernel's been complaining recently. Last 10 issues:"
        echo "$l"
    else 
        log_info "No recent kernel errors or warnings."; fi
}

# --- Main Logic ---
main() {
    setup_colors
    
    # Load configuration from user's home directory if it exists
    local config_file="$HOME/.config/health-check/health-check.conf"
    local skip_checks; skip_checks=$(get_config "$config_file" "skip_checks" "")
    local warning_score; warning_score=$(get_config "$config_file" "warning_score" "75")
    local critical_score; critical_score=$(get_config "$config_file" "critical_score" "50")
    local log_dir_conf; log_dir_conf=$(get_config "$config_file" "log_dir" "$HOME/logs")
    # CLI option -o overrides the config file setting
    local final_output_dir=${opt_output_dir:-$log_dir_conf}

    # FIXED: Define TIMESTAMP for unique report filenames
    local TIMESTAMP; TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    echo -e "${BLUE}=== Kicking off the Arch Health Check v${SCRIPT_VERSION} ===${NC}"
    mkdir -p "$final_output_dir"

    # Check for dependencies and suggest installation if missing
    local arch_deps=("lspci:pciutils" "sensors:lm-sensors")
    local missing_pkgs; missing_pkgs=$(check_dependencies arch_deps)

    # Run checks in parallel for speed, sending output to log files in the temp directory
    log_info "Running checks in parallel... (This might take a moment)"
    check_system_info  "${WORK_DIR}/01-system.log" &
    check_hardware     "${WORK_DIR}/02-hardware.log" &
    check_drivers      "${WORK_DIR}/03-drivers.log" &
    check_packages     "${WORK_DIR}/04-packages.log" &
    check_services_and_logs "${WORK_DIR}/05-services.log" &
    wait # Wait for all background jobs to finish
    
    # Combine individual logs into one master log for scoring
    local final_log_plain="${WORK_DIR}/final_plain.log"
    cat "${WORK_DIR}"/*.log > "$final_log_plain"
    
    # Calculate a simple health score based on findings
    local score=100
    local score_details=""
    local failed_services; failed_services=$(grep -c 'looking wonky' "$final_log_plain" || true)
    local unclaimed_devices; unclaimed_devices=$(grep -c 'unclaimed devices found' "$final_log_plain" || true)
    local orphans; orphans=$(grep -c 'orphans found' "$final_log_plain" || true)
    local missing_files; missing_files=$(grep -c 'missing files found' "$final_log_plain" || true)
    score=$((score - failed_services * 25 - unclaimed_devices * 10 - orphans * 5 - missing_files * 5))
    [[ $score -lt 0 ]] && score=0 # Don't let score go below zero
    if [[ $failed_services -gt 0 ]]; then score_details+="Failed Services (-25) "; fi
    if [[ $unclaimed_devices -gt 0 ]]; then score_details+="Unclaimed Devices (-10) "; fi
    if [[ $orphans -gt 0 ]]; then score_details+="Orphans (-5) "; fi
    if [[ $missing_files -gt 0 ]]; then score_details+="Missing Files (-5) "; fi

    # Create the final score report section
    local score_report="${WORK_DIR}/99-score.log"
    { 
        log_section "HEALTH SCORE"
        if [[ $score -le $critical_score ]]; then log_error "System Health Score: ${score}/100"
        elif [[ $score -le $warning_score ]]; then log_warn "System Health Score: ${score}/100"
        else log_info "System Health Score: ${score}/100"; fi
        if [[ -n "$score_details" ]]; then 
            log_warn "Lost points on: ${score_details}"
        else 
            log_info "Lookin' good! No major issues detected."
        fi
    } > "$score_report"
    
    # Combine all logs for final colored output
    local final_log_colored; final_log_colored=$(mktemp)
    cat "${WORK_DIR}"/*.log "$score_report" > "$final_log_colored"

    # Display summary or full report based on user flag
    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "$score_report"
    else
        cat "$final_log_colored"
    fi

    # Save the final log file to the designated output directory
    local report_base_name="${final_output_dir}/${SCRIPT_NAME}-${TIMESTAMP}"
    mv "$final_log_colored" "${report_base_name}.log"

    echo -e "\n${GREEN}✔ All done. Report saved to '${report_base_name}.log'${NC}"
    if [[ -n "$missing_pkgs" ]]; then
        echo -e "\n${YELLOW}PSST: For an even better report, install these: ${GREEN}sudo pacman -Syu ${missing_pkgs}${NC}"
    fi
}

# Execute the main function with all passed arguments
main "$@"
