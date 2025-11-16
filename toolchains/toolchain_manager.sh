#!/bin/bash
# toolchains/toolchain_manager.sh - Toolchain Orchestration Manager
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load all available toolchains
function load_toolchains() {
    log_debug "Loading available toolchains..."
    
    for toolchain in "${TOOLCHAIN_DIR}"/*_toolchain.sh; do
        if [ -f "$toolchain" ]; then
            source "$toolchain"
            log_debug "Loaded: $(basename "$toolchain")"
        fi
    done
}

# Detect which toolchains to run based on services
function detect_toolchains() {
    local services_file="$1"
    local toolchains=()
    
    if [ ! -f "$services_file" ] || [ ! -s "$services_file" ]; then
        log_debug "No services file or empty, no toolchains to run"
        return 1
    fi
    
    log_info "Detecting applicable toolchains based on services..."
    
    while IFS= read -r service; do
        case "$service" in
            http|http-*|https|ssl|www)
                if ! [[ " ${toolchains[*]} " =~ " web " ]]; then
                    toolchains+=("web")
                    log_info "Detected HTTP/HTTPS - will run web toolchain"
                fi
                ;;
            smb|microsoft-ds|netbios-ssn)
                if ! [[ " ${toolchains[*]} " =~ " smb " ]]; then
                    toolchains+=("smb")
                    log_info "Detected SMB - will run SMB toolchain"
                fi
                ;;
            dns|domain)
                if ! [[ " ${toolchains[*]} " =~ " dns " ]]; then
                    toolchains+=("dns")
                    log_info "Detected DNS - will run DNS toolchain"
                fi
                ;;
            mysql|mariadb|postgresql)
                if ! [[ " ${toolchains[*]} " =~ " database " ]]; then
                    toolchains+=("database")
                    log_info "Detected Database - will run database toolchain"
                fi
                ;;
            ftp|ftp-*)
                if ! [[ " ${toolchains[*]} " =~ " ftp " ]]; then
                    toolchains+=("ftp")
                    log_info "Detected FTP - will run FTP toolchain"
                fi
                ;;
            smtp|smtp-*|submission)
                if ! [[ " ${toolchains[*]} " =~ " smtp " ]]; then
                    toolchains+=("smtp")
                    log_info "Detected SMTP - will run SMTP toolchain"
                fi
                ;;
            ssh|ssh-*)
                if ! [[ " ${toolchains[*]} " =~ " ssh " ]]; then
                    toolchains+=("ssh")
                    log_info "Detected SSH - will run SSH toolchain"
                fi
                ;;
        esac
    done < "$services_file"
    
    if [ ${#toolchains[@]} -eq 0 ]; then
        log_info "No applicable toolchains detected for services"
        return 1
    fi
    
    echo "${toolchains[@]}"
    return 0
}

# Run a specific toolchain
function run_toolchain() {
    local toolchain_name="$1"
    local target="$2"
    local output_dir="$3"
    shift 3
    local additional_args=("$@")
    
    log_info "Running ${toolchain_name} toolchain..."
    
    case "$toolchain_name" in
        web)
            if type web_toolchain_run &>/dev/null; then
                web_toolchain_run "$target" "$output_dir" "${additional_args[@]}"
            else
                log_error "Web toolchain not loaded"
                return 1
            fi
            ;;
        smb)
            if type smb_toolchain_run &>/dev/null; then
                smb_toolchain_run "$target" "$output_dir"
            else
                log_error "SMB toolchain not loaded"
                return 1
            fi
            ;;
        dns)
            if type dns_toolchain_run &>/dev/null; then
                dns_toolchain_run "$target" "$output_dir"
            else
                log_error "DNS toolchain not loaded"
                return 1
            fi
            ;;
        database)
            if type database_toolchain_run &>/dev/null; then
                database_toolchain_run "$target" "$output_dir"
            else
                log_error "Database toolchain not loaded"
                return 1
            fi
            ;;
        ftp)
            if type ftp_toolchain_run &>/dev/null; then
                ftp_toolchain_run "$target" "$output_dir"
            else
                log_error "FTP toolchain not loaded"
                return 1
            fi
            ;;
        smtp)
            if type smtp_toolchain_run &>/dev/null; then
                smtp_toolchain_run "$target" "$output_dir"
            else
                log_error "SMTP toolchain not loaded"
                return 1
            fi
            ;;
        ssh)
            if type ssh_toolchain_run &>/dev/null; then
                ssh_toolchain_run "$target" "$output_dir"
            else
                log_error "SSH toolchain not loaded"
                return 1
            fi
            ;;
        *)
            log_warning "Unknown toolchain: $toolchain_name"
            return 1
            ;;
    esac
    
    return 0
}

# Run all detected toolchains
function run_auto_toolchains() {
    local target="$1"
    local output_dir="$2"
    local services_file="${output_dir}/services.txt"
    
    # Detect applicable toolchains
    local toolchains
    if ! toolchains=$(detect_toolchains "$services_file"); then
        log_info "No toolchains applicable for $target"
        return 0
    fi
    
    # Convert to array for proper handling
    local -a toolchain_array=($toolchains)
    log_info "Running ${#toolchain_array[@]} toolchain(s) for $target"
    
    # Run each detected toolchain
    for toolchain in $toolchains; do
        run_toolchain "$toolchain" "$target" "$output_dir"
    done
    
    log_success "All toolchains completed for $target"
    
    return 0
}

# Run specific toolchains by name
function run_specified_toolchains() {
    local target="$1"
    local output_dir="$2"
    local toolchain_list="$3"
    
    IFS=',' read -ra toolchains <<< "$toolchain_list"
    
    log_info "Running ${#toolchains[@]} specified toolchain(s)"
    
    for toolchain in "${toolchains[@]}"; do
        toolchain=$(echo "$toolchain" | tr -d ' ')
        
        if [ "$toolchain" = "all" ]; then
            log_info "Running all available toolchains"
            run_toolchain "web" "$target" "$output_dir" 80 "http"
            run_toolchain "smb" "$target" "$output_dir"
            run_toolchain "dns" "$target" "$output_dir"
            run_toolchain "database" "$target" "$output_dir"
            run_toolchain "ftp" "$target" "$output_dir"
            run_toolchain "smtp" "$target" "$output_dir"
            run_toolchain "ssh" "$target" "$output_dir"
        else
            run_toolchain "$toolchain" "$target" "$output_dir"
        fi
    done
    
    return 0
}

# Generate combined toolchain report
function generate_toolchain_report() {
    local output_dir="$1"
    local report_file="${output_dir}/toolchain_report.txt"
    
    log_info "Generating combined toolchain report..."
    
    {
        echo "========================================"
        echo "HackerEnv Toolchain Execution Report"
        echo "========================================"
        echo "Date: $(date)"
        echo "Target Directory: $output_dir"
        echo ""
        
        # List all toolchain directories
        echo "=== Toolchains Executed ==="
        for toolchain_dir in "${output_dir}"/*_toolchain; do
            if [ -d "$toolchain_dir" ]; then
                local toolchain_name
                toolchain_name=$(basename "$toolchain_dir" | sed 's/_toolchain//')
                echo "  ✓ ${toolchain_name^^} Toolchain"
                
                # Include summary if exists
                local summary="${toolchain_dir}/${toolchain_name}_toolchain_summary.txt"
                if [ -f "$summary" ]; then
                    echo ""
                    cat "$summary"
                    echo ""
                fi
            fi
        done
        
        echo ""
        echo "=== Key Findings ==="
        
        # Search for interesting findings across all toolchains
        grep -rh -i "vulnerable\|exploit\|weak\|exposed\|misconfigured" "${output_dir}"/*_toolchain/ 2>/dev/null | head -20 || echo "  No critical findings in automated scans"
        
        echo ""
        echo "=== Next Steps ==="
        echo "1. Review individual toolchain outputs"
        echo "2. Investigate any findings manually"
        echo "3. Run additional targeted scans as needed"
        echo ""
        echo "Report saved: $report_file"
        
    } > "$report_file"
    
    log_success "Toolchain report generated: $report_file"
    
    return 0
}

# Initialize - load all toolchains
load_toolchains

export -f load_toolchains detect_toolchains run_toolchain
export -f run_auto_toolchains run_specified_toolchains generate_toolchain_report
