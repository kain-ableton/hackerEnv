#!/bin/bash
# toolchains/smb_toolchain.sh - SMB/CIFS Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="SMB"
TOOLCHAIN_VERSION="2.0"

function smb_toolchain_check_tools() {
    local tools=("smbclient" "enum4linux" "smbmap" "crackmapexec")
    local missing_tools=()
    
    log_info "[$TOOLCHAIN_NAME] Checking available SMB tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_warning "[$TOOLCHAIN_NAME] Missing: $tool"
            missing_tools+=("$tool")
        fi
    done
    
    return 0
}

function smb_toolchain_enum4linux() {
    local target="$1"
    local output_dir="$2"
    
    if ! command -v enum4linux &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] enum4linux not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running enum4linux on $target"
    
    local output_file="${output_dir}/enum4linux_${target}.txt"
    
    if timeout 300 enum4linux -a "$target" > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] enum4linux completed"
        
        # Extract key findings
        grep -E "Domain Name:|OS:|Shares:|Users:" "$output_file" | head -20 || true
    else
        log_warning "[$TOOLCHAIN_NAME] enum4linux timeout or error"
    fi
    
    return 0
}

function smb_toolchain_smbclient() {
    local target="$1"
    local output_dir="$2"
    
    if ! command -v smbclient &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] smbclient not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running smbclient share enumeration on $target"
    
    local output_file="${output_dir}/smbclient_${target}.txt"
    
    # List shares (null session)
    if smbclient -L "//$target" -N > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] smbclient completed"
        
        # Show found shares
        grep -E "Disk|IPC|Printer" "$output_file" || true
    else
        log_warning "[$TOOLCHAIN_NAME] smbclient access denied (normal for secured systems)"
    fi
    
    return 0
}

function smb_toolchain_smbmap() {
    local target="$1"
    local output_dir="$2"
    
    if ! command -v smbmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] smbmap not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running smbmap on $target"
    
    local output_file="${output_dir}/smbmap_${target}.txt"
    
    # Try null session first
    if smbmap -H "$target" > "$output_file" 2>&1; then
        log_success "[$TOOLCHAIN_NAME] smbmap completed"
    else
        log_warning "[$TOOLCHAIN_NAME] smbmap no access"
    fi
    
    # Try with guest
    if smbmap -H "$target" -u guest >> "$output_file" 2>&1; then
        log_info "[$TOOLCHAIN_NAME] Guest access available"
    fi
    
    return 0
}

function smb_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    
    log_info "[$TOOLCHAIN_NAME] Starting SMB toolchain for $target"
    
    local toolchain_dir="${output_dir}/smb_toolchain"
    safe_create_dir "$toolchain_dir"
    
    smb_toolchain_check_tools
    smb_toolchain_enum4linux "$target" "$toolchain_dir"
    smb_toolchain_smbclient "$target" "$toolchain_dir"
    smb_toolchain_smbmap "$target" "$toolchain_dir"
    
    local summary_file="${toolchain_dir}/smb_toolchain_summary.txt"
    {
        echo "=================================="
        echo "SMB Toolchain Summary"
        echo "=================================="
        echo "Target: $target"
        echo "Date: $(date)"
        echo ""
        echo "Tools Run:"
        [ -f "${toolchain_dir}/enum4linux_${target}.txt" ] && echo "  ✓ enum4linux"
        [ -f "${toolchain_dir}/smbclient_${target}.txt" ] && echo "  ✓ smbclient"
        [ -f "${toolchain_dir}/smbmap_${target}.txt" ] && echo "  ✓ smbmap"
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] SMB toolchain completed"
    
    return 0
}

export -f smb_toolchain_check_tools smb_toolchain_enum4linux
export -f smb_toolchain_smbclient smb_toolchain_smbmap smb_toolchain_run
