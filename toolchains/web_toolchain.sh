#!/bin/bash
# toolchains/web_toolchain.sh - Web Application Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="WEB"
TOOLCHAIN_VERSION="2.0"

function web_toolchain_check_tools() {
    local missing_tools=()
    local optional_tools=("whatweb" "nikto" "dirb" "gobuster" "wapiti" "sqlmap")
    
    log_info "[$TOOLCHAIN_NAME] Checking available web tools..."
    
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_warning "[$TOOLCHAIN_NAME] Missing: $tool"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warning "[$TOOLCHAIN_NAME] Some tools missing: ${missing_tools[*]}"
        log_info "[$TOOLCHAIN_NAME] Install with: sudo apt install ${missing_tools[*]}"
    fi
    
    return 0
}

function web_toolchain_whatweb() {
    local target="$1"
    local output_dir="$2"
    local protocol="${3:-http}"
    
    if ! command -v whatweb &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] whatweb not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running whatweb on ${protocol}://${target}"
    
    local output_file="${output_dir}/whatweb_${target}.txt"
    
    if whatweb -a 3 --color=never "${protocol}://${target}" > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] whatweb completed"
        
        # Extract interesting findings
        grep -i "cms\|framework\|server\|version" "$output_file" | head -10 || true
    else
        log_warning "[$TOOLCHAIN_NAME] whatweb encountered errors"
    fi
    
    return 0
}

function web_toolchain_nikto() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-80}"
    
    if ! command -v nikto &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] nikto not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running nikto web scanner on ${target}:${port}"
    
    local output_file="${output_dir}/nikto_${target}_${port}.txt"
    
    # Run with timeout to prevent hangs
    if timeout 300 nikto -h "$target" -p "$port" -Format txt -output "$output_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] nikto completed"
    else
        log_warning "[$TOOLCHAIN_NAME] nikto timeout or error"
    fi
    
    return 0
}

function web_toolchain_dirb() {
    local target="$1"
    local output_dir="$2"
    local protocol="${3:-http}"
    
    if ! command -v dirb &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] dirb not available, trying gobuster"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running dirb directory bruteforce on ${protocol}://${target}"
    
    local output_file="${output_dir}/dirb_${target}.txt"
    local wordlist="/usr/share/wordlists/dirb/common.txt"
    
    if [ ! -f "$wordlist" ]; then
        log_warning "[$TOOLCHAIN_NAME] dirb wordlist not found"
        return 1
    fi
    
    # Run with timeout
    if timeout 600 dirb "${protocol}://${target}/" "$wordlist" -o "$output_file" -r -S 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] dirb completed"
        
        # Show found directories
        grep -E "==> DIRECTORY:|CODE:" "$output_file" | head -20 || true
    else
        log_warning "[$TOOLCHAIN_NAME] dirb timeout or error"
    fi
    
    return 0
}

function web_toolchain_gobuster() {
    local target="$1"
    local output_dir="$2"
    local protocol="${3:-http}"
    
    if ! command -v gobuster &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] gobuster not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running gobuster directory bruteforce on ${protocol}://${target}"
    
    local output_file="${output_dir}/gobuster_${target}.txt"
    local wordlist="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
    
    # Try common wordlist locations
    if [ ! -f "$wordlist" ]; then
        wordlist="/usr/share/seclists/Discovery/Web-Content/common.txt"
    fi
    
    if [ ! -f "$wordlist" ]; then
        log_warning "[$TOOLCHAIN_NAME] No wordlist found for gobuster"
        return 1
    fi
    
    # Run gobuster
    if timeout 600 gobuster dir -u "${protocol}://${target}/" -w "$wordlist" -o "$output_file" -q -e 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] gobuster completed"
    else
        log_warning "[$TOOLCHAIN_NAME] gobuster timeout or error"
    fi
    
    return 0
}

function web_toolchain_sqlmap_test() {
    local target="$1"
    local output_dir="$2"
    local protocol="${3:-http}"
    
    if ! command -v sqlmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] sqlmap not available"
        return 1
    fi
    
    # Only run if explicitly enabled
    if [ "${CONFIG_SQLMAP_ENABLED:-false}" != "true" ]; then
        log_debug "[$TOOLCHAIN_NAME] sqlmap testing disabled (use --enable-sqlmap)"
        return 0
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running sqlmap basic test on ${protocol}://${target}"
    
    local output_dir_sqlmap="${output_dir}/sqlmap"
    mkdir -p "$output_dir_sqlmap"
    
    # Basic crawl and test
    if timeout 300 sqlmap -u "${protocol}://${target}/" --batch --crawl=2 --random-agent --output-dir="$output_dir_sqlmap" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] sqlmap test completed"
    else
        log_warning "[$TOOLCHAIN_NAME] sqlmap timeout or error"
    fi
    
    return 0
}

function web_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-80}"
    local protocol="${4:-http}"
    
    log_info "[$TOOLCHAIN_NAME] Starting web toolchain for ${protocol}://${target}:${port}"
    
    # Create toolchain output directory
    local toolchain_dir="${output_dir}/web_toolchain"
    safe_create_dir "$toolchain_dir"
    
    # Check available tools
    web_toolchain_check_tools
    
    # Run technology detection
    web_toolchain_whatweb "$target" "$toolchain_dir" "$protocol"
    
    # Run vulnerability scanner
    web_toolchain_nikto "$target" "$toolchain_dir" "$port"
    
    # Run directory enumeration (try dirb first, then gobuster)
    if ! web_toolchain_dirb "$target" "$toolchain_dir" "$protocol"; then
        web_toolchain_gobuster "$target" "$toolchain_dir" "$protocol"
    fi
    
    # Run SQL injection test (if enabled)
    web_toolchain_sqlmap_test "$target" "$toolchain_dir" "$protocol"
    
    # Generate summary
    local summary_file="${toolchain_dir}/web_toolchain_summary.txt"
    {
        echo "=================================="
        echo "Web Toolchain Summary"
        echo "=================================="
        echo "Target: ${protocol}://${target}:${port}"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/whatweb_${target}.txt" ] && echo "  ✓ whatweb"
        [ -f "${toolchain_dir}/nikto_${target}_${port}.txt" ] && echo "  ✓ nikto"
        [ -f "${toolchain_dir}/dirb_${target}.txt" ] && echo "  ✓ dirb"
        [ -f "${toolchain_dir}/gobuster_${target}.txt" ] && echo "  ✓ gobuster"
        [ -d "${toolchain_dir}/sqlmap" ] && echo "  ✓ sqlmap"
        echo ""
        echo "Results saved in: $toolchain_dir"
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] Web toolchain completed for $target"
    log_info "[$TOOLCHAIN_NAME] Summary saved: $summary_file"
    
    return 0
}

export -f web_toolchain_check_tools web_toolchain_whatweb web_toolchain_nikto
export -f web_toolchain_dirb web_toolchain_gobuster web_toolchain_sqlmap_test web_toolchain_run
