#!/usr/bin/env bash
# ============================================================================
# Common Health Check Functions
# ============================================================================

# This script is intended to be sourced by distribution-specific scripts.

setup_colors

if ! WORK_DIR=$(mktemp -d "/tmp/health-check.XXXXXX"); then
    log_error "Failed to create temporary directory in /tmp. Please ensure it's writable."
    exit 1
fi

trap 'echo -e "\nScript interrupted. Cleaning up temp files..."; rm -rf "$WORK_DIR"; exit 1' SIGINT SIGTERM
trap 'rm -rf "$WORK_DIR"' EXIT


opt_fast_mode=false
opt_no_color=false
opt_summary_mode=false
opt_output_dir=""

show_usage() {
    cat <<EOF
Usage: $0 [options]
  -f, --fast        Skip slower checks.
  -c, --no-color    Disable color output.
  -s, --summary     Only show a brief summary.
  -o, --output-dir  Where to save reports (default: ~/logs).
  --public          Censor sensitive information for sharing.
  -h, --help        Show this help message.
EOF
    exit 0
}

parse_cli_args() {
    while (($# > 0)); do
        case "$1" in
            -f|--fast)
                opt_fast_mode=true
                shift
                ;; 
            -c|--no-color)
                opt_no_color=true
                shift
                ;; 
            -s|--summary)
                opt_summary_mode=true
                shift
                ;; 
            -o|--output-dir)
                if [[ -z "$2" || "$2" == -* ]]; then
                    log_error "Option '$1' requires an argument."
                    exit 1
                fi
                opt_output_dir="$2"
                shift 2
                ;; 
            --public)
                opt_public_mode=true
                shift
                ;; 
            -h|--help)
                show_usage
                ;; 
            --)
                shift
                break
                ;; 
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;; 
            *)
                # Stop processing options
                break
                ;; 
        esac
    done
}

check_system_info() {
    exec >"$1" 2>&1
    log_section "SYSTEM & KERNEL"
    hostnamectl
    echo
    log_info "Kernel: $(uname -r)"
    if command -v lsb_release &>/dev/null; then
        log_info "Distro: $(lsb_release -ds)"
    fi
}

check_hardware() {
    exec >"$1" 2>&1
    log_section "HARDWARE"
    lscpu | grep -E 'Model name|CPU(s)'
    log_subsection "Memory"
    free -h
    log_subsection "Storage"
    lsblk -f
    log_subsection "Temps"
    if command -v sensors &>/dev/null; then
        sensors
    else
        log_warn "lm-sensors not found. Temperature check skipped."
    fi
}

check_drivers() {
    exec >"$1" 2>&1
    log_section "DRIVERS"
    if ! command -v lspci &>/dev/null; then
        log_warn "pciutils not found. Driver check skipped."
        return
    fi
    lspci -nnk | grep -A3 'VGA|Network|Audio'
    if lspci -nnk | grep -i "UNCLAIMED" >/dev/null; then
        log_warn "Unclaimed PCI devices found, indicating missing drivers."
        lspci -nnk | grep -i "UNCLAIMED"
        touch "${WORK_DIR}/issue_unclaimed_devices"
    else
        log_info "All PCI devices appear to have drivers."
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

    log_subsection "Recent Logs"
    if command -v journalctl &>/dev/null; then
        if errors=$(journalctl -p WARNING..ERR -n 10 --no-pager --output=short-monotonic 2>/dev/null); [[ -n "$errors" ]]; then
            log_warn "Recent kernel errors or warnings found:"
            echo "$errors"
            touch "${WORK_DIR}/issue_journal_errors"
        else
            log_info "No recent kernel errors or warnings."
        fi
    elif [[ -r "/var/log/syslog" ]]; then
        if errors=$(grep -E -i 'error|warn|fail' /var/log/syslog | tail -n 10); [[ -n "$errors" ]]; then
            log_warn "Found errors/warnings in syslog:"
            echo "$errors"
            touch "${WORK_DIR}/issue_syslog_errors"
        else
            log_info "No recent errors or warnings in syslog."
        fi
    else
        log_warn "Could not find journalctl or read /var/log/syslog."
    fi
}

check_network() {
    exec >"$1" 2>&1
    log_section "NETWORK"

    log_subsection "Firewall Status"
    if command -v ufw &>/dev/null; then
        log_info "UFW Status:"
        ufw status verbose
        if ufw status | grep -q "Status: active"; then
            log_info "UFW is active."
        else
            log_warn "UFW is inactive."
            touch "${WORK_DIR}/issue_inactive_firewall"
        fi
    elif command -v firewall-cmd &>/dev/null; then
        log_info "FirewallD Status:"
        firewall-cmd --state
        if [[ "$(firewall-cmd --state)" == "running" ]]; then
            log_info "FirewallD is active."
        else
            log_warn "FirewallD is inactive."
            touch "${WORK_DIR}/issue_inactive_firewall"
        fi
    elif command -v iptables &>/dev/null; then
        log_info "IPTables (basic check):"
        iptables -L -n -v
        log_warn "No user-friendly firewall (UFW/FirewallD) detected. Manual IPTables review needed."
    else
        log_warn "No common firewall utility (UFW, FirewallD, IPTables) found."
        touch "${WORK_DIR}/issue_no_firewall_tool"
    fi

    log_subsection "Open Ports (Top 10)"
    if command -v ss &>/dev/null; then
        log_info "Open Ports (ss):"
        ss -tuln | head -n 11
    elif command -v netstat &>/dev/null; then
        log_info "Open Ports (netstat):"
        netstat -tuln | head -n 11
    else
        log_warn "Neither 'ss' nor 'netstat' found. Cannot check open ports."
        touch "${WORK_DIR}/issue_no_net_tools"
    fi

    log_subsection "DNS Resolution"
    if command -v dig &>/dev/null; then
        if dig +short google.com @8.8.8.8 >/dev/null; then
            log_info "DNS resolution to google.com via 8.8.8.8 is working."
        else
            log_warn "DNS resolution to google.com via 8.8.8.8 failed."
            touch "${WORK_DIR}/issue_dns_failure"
        fi
    elif command -v nslookup &>/dev/null; then
        if nslookup google.com 8.8.8.8 >/dev/null; then
            log_info "DNS resolution to google.com via 8.8.8.8 is working."
        else
            log_warn "DNS resolution to google.com via 8.8.8.8 failed."
            touch "${WORK_DIR}/issue_dns_failure"
        fi
    else
        log_warn "Neither 'dig' nor 'nslookup' found. Cannot check DNS resolution."
        touch "${WORK_DIR}/issue_no_dns_tools"
    fi

    log_subsection "Network Interface Statistics"
    if command -v ip &>/dev/null; then
        log_info "Network Interface Stats (ip -s link):"
        ip -s link
    else
        log_warn "'ip' command not found. Cannot check network interface statistics."
        touch "${WORK_DIR}/issue_no_ip_tool"
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
    load_config_array "$config_file" "deductions" "failed_services:25,unclaimed_devices:10,orphans:5,missing_files:5,upgradable_pkgs:1,inactive_firewall:15,no_firewall_tool:5,no_net_tools:5,dns_failure:10,no_dns_tools:5,no_ip_tool:5,journal_errors:5,syslog_errors:5"
    for item in "${deductions[@]}"; do
        DEDUCTIONS_MAP["${item%%:*#}"]="${item##*:}"
    done
}

run_all_checks() {
    log_info "Running checks in parallel..."
    run_check "check_system_info" "${WORK_DIR}/01-system.log" "system_info" &
    run_check "check_hardware" "${WORK_DIR}/02-hardware.log" "hardware" &
    run_check "check_drivers" "${WORK_DIR}/03-drivers.log" "drivers" &
    run_check "check_packages_distro" "${WORK_DIR}/04-packages.log" "packages" &
    run_check "check_services_and_logs" "${WORK_DIR}/05-services.log" "services,logs" &
    run_check "check_network" "${WORK_DIR}/06-network.log" "network" &
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

        if [[ "$issue_name" == "upgradable_pkgs" ]]; then
            local count
            count=$(<"$issue_file")
            deduction=$((count * deduction))
            details+="$count Upgradable Pkgs (-$deduction) "
        else
            details+="$(tr '_' ' ' <<<"$issue_name" | sed 's/\b\(.\)/\u\1/g') (-$deduction) "
        fi
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
        grep '[[WARN]]||[[ERROR]]' "$final_log_colored" || log_info "No warnings or errors to display."
        cat "$score_report"
    else
        cat "$final_log_colored"
    fi

    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local report_base_name="${final_output_dir}/${distro_name}-health-check-${timestamp}"
    mv "$final_log_colored" "${report_base_name}.log"

    echo -e "\n${GREEN}✔ All done. Report saved to '${report_base_name}.log'${NC}"
}

# This is the main entry point to be called by distro-specific scripts.
# Arguments:
#   $1: The name of the distribution (e.g., "Ubuntu", "Arch")
#   $2: The package manager command for installing missing dependencies (e.g., "sudo apt install")
#   $@: The remaining arguments are the list of dependencies for the check.
run_health_check() {
    distro_name=$1
    local install_cmd=$2
    shift 2
    local distro_deps=($@)

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

    echo -e "${BLUE}=== Kicking off the $distro_name Health Check ===${NC}"

    local missing_pkgs
    missing_pkgs=$(check_dependencies "${distro_deps[@]}")

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
        log_info "You can do this by running: ${GREEN}${install_cmd} ${missing_pkgs}${NC}"
    fi
}
