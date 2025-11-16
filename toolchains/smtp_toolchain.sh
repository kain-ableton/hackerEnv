#!/bin/bash
# toolchains/smtp_toolchain.sh - SMTP/Email Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="SMTP"
TOOLCHAIN_VERSION="2.0"

function smtp_toolchain_check_tools() {
    local tools=("nmap" "nc" "telnet" "smtp-user-enum")
    
    log_info "[$TOOLCHAIN_NAME] Checking available SMTP tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_debug "[$TOOLCHAIN_NAME] Missing: $tool"
        fi
    done
    
    return 0
}

function smtp_toolchain_banner_grab() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    log_info "[$TOOLCHAIN_NAME] Grabbing SMTP banner from $target:$port"
    
    local output_file="${output_dir}/smtp_banner_${target}.txt"
    
    {
        echo "=== SMTP Banner ==="
        echo "QUIT" | timeout 5 nc "$target" "$port" 2>&1 | head -10 || \
        echo "Could not connect"
    } > "$output_file"
    
    if [ -s "$output_file" ]; then
        log_success "[$TOOLCHAIN_NAME] Banner captured"
        grep -i "220\|smtp\|mail\|postfix\|exchange" "$output_file" | head -3 || true
    fi
    
    return 0
}

function smtp_toolchain_vrfy_test() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    log_info "[$TOOLCHAIN_NAME] Testing VRFY command on $target:$port"
    
    local output_file="${output_dir}/smtp_vrfy_${target}.txt"
    
    {
        echo "=== SMTP VRFY Test ==="
        echo "Testing common usernames..."
        echo ""
        
        for user in root admin administrator postmaster; do
            echo "VRFY $user" | timeout 5 nc "$target" "$port" 2>&1 | grep -E "^[0-9]{3}"
        done
    } > "$output_file"
    
    if grep -q "250\|252" "$output_file"; then
        log_warning "[$TOOLCHAIN_NAME] VRFY command enabled (information disclosure)"
        echo "INFO_DISCLOSURE: SMTP VRFY enabled" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] VRFY command disabled (secure)"
    fi
    
    return 0
}

function smtp_toolchain_open_relay() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    log_info "[$TOOLCHAIN_NAME] Testing for open relay on $target:$port"
    
    local output_file="${output_dir}/smtp_relay_${target}.txt"
    
    {
        echo "=== SMTP Open Relay Test ==="
        timeout 10 bash -c "
            (
                sleep 1; echo 'EHLO test.com'
                sleep 1; echo 'MAIL FROM:<test@test.com>'
                sleep 1; echo 'RCPT TO:<test@external.com>'
                sleep 1; echo 'QUIT'
            ) | nc $target $port
        " 2>&1
    } > "$output_file"
    
    if grep -q "250.*RCPT" "$output_file"; then
        log_warning "[$TOOLCHAIN_NAME] Possible open relay detected (CRITICAL!)"
        echo "CRITICAL: Potential open relay" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] Not an open relay (secure)"
    fi
    
    return 0
}

function smtp_toolchain_user_enum() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    if ! command -v smtp-user-enum &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] smtp-user-enum not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running user enumeration on $target:$port"
    
    local output_file="${output_dir}/smtp_user_enum_${target}.txt"
    local userlist="/usr/share/wordlists/metasploit/unix_users.txt"
    
    # Try common wordlist locations
    if [ ! -f "$userlist" ]; then
        userlist="/usr/share/seclists/Usernames/top-usernames-shortlist.txt"
    fi
    
    if [ ! -f "$userlist" ]; then
        log_warning "[$TOOLCHAIN_NAME] No username wordlist found"
        return 1
    fi
    
    if timeout 300 smtp-user-enum -M VRFY -U "$userlist" -t "$target" -p "$port" > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] User enumeration completed"
        
        local found
        found=$(grep -c "exists" "$output_file" 2>/dev/null || echo "0")
        if [ "$found" -gt 0 ]; then
            log_warning "[$TOOLCHAIN_NAME] Found $found valid users"
        fi
    else
        log_warning "[$TOOLCHAIN_NAME] User enumeration failed or timeout"
    fi
    
    return 0
}

function smtp_toolchain_nmap_scripts() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    if ! command -v nmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] nmap not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running nmap SMTP scripts on $target:$port"
    
    local output_file="${output_dir}/smtp_nmap_scripts_${target}.txt"
    
    if timeout 300 nmap --script "smtp-*" -p "$port" "$target" -oN "$output_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] Nmap SMTP scripts completed"
    else
        log_warning "[$TOOLCHAIN_NAME] Nmap SMTP scripts failed"
    fi
    
    return 0
}

function smtp_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-25}"
    
    log_info "[$TOOLCHAIN_NAME] Starting SMTP toolchain for $target:$port"
    
    local toolchain_dir="${output_dir}/smtp_toolchain"
    safe_create_dir "$toolchain_dir"
    
    smtp_toolchain_check_tools
    smtp_toolchain_banner_grab "$target" "$toolchain_dir" "$port"
    smtp_toolchain_vrfy_test "$target" "$toolchain_dir" "$port"
    smtp_toolchain_open_relay "$target" "$toolchain_dir" "$port"
    smtp_toolchain_user_enum "$target" "$toolchain_dir" "$port"
    smtp_toolchain_nmap_scripts "$target" "$toolchain_dir" "$port"
    
    local summary_file="${toolchain_dir}/smtp_toolchain_summary.txt"
    {
        echo "=================================="
        echo "SMTP Toolchain Summary"
        echo "=================================="
        echo "Target: $target:$port"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/smtp_banner_${target}.txt" ] && echo "  ✓ Banner grab"
        [ -f "${toolchain_dir}/smtp_vrfy_${target}.txt" ] && echo "  ✓ VRFY test"
        [ -f "${toolchain_dir}/smtp_relay_${target}.txt" ] && echo "  ✓ Open relay test"
        [ -f "${toolchain_dir}/smtp_user_enum_${target}.txt" ] && echo "  ✓ User enumeration"
        [ -f "${toolchain_dir}/smtp_nmap_scripts_${target}.txt" ] && echo "  ✓ Nmap scripts"
        echo ""
        echo "Key Findings:"
        if grep -q "open relay" "${toolchain_dir}/smtp_relay_${target}.txt" 2>/dev/null; then
            echo "  ⚠ CRITICAL: Potential open relay"
        fi
        if grep -q "VRFY enabled" "${toolchain_dir}/smtp_vrfy_${target}.txt" 2>/dev/null; then
            echo "  ⚠ VRFY command enabled (info disclosure)"
        fi
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] SMTP toolchain completed"
    
    return 0
}

export -f smtp_toolchain_check_tools smtp_toolchain_banner_grab smtp_toolchain_vrfy_test
export -f smtp_toolchain_open_relay smtp_toolchain_user_enum smtp_toolchain_nmap_scripts
export -f smtp_toolchain_run
