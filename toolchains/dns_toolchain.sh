#!/bin/bash
# toolchains/dns_toolchain.sh - DNS Reconnaissance Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="DNS"
TOOLCHAIN_VERSION="2.0"

function dns_toolchain_check_tools() {
    local tools=("dig" "host" "nslookup" "dnsrecon" "dnsenum" "fierce")
    
    log_info "[$TOOLCHAIN_NAME] Checking available DNS tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_debug "[$TOOLCHAIN_NAME] Missing: $tool"
        fi
    done
    
    return 0
}

function dns_toolchain_zone_transfer() {
    local target="$1"
    local output_dir="$2"
    
    if ! command -v dig &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] dig not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Attempting zone transfer on $target"
    
    local output_file="${output_dir}/dns_zone_transfer_${target}.txt"
    
    # Try zone transfer
    if dig axfr "@$target" > "$output_file" 2>&1; then
        if grep -q "Transfer failed" "$output_file"; then
            log_info "[$TOOLCHAIN_NAME] Zone transfer not allowed (secure)"
        else
            log_warning "[$TOOLCHAIN_NAME] Zone transfer successful! (security issue)"
        fi
    fi
    
    return 0
}

function dns_toolchain_enum() {
    local target="$1"
    local output_dir="$2"
    
    log_info "[$TOOLCHAIN_NAME] Running DNS enumeration on $target"
    
    local output_file="${output_dir}/dns_enum_${target}.txt"
    
    # Basic DNS queries
    {
        echo "=== A Records ==="
        dig +short "$target" A 2>/dev/null || true
        echo ""
        echo "=== MX Records ==="
        dig +short "$target" MX 2>/dev/null || true
        echo ""
        echo "=== NS Records ==="
        dig +short "$target" NS 2>/dev/null || true
        echo ""
        echo "=== TXT Records ==="
        dig +short "$target" TXT 2>/dev/null || true
    } > "$output_file"
    
    log_success "[$TOOLCHAIN_NAME] Basic DNS enumeration completed"
    
    return 0
}

function dns_toolchain_subdomain_enum() {
    local domain="$1"
    local output_dir="$2"
    
    if ! command -v dnsrecon &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] dnsrecon not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running subdomain enumeration on $domain"
    
    local output_file="${output_dir}/dns_subdomains_${domain}.txt"
    
    # Basic subdomain brute force
    if timeout 300 dnsrecon -d "$domain" -t brt > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] Subdomain enumeration completed"
    else
        log_warning "[$TOOLCHAIN_NAME] Subdomain enumeration timeout or error"
    fi
    
    return 0
}

function dns_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    
    log_info "[$TOOLCHAIN_NAME] Starting DNS toolchain for $target"
    
    local toolchain_dir="${output_dir}/dns_toolchain"
    safe_create_dir "$toolchain_dir"
    
    dns_toolchain_check_tools
    dns_toolchain_enum "$target" "$toolchain_dir"
    dns_toolchain_zone_transfer "$target" "$toolchain_dir"
    
    # If target looks like a domain, try subdomain enum
    if [[ "$target" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        dns_toolchain_subdomain_enum "$target" "$toolchain_dir"
    fi
    
    local summary_file="${toolchain_dir}/dns_toolchain_summary.txt"
    {
        echo "=================================="
        echo "DNS Toolchain Summary"
        echo "=================================="
        echo "Target: $target"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/dns_enum_${target}.txt" ] && echo "  ✓ DNS queries"
        [ -f "${toolchain_dir}/dns_zone_transfer_${target}.txt" ] && echo "  ✓ Zone transfer test"
        [ -f "${toolchain_dir}/dns_subdomains_${target}.txt" ] && echo "  ✓ Subdomain enum"
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] DNS toolchain completed"
    
    return 0
}

export -f dns_toolchain_check_tools dns_toolchain_zone_transfer
export -f dns_toolchain_enum dns_toolchain_subdomain_enum dns_toolchain_run
