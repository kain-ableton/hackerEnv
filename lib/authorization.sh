#!/bin/bash
# lib/authorization.sh - Authorization and audit logging
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

AUDIT_LOG="${AUDIT_LOG:-./logs/audit_$(date +%Y%m%d_%H%M%S).log}"
AUTH_FILE="${AUTH_FILE:-.authorized_targets}"

function init_authorization() {
    safe_create_dir "$(dirname "$AUDIT_LOG")"
    
    log_info "=== Authorization Check Started ==="
    log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    log_info "User: $(whoami)"
    log_info "Hostname: $(hostname)"
    log_info "Working Directory: $(pwd)"
    
    audit_log "SESSION_START" "HackerEnv session initiated"
}

function audit_log() {
    local action="$1"
    local details="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user=$(whoami)
    
    echo "[$timestamp] [$user] [$action] $details" >> "$AUDIT_LOG"
}

function check_authorization_file() {
    if [ "${CONFIG_REQUIRE_AUTH_FILE:-true}" = "true" ]; then
        if [ ! -f "$AUTH_FILE" ]; then
            log_error "Authorization file not found: $AUTH_FILE"
            log_error "Create this file with authorized target IPs/networks (one per line)"
            log_error "Example:"
            log_error "  192.168.1.0/24"
            log_error "  10.0.0.50"
            audit_log "AUTHORIZATION_FAILED" "Missing authorization file"
            return 1
        fi
        
        if [ ! -s "$AUTH_FILE" ]; then
            log_error "Authorization file is empty: $AUTH_FILE"
            audit_log "AUTHORIZATION_FAILED" "Empty authorization file"
            return 1
        fi
        
        log_success "Authorization file found: $AUTH_FILE"
        audit_log "AUTHORIZATION_CHECK" "Authorization file validated"
    fi
}

function is_target_authorized() {
    local target="$1"
    
    # If authorization not required, allow all
    if [ "${CONFIG_REQUIRE_AUTH_FILE:-true}" != "true" ]; then
        log_warning "Authorization checking is DISABLED - USE WITH CAUTION"
        audit_log "AUTHORIZATION_BYPASS" "Target $target - authorization check disabled"
        return 0
    fi
    
    # Check if target is in authorized list
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ || -z $line ]] && continue
        
        line=$(echo "$line" | tr -d ' \t')
        
        # Check exact IP match
        if [ "$target" = "$line" ]; then
            log_success "Target $target is authorized (exact match)"
            audit_log "AUTHORIZATION_SUCCESS" "Target $target authorized"
            return 0
        fi
        
        # Check CIDR match
        if [[ $line =~ / ]]; then
            if ip_in_cidr "$target" "$line"; then
                log_success "Target $target is authorized (CIDR match: $line)"
                audit_log "AUTHORIZATION_SUCCESS" "Target $target authorized via CIDR $line"
                return 0
            fi
        fi
    done < "$AUTH_FILE"
    
    log_error "Target $target is NOT authorized"
    audit_log "AUTHORIZATION_DENIED" "Unauthorized target attempted: $target"
    return 1
}

function ip_in_cidr() {
    local ip="$1"
    local cidr="$2"
    
    # Use ipcalc if available
    if command -v ipcalc &> /dev/null; then
        ipcalc -c "$ip" "$cidr" &>/dev/null
        return $?
    fi
    
    # Simple check using nmap if available
    if command -v nmap &> /dev/null; then
        local result=$(nmap -sL -n "$cidr" 2>/dev/null | grep "$ip")
        [ -n "$result" ]
        return $?
    fi
    
    log_warning "Cannot verify CIDR membership - install ipcalc or nmap"
    return 1
}

function require_user_confirmation() {
    local target="$1"
    
    log_warning "You are about to scan/attack: ${BOLD}${target}${RESET}"
    log_warning "Ensure you have WRITTEN AUTHORIZATION to test this target"
    
    read -p "Type 'YES I AM AUTHORIZED' to continue: " confirmation
    
    if [ "$confirmation" = "YES I AM AUTHORIZED" ]; then
        audit_log "USER_CONFIRMATION" "User confirmed authorization for $target"
        return 0
    else
        log_error "Authorization not confirmed"
        audit_log "USER_DENIAL" "User did not confirm authorization for $target"
        return 1
    fi
}

function log_scan_start() {
    local target="$1"
    audit_log "SCAN_START" "Target: $target"
}

function log_scan_end() {
    local target="$1"
    local status="$2"
    audit_log "SCAN_END" "Target: $target Status: $status"
}

function log_exploit_attempt() {
    local target="$1"
    local exploit="$2"
    audit_log "EXPLOIT_ATTEMPT" "Target: $target Exploit: $exploit"
}

function log_exploit_result() {
    local target="$1"
    local exploit="$2"
    local result="$3"
    audit_log "EXPLOIT_RESULT" "Target: $target Exploit: $exploit Result: $result"
}

function log_credentials_found() {
    local target="$1"
    local service="$2"
    local username="$3"
    
    # Don't log password in audit log for security
    audit_log "CREDENTIALS_FOUND" "Target: $target Service: $service User: $username"
}

function generate_authorization_report() {
    local output_file="./reports/authorization_report_$(date +%Y%m%d_%H%M%S).txt"
    safe_create_dir "$(dirname "$output_file")"
    
    {
        echo "=================================="
        echo "HackerEnv Authorization Report"
        echo "=================================="
        echo ""
        echo "Generated: $(date)"
        echo "User: $(whoami)"
        echo "Audit Log: $AUDIT_LOG"
        echo ""
        echo "Authorized Targets:"
        if [ -f "$AUTH_FILE" ]; then
            cat "$AUTH_FILE"
        else
            echo "  [No authorization file found]"
        fi
        echo ""
        echo "Recent Activity:"
        if [ -f "$AUDIT_LOG" ]; then
            tail -n 50 "$AUDIT_LOG"
        else
            echo "  [No audit log available]"
        fi
    } > "$output_file"
    
    log_info "Authorization report saved to: $output_file"
}

# Cleanup handler
function finalize_authorization() {
    audit_log "SESSION_END" "HackerEnv session completed"
    generate_authorization_report
}

trap finalize_authorization EXIT

export -f init_authorization audit_log check_authorization_file
export -f is_target_authorized require_user_confirmation
export -f log_scan_start log_scan_end log_exploit_attempt log_exploit_result
export -f log_credentials_found generate_authorization_report finalize_authorization
