#!/bin/bash
# toolchains/ssh_toolchain.sh - SSH Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="SSH"
TOOLCHAIN_VERSION="2.0"

function ssh_toolchain_check_tools() {
    local tools=("ssh" "ssh-keyscan" "nmap")
    
    log_info "[$TOOLCHAIN_NAME] Checking available SSH tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_debug "[$TOOLCHAIN_NAME] Missing: $tool"
        fi
    done
    
    return 0
}

function ssh_toolchain_banner_grab() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    log_info "[$TOOLCHAIN_NAME] Grabbing SSH banner from $target:$port"
    
    local output_file="${output_dir}/ssh_banner_${target}.txt"
    
    {
        echo "=== SSH Banner ==="
        timeout 5 nc "$target" "$port" 2>&1 | head -5 || \
        timeout 5 ssh -V -p "$port" "$target" 2>&1 | head -5 || \
        echo "Could not connect"
    } > "$output_file"
    
    if [ -s "$output_file" ]; then
        log_success "[$TOOLCHAIN_NAME] Banner captured"
        cat "$output_file"
    fi
    
    return 0
}

function ssh_toolchain_key_scan() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    if ! command -v ssh-keyscan &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] ssh-keyscan not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Scanning SSH keys on $target:$port"
    
    local output_file="${output_dir}/ssh_keys_${target}.txt"
    
    {
        echo "=== SSH Host Keys ==="
        timeout 10 ssh-keyscan -p "$port" "$target" 2>&1
    } > "$output_file"
    
    if [ -s "$output_file" ]; then
        log_success "[$TOOLCHAIN_NAME] SSH keys captured"
        grep -E "ssh-rsa|ecdsa|ed25519" "$output_file" | head -5 || true
    fi
    
    return 0
}

function ssh_toolchain_auth_methods() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    log_info "[$TOOLCHAIN_NAME] Testing SSH authentication methods on $target:$port"
    
    local output_file="${output_dir}/ssh_auth_methods_${target}.txt"
    
    {
        echo "=== SSH Authentication Methods ==="
        # Try to get supported auth methods
        timeout 10 ssh -v -p "$port" -o PreferredAuthentications=none "$target" 2>&1 | \
            grep -i "authentication\|method" || echo "Could not determine"
    } > "$output_file"
    
    if grep -qi "password\|keyboard-interactive" "$output_file"; then
        log_info "[$TOOLCHAIN_NAME] Password authentication enabled"
    fi
    if grep -qi "publickey" "$output_file"; then
        log_info "[$TOOLCHAIN_NAME] Public key authentication enabled"
    fi
    
    return 0
}

function ssh_toolchain_algorithm_scan() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    log_info "[$TOOLCHAIN_NAME] Scanning supported algorithms on $target:$port"
    
    local output_file="${output_dir}/ssh_algorithms_${target}.txt"
    
    {
        echo "=== SSH Supported Algorithms ==="
        timeout 10 ssh -v -p "$port" -o "Ciphers=aes128-cbc" "$target" 2>&1 | \
            grep -E "kex|cipher|mac|compression" | head -20
    } > "$output_file"
    
    # Check for weak algorithms
    if grep -qi "cbc\|md5\|sha1\|arcfour" "$output_file"; then
        log_warning "[$TOOLCHAIN_NAME] Weak algorithms detected"
        echo "VULNERABILITY: SSH weak algorithms" >> "${output_dir}/vulnerabilities.txt"
    fi
    
    return 0
}

function ssh_toolchain_nmap_scripts() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    if ! command -v nmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] nmap not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running nmap SSH scripts on $target:$port"
    
    local output_file="${output_dir}/ssh_nmap_scripts_${target}.txt"
    
    if timeout 300 nmap --script "ssh-*" -p "$port" "$target" -oN "$output_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] Nmap SSH scripts completed"
        
        # Check for vulnerabilities
        if grep -qi "vulnerable\|vuln\|weak" "$output_file"; then
            log_warning "[$TOOLCHAIN_NAME] Potential vulnerabilities found"
        fi
    else
        log_warning "[$TOOLCHAIN_NAME] Nmap SSH scripts failed"
    fi
    
    return 0
}

function ssh_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-22}"
    
    log_info "[$TOOLCHAIN_NAME] Starting SSH toolchain for $target:$port"
    
    local toolchain_dir="${output_dir}/ssh_toolchain"
    safe_create_dir "$toolchain_dir"
    
    ssh_toolchain_check_tools
    ssh_toolchain_banner_grab "$target" "$toolchain_dir" "$port"
    ssh_toolchain_key_scan "$target" "$toolchain_dir" "$port"
    ssh_toolchain_auth_methods "$target" "$toolchain_dir" "$port"
    ssh_toolchain_algorithm_scan "$target" "$toolchain_dir" "$port"
    ssh_toolchain_nmap_scripts "$target" "$toolchain_dir" "$port"
    
    local summary_file="${toolchain_dir}/ssh_toolchain_summary.txt"
    {
        echo "=================================="
        echo "SSH Toolchain Summary"
        echo "=================================="
        echo "Target: $target:$port"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/ssh_banner_${target}.txt" ] && echo "  ✓ Banner grab"
        [ -f "${toolchain_dir}/ssh_keys_${target}.txt" ] && echo "  ✓ Key scan"
        [ -f "${toolchain_dir}/ssh_auth_methods_${target}.txt" ] && echo "  ✓ Auth methods"
        [ -f "${toolchain_dir}/ssh_algorithms_${target}.txt" ] && echo "  ✓ Algorithm scan"
        [ -f "${toolchain_dir}/ssh_nmap_scripts_${target}.txt" ] && echo "  ✓ Nmap scripts"
        echo ""
        echo "Key Findings:"
        if grep -q "weak algorithms" "${toolchain_dir}/ssh_algorithms_${target}.txt" 2>/dev/null; then
            echo "  ⚠ Weak encryption algorithms detected"
        fi
        if grep -qi "vulnerable" "${toolchain_dir}/ssh_nmap_scripts_${target}.txt" 2>/dev/null; then
            echo "  ⚠ Potential vulnerabilities detected"
        fi
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] SSH toolchain completed"
    
    return 0
}

export -f ssh_toolchain_check_tools ssh_toolchain_banner_grab ssh_toolchain_key_scan
export -f ssh_toolchain_auth_methods ssh_toolchain_algorithm_scan ssh_toolchain_nmap_scripts
export -f ssh_toolchain_run
