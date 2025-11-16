#!/bin/bash
# lib/statistics.sh - Statistics and Analytics Module
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Generate comprehensive statistics
function generate_statistics() {
    local targets_dir="$1"
    local stats_file="${targets_dir}/../scan_statistics.json"
    
    log_info "[STATS] Generating scan statistics..."
    
    local total_targets=0
    local total_open_ports=0
    local total_services=0
    local total_vulns=0
    local total_creds_found=0
    local total_exploits_attempted=0
    
    # Collect statistics from each target
    local -A service_counts
    local -A port_counts
    
    for target_dir in "${targets_dir}"/*; do
        [ -d "$target_dir" ] || continue
        total_targets=$((total_targets + 1))
        
        local target
        target=$(basename "$target_dir")
        
        # Count open ports
        if [ -f "${target_dir}/nmap_${target}.nmap" ]; then
            local ports
            ports=$(grep -c "open" "${target_dir}/nmap_${target}.nmap" 2>/dev/null || echo "0")
            total_open_ports=$((total_open_ports + ports))
        fi
        
        # Count services
        if [ -f "${target_dir}/services.txt" ]; then
            local services
            services=$(wc -l < "${target_dir}/services.txt" 2>/dev/null || echo "0")
            total_services=$((total_services + services))
            
            # Track service types
            while IFS= read -r service; do
                service_counts[$service]=$((${service_counts[$service]:-0} + 1))
            done < "${target_dir}/services.txt"
        fi
        
        # Count vulnerabilities
        if grep -rq "vulnerable\|exploit\|backdoor" "$target_dir" 2>/dev/null; then
            total_vulns=$((total_vulns + 1))
        fi
        
        # Count found credentials
        if [ -d "${target_dir}/hydra" ]; then
            if grep -rq "login:" "${target_dir}/hydra" 2>/dev/null; then
                total_creds_found=$((total_creds_found + 1))
            fi
        fi
        
        # Count exploit attempts
        if [ -d "${target_dir}/metasploit" ]; then
            local exploits
            exploits=$(find "${target_dir}/metasploit" -name "*.rc" -type f | wc -l)
            total_exploits_attempted=$((total_exploits_attempted + exploits))
        fi
    done
    
    # Generate JSON statistics
    {
        echo "{"
        echo "  \"scan_date\": \"$(date '+%Y-%m-%d %H:%M:%S')\","
        echo "  \"summary\": {"
        echo "    \"total_targets\": $total_targets,"
        echo "    \"total_open_ports\": $total_open_ports,"
        echo "    \"total_services\": $total_services,"
        echo "    \"total_vulnerabilities\": $total_vulns,"
        echo "    \"credentials_found\": $total_creds_found,"
        echo "    \"exploits_attempted\": $total_exploits_attempted"
        echo "  },"
        echo "  \"service_distribution\": {"
        
        local first=true
        for service in "${!service_counts[@]}"; do
            [ "$first" = false ] && echo ","
            echo -n "    \"$service\": ${service_counts[$service]}"
            first=false
        done
        echo ""
        echo "  },"
        echo "  \"targets\": ["
        
        first=true
        for target_dir in "${targets_dir}"/*; do
            [ -d "$target_dir" ] || continue
            [ "$first" = false ] && echo ","
            
            local target
            target=$(basename "$target_dir")
            echo "    {"
            echo "      \"ip\": \"$target\","
            echo "      \"open_ports\": $(grep -c "open" "${target_dir}/nmap_${target}.nmap" 2>/dev/null || echo "0"),"
            echo "      \"services\": $(wc -l < "${target_dir}/services.txt" 2>/dev/null || echo "0"),"
            echo "      \"has_vulns\": $(grep -rq "vulnerable\|exploit\|backdoor" "$target_dir" 2>/dev/null && echo "true" || echo "false"),"
            echo "      \"has_creds\": $([ -d "${target_dir}/hydra" ] && grep -rq "login:" "${target_dir}/hydra" 2>/dev/null && echo "true" || echo "false")"
            echo -n "    }"
            first=false
        done
        echo ""
        echo "  ]"
        echo "}"
    } > "$stats_file"
    
    log_success "[STATS] Statistics saved: $stats_file"
    
    # Display summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 SCAN STATISTICS SUMMARY"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Targets Scanned:     $total_targets"
    echo "  Total Open Ports:    $total_open_ports"
    echo "  Services Detected:   $total_services"
    echo "  Vulnerabilities:     $total_vulns"
    echo "  Credentials Found:   $total_creds_found"
    echo "  Exploits Attempted:  $total_exploits_attempted"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Generate risk assessment
function generate_risk_assessment() {
    local targets_dir="$1"
    local output_file="${targets_dir}/../risk_assessment.txt"
    
    log_info "[STATS] Generating risk assessment..."
    
    {
        echo "=========================================="
        echo "RISK ASSESSMENT REPORT"
        echo "=========================================="
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        # High risk indicators
        echo "🔴 HIGH RISK INDICATORS:"
        echo ""
        local high_risk_found=false
        
        for target_dir in "${targets_dir}"/*; do
            [ -d "$target_dir" ] || continue
            local target
            target=$(basename "$target_dir")
            
            # Check for found credentials
            if [ -d "${target_dir}/hydra" ] && grep -rq "login:" "${target_dir}/hydra" 2>/dev/null; then
                echo "  ⚠️ $target: Weak/Default Credentials Found"
                high_risk_found=true
            fi
            
            # Check for successful exploits
            if [ -d "${target_dir}/metasploit" ]; then
                if grep -rq "session.*opened\|Command shell" "${target_dir}/metasploit" 2>/dev/null; then
                    echo "  ⚠️ $target: Successful Exploitation Detected"
                    high_risk_found=true
                fi
            fi
            
            # Check for known vulnerabilities
            if grep -riq "CVE-\|vulnerable\|backdoor" "$target_dir" 2>/dev/null; then
                echo "  ⚠️ $target: Known Vulnerabilities Present"
                high_risk_found=true
            fi
        done
        
        [ "$high_risk_found" = false ] && echo "  ✓ No critical issues detected"
        
        echo ""
        echo "🟡 MEDIUM RISK INDICATORS:"
        echo ""
        local medium_risk_found=false
        
        for target_dir in "${targets_dir}"/*; do
            [ -d "$target_dir" ] || continue
            local target
            target=$(basename "$target_dir")
            
            # Check for exposed admin interfaces
            if grep -riq "admin\|management\|webmin" "${target_dir}/nmap_${target}.nmap" 2>/dev/null; then
                echo "  ⚠️ $target: Administrative Interface Exposed"
                medium_risk_found=true
            fi
            
            # Check for unencrypted services
            if grep -q "telnet\|ftp" "${target_dir}/services.txt" 2>/dev/null; then
                echo "  ⚠️ $target: Unencrypted Services Detected"
                medium_risk_found=true
            fi
        done
        
        [ "$medium_risk_found" = false ] && echo "  ✓ No medium-risk issues detected"
        
        echo ""
        echo "RECOMMENDATIONS:"
        echo "  1. Address all HIGH risk issues immediately"
        echo "  2. Review and remediate MEDIUM risk issues"
        echo "  3. Implement network segmentation"
        echo "  4. Enable logging and monitoring"
        echo "  5. Regular security audits recommended"
        
    } > "$output_file"
    
    log_success "[STATS] Risk assessment saved: $output_file"
}

# Export functions
export -f generate_statistics generate_risk_assessment
