#!/usr/bin/env bash
# ============================================================================
# Arch Linux Health Check
# ============================================================================

set -euo pipefail

SCRIPT_DIR_SELF=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR_SELF/../common/functions.sh"
source "$SCRIPT_DIR_SELF/common_checks.sh"

check_packages_distro() {
    exec >"$1" 2>&1
    log_section "PACKAGES (PACMAN)"
    if ! command -v pacman &>/dev/null; then
        log_warn "pacman not found, skipping package checks."
        return
    fi

    log_info "Checking for pending updates..."
    local upgradable_count
    upgradable_count=$(pacman -Qu | wc -l)
    if ((upgradable_count > 0)); then
        log_warn "$upgradable_count packages can be upgraded."
        log_info "Run 'sudo pacman -Syu' to update."
        echo "$upgradable_count" >"${WORK_DIR}/issue_upgradable_pkgs"
    else
        log_info "System is up-to-date."
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

main() {
    local arch_deps=("lscpu:util-linux" "hostnamectl:systemd" "lsb_release:lsb-release" "lspci:pciutils" "sensors:lm-sensors" "ufw:ufw" "firewall-cmd:firewalld" "ss:iproute2" "dig:dnsutils" "ip:iproute2" "iptables:iptables" "netstat:net-tools" "nslookup:bind")
    run_health_check "Arch" "sudo pacman -Syu" "${arch_deps[@]}" "$@"
}

main "$@"