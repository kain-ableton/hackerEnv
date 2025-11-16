#!/bin/bash
# toolchains/ftp_toolchain.sh - FTP Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="FTP"
TOOLCHAIN_VERSION="2.0"

function ftp_toolchain_check_tools() {
    local tools=("ftp" "nmap")
    
    log_info "[$TOOLCHAIN_NAME] Checking available FTP tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_debug "[$TOOLCHAIN_NAME] Missing: $tool"
        fi
    done
    
    return 0
}

function ftp_toolchain_anonymous_check() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-21}"
    
    log_info "[$TOOLCHAIN_NAME] Testing anonymous FTP access on $target:$port"
    
    local output_file="${output_dir}/ftp_anonymous_${target}.txt"
    
    # Try anonymous login
    {
        echo "=== FTP Anonymous Access Test ==="
        echo "Target: $target:$port"
        echo "Date: $(date)"
        echo ""
        
        # Use expect-like approach with timeout
        timeout 10 ftp -n "$target" "$port" <<EOF 2>&1 || true
user anonymous anonymous@example.com
ls
bye
EOF
    } > "$output_file"
    
    if grep -qi "230\|logged in\|welcome" "$output_file"; then
        log_warning "[$TOOLCHAIN_NAME] Anonymous FTP access ALLOWED (security risk!)"
        echo "VULNERABILITY: Anonymous FTP access enabled" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] Anonymous FTP access denied (secure)"
    fi
    
    return 0
}

function ftp_toolchain_nmap_scripts() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-21}"
    
    if ! command -v nmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] nmap not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running nmap FTP scripts on $target:$port"
    
    local output_file="${output_dir}/ftp_nmap_scripts_${target}.txt"
    
    # Run FTP-specific nmap scripts
    if timeout 300 nmap --script "ftp-*" -p "$port" "$target" -oN "$output_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] Nmap FTP scripts completed"
        
        # Check for specific vulnerabilities
        if grep -qi "vulnerable\|vuln" "$output_file"; then
            log_warning "[$TOOLCHAIN_NAME] Potential vulnerabilities found!"
        fi
    else
        log_warning "[$TOOLCHAIN_NAME] Nmap FTP scripts failed or timeout"
    fi
    
    return 0
}

function ftp_toolchain_banner_grab() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-21}"
    
    log_info "[$TOOLCHAIN_NAME] Grabbing FTP banner from $target:$port"
    
    local output_file="${output_dir}/ftp_banner_${target}.txt"
    
    {
        echo "=== FTP Banner ==="
        timeout 5 nc -v "$target" "$port" 2>&1 | head -10 || \
        timeout 5 telnet "$target" "$port" 2>&1 | head -10 || \
        echo "Could not connect"
    } > "$output_file"
    
    if [ -s "$output_file" ]; then
        log_success "[$TOOLCHAIN_NAME] Banner captured"
        grep -i "220\|ftp\|version" "$output_file" | head -3 || true
    fi
    
    return 0
}

function ftp_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-21}"
    
    log_info "[$TOOLCHAIN_NAME] Starting FTP toolchain for $target:$port"
    
    local toolchain_dir="${output_dir}/ftp_toolchain"
    safe_create_dir "$toolchain_dir"
    
    ftp_toolchain_check_tools
    ftp_toolchain_banner_grab "$target" "$toolchain_dir" "$port"
    ftp_toolchain_anonymous_check "$target" "$toolchain_dir" "$port"
    ftp_toolchain_nmap_scripts "$target" "$toolchain_dir" "$port"
    
    local summary_file="${toolchain_dir}/ftp_toolchain_summary.txt"
    {
        echo "=================================="
        echo "FTP Toolchain Summary"
        echo "=================================="
        echo "Target: $target:$port"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/ftp_banner_${target}.txt" ] && echo "  ✓ Banner grab"
        [ -f "${toolchain_dir}/ftp_anonymous_${target}.txt" ] && echo "  ✓ Anonymous check"
        [ -f "${toolchain_dir}/ftp_nmap_scripts_${target}.txt" ] && echo "  ✓ Nmap scripts"
        echo ""
        echo "Key Findings:"
        if grep -q "Anonymous FTP access ALLOWED" "${toolchain_dir}/ftp_anonymous_${target}.txt" 2>/dev/null; then
            echo "  ⚠ Anonymous access enabled"
        fi
        if grep -qi "vulnerable\|vuln" "${toolchain_dir}/ftp_nmap_scripts_${target}.txt" 2>/dev/null; then
            echo "  ⚠ Potential vulnerabilities detected"
        fi
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] FTP toolchain completed"
    
    return 0
}

export -f ftp_toolchain_check_tools ftp_toolchain_anonymous_check
export -f ftp_toolchain_nmap_scripts ftp_toolchain_banner_grab ftp_toolchain_run
