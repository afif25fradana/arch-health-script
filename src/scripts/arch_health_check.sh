#!/usr/bin/env bash
# ============================================================================
# Arch Linux Health Check
# ============================================================================

set -euo pipefail

SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR_SELF/../common/functions.sh"
setup_colors

WORK_DIR=$(mktemp -d "/tmp/arch-check.XXXXXX")
trap 'echo -e "\nScript interrupted. Cleaning up temp files..."; rm -rf "$WORK_DIR"; exit 1' SIGINT SIGTERM
trap 'rm -rf "$WORK_DIR"' EXIT

opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir=""

show_usage() {
    cat <<EOF
Usage: $0 [options]
  -f, --fast        Skip slower checks (like pacman -Qk).
  -c, --no-color    Disable color output.
  -s, --summary     Only show a brief summary.
  -o, --output-dir  Where to save reports (default: ~/logs).
  -h, --help        Show this help message.
EOF
    exit 0
}

parse_cli_args() {
    local opts
    opts=$(getopt -o fcso:h --long fast,no-color,summary,output-dir:,help -n "$0" -- "$@")
    if (($? != 0)); then
        log_error "Failed parsing options."
        exit 1
    fi
    eval set -- "$opts"
    while true; do
        case "$1" in
            -f | --fast) opt_fast_mode=true; shift ;;
            -c | --no-color) opt_no_color=true; shift ;;
            -s | --summary) opt_summary_mode=true; shift ;;
            -o | --output-dir) opt_output_dir="$2"; shift 2 ;;
            -h | --help) show_usage ;;
            --) shift; break ;;
            *) log_error "Internal error!"; exit 1 ;;
        esac
    done
}

check_system_info() {
    exec >"$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo
    local kernel
    kernel=$(uname -r)
    if [[ "$kernel" == *zen* ]]; then log_info "Zen Kernel detected: $kernel"
    elif [[ "$kernel" == *lts* ]]; then log_info "LTS Kernel detected: $kernel"
    else log_info "Standard Kernel: $kernel"; fi
}

check_hardware() {
    exec >"$1" 2>&1
    log_section "HARDWARE"
    lscpu | grep -E 'Model name|CPU\(s\)' || log_warn "lscpu not found"
    log_subsection "Memory"
    free -h
    log_subsection "Storage"
    lsblk -f
    log_subsection "Temps"
    if command -v sensors &>/dev/null; then sensors; else log_warn "lm-sensors not found."; fi
}

check_drivers() {
    exec >"$1" 2>&1
    log_section "DRIVERS"
    if ! command -v lspci &>/dev/null; then
        log_warn "pciutils not found."
        return
    fi
    lspci -nnk | grep -A3 'VGA\|Network\|Audio'
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then
        log_warn "Unclaimed PCI devices found, indicating missing drivers."
        lspci -nnk | grep -i "UNCLAIMED"
        touch "${WORK_DIR}/issue_unclaimed_devices"
    else
        log_info "All PCI devices appear to have drivers."
    fi
}

check_packages() {
    exec >"$1" 2>&1
    log_section "PACKAGES"
    if ! command -v pacman &>/dev/null; then
        log_warn "pacman not found, skipping package checks."
        return
    fi
    if orphans=$(pacman -Qdtq); [[ -n "$orphans" ]]; then
        log_warn "$(echo "$orphans" | wc -l) orphaned packages found."
        echo "$orphans" | head -n 5
        log_info "Run 'sudo pacman -Rns \$(pacman -Qdtq)' to remove."
        touch "${WORK_DIR}/issue_orphans"
    else
        log_info "No orphaned packages found."
    fi

    if ! $opt_fast_mode; then
        if missing_files=$(pacman -Qk 2>/dev/null | grep -v " 0 missing"); [[ -n "$missing_files" ]]; then
            log_warn "Packages with missing files found."
            echo "$missing_files" | head -n 5
            touch "${WORK_DIR}/issue_missing_files"
        else
            log_info "No missing package files found."
        fi
    fi
}

check_services_and_logs() {
    exec >"$1" 2>&1
    log_section "SERVICES & LOGS"
    if ! systemctl is-system-running --quiet; then
        log_warn "System state is degraded. Checking for failed services..."
        systemctl --failed --no-pager
        touch "${WORK_DIR}/issue_failed_services"
    else
        log_info "Systemd state is running normally."
    fi

    if errors=$(journalctl -p WARNING..ERR -n 10 --no-pager --output=short-monotonic 2>/dev/null); [[ -n "$errors" ]]; then
        log_warn "Recent kernel errors or warnings found:"
        echo "$errors"
    else
        log_info "No recent kernel errors or warnings."
    fi
}

load_configuration() {
    local system_config="/etc/health-check/health-check.conf"
    local user_config="$HOME/.config/health-check/health-check.conf"
    local config_file=""

    [[ -f "$user_config" ]] && config_file="$user_config"
    [[ -f "$system_config" ]] && config_file="$system_config"

    load_config "$config_file" \
        "skip_checks" "" \
        "warning_score" "75" \
        "critical_score" "50" \
        "log_dir" "$HOME/logs"

    declare -gA DEDUCTIONS_MAP
    load_config_array "$config_file" "deductions" "failed_services:25,unclaimed_devices:10,orphans:5,missing_files:5"
    for item in "${deductions[@]}"; do
        DEDUCTIONS_MAP["${item%%:*}"]="${item##*:}"
    done
}

run_all_checks() {
    log_info "Running checks in parallel..."
    run_check "check_system_info" "${WORK_DIR}/01-system.log" "system_info" &
    run_check "check_hardware" "${WORK_DIR}/02-hardware.log" "hardware" &
    run_check "check_drivers" "${WORK_DIR}/03-drivers.log" "drivers" &
    run_check "check_packages" "${WORK_DIR}/04-packages.log" "packages" &
    run_check "check_services_and_logs" "${WORK_DIR}/05-services.log" "services,logs" &
    wait
}

calculate_score() {
    local score=100
    local details=""
    local issue_dir="$1"

    for issue_file in "$issue_dir"/issue_*; do
        [[ ! -f "$issue_file" ]] && continue
        local issue_name
        issue_name=$(basename "$issue_file" | sed 's/issue_//')
        local deduction=${DEDUCTIONS_MAP[$issue_name]}
        details+="$(tr '_' ' ' <<<"$issue_name" | sed 's/\b\(.\)/\u\1/g') (-$deduction) "
        score=$((score - deduction))
    done

    ((score < 0)) && score=0
    echo "$score:$details"
}

generate_report() {
    local score=$1
    local score_details="$2"
    local final_log_colored
    final_log_colored=$(mktemp)

    local score_report="${WORK_DIR}/99-score.log"
    {
        log_section "HEALTH SCORE"
        if ((score <= critical_score)); then log_error "System Health Score: ${score}/100"
        elif ((score <= warning_score)); then log_warn "System Health Score: ${score}/100"
        else log_info "System Health Score: ${score}/100"; fi
        
        if [[ -n "$score_details" ]]; then
            log_warn "Lost points on: ${score_details}"
        else
            log_info "No major issues detected."
        fi
    } >"$score_report"

    cat "${WORK_DIR}"/*.log "$score_report" >"$final_log_colored"

    if $opt_summary_mode; then
        echo -e "\n${BLUE}=== SUMMARY ===${NC}"
        grep '\[WARN\]\|\[ERROR\]' "$final_log_colored" || log_info "No warnings or errors to display."
    else
        cat "$final_log_colored"
    fi

    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local report_base_name="${final_output_dir}/arch-health-check-${timestamp}"
    mv "$final_log_colored" "${report_base_name}.log"

    echo -e "\n${GREEN}✔ All done. Report saved to '${report_base_name}.log'${NC}"
}

main() {
    parse_cli_args "$@"
    load_configuration

    local final_output_dir=${opt_output_dir:-$log_dir}
    if ! mkdir -p "$final_output_dir"; then
        log_error "Failed to create output directory: '$final_output_dir'."
        exit 1
    fi
    if [[ ! -w "$final_output_dir" ]]; then
        log_error "Output directory '$final_output_dir' is not writable."
        exit 1
    fi

    echo -e "${BLUE}=== Kicking off the Arch Health Check ===${NC}"

    local arch_deps=("lspci:pciutils" "sensors:lm-sensors")
    local missing_pkgs
    missing_pkgs=$(check_dependencies "${arch_deps[@]}")

    run_all_checks

    local score_data
    score_data=$(calculate_score "$WORK_DIR")
    local score
    score=$(cut -d: -f1 <<<"$score_data")
    local score_details
    score_details=$(cut -d: -f2- <<<"$score_data")

    generate_report "$score" "$score_details"

    if [[ -n "$missing_pkgs" ]]; then
        echo
        log_warn "Some checks were skipped due to missing dependencies."
        log_info "For a more accurate report, please install the following packages: ${missing_pkgs}"
        log_info "You can do this by running: ${GREEN}sudo pacman -Syu ${missing_pkgs}${NC}"
    fi
}

main "$@"
