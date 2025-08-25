#!/usr/bin/env bash
# ============================================================================
# Ubuntu/Debian Health Check
# ============================================================================

set -euo pipefail

SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR_SELF/../common/functions.sh"
source "$SCRIPT_DIR_SELF/common_checks.sh"

check_packages_distro() {
    exec >"$1" 2>&1
    log_section "PACKAGES (APT)"
    local upgradable_count
    upgradable_count=$(apt list --upgradable 2>/dev/null | grep -vc "Listing...")
    if ((upgradable_count > 0)); then
        log_warn "$upgradable_count packages can be upgraded."
        log_info "Run 'sudo apt update && sudo apt upgrade' to update."
        echo "$upgradable_count" >"${WORK_DIR}/issue_upgradable_pkgs"
    else
        log_info "System is up-to-date."
    fi

    if command -v deborphan &>/dev/null; then
        if orphans=$(deborphan); [[ -n "$orphans" ]]; then
            log_warn "Orphan packages found:"
            echo "$orphans"
            touch "${WORK_DIR}/issue_orphans"
        else
            log_info "No orphan packages found."
        fi
    else
        log_warn "deborphan not found. Orphan check skipped."
    fi

    if ! $opt_fast_mode; then
        if command -v debsums &>/dev/null; then
            if changed_files=$(debsums -c 2>/dev/null); [[ -n "$changed_files" ]]; then
                log_warn "Found changed config files (this can be normal):"
                echo "$changed_files"
                touch "${WORK_DIR}/issue_changed_configs"
            else
                log_info "No changed package files found."
            fi
        else
            log_warn "debsums not found. File integrity check skipped."
        fi
    fi
}

main() {
    local ubuntu_deps=("lscpu:util-linux" "hostnamectl:systemd" "lsb_release:lsb-release" "lspci:pciutils" "sensors:lm-sensors" "deborphan:deborphan" "debsums:debsums" "ufw:ufw" "firewall-cmd:firewalld" "ss:iproute2" "dig:dnsutils" "ip:iproute2" "iptables:iptables" "netstat:net-tools")
    run_health_check "Ubuntu" "sudo apt update && sudo apt install" "${ubuntu_deps[@]}" "$@"
}

main "$@"