#!/bin/bash
# lib/progress.sh - Progress tracking and estimation
# Version: 2.0.1

set -euo pipefail

# Progress tracking globals
SCAN_START_TIME=""
PROGRESS_CURRENT=0
PROGRESS_TOTAL=0
PROGRESS_STEP_NAME=""

# Initialize progress tracking
function progress_init() {
    local total_steps="${1:-10}"
    SCAN_START_TIME=$(date +%s)
    PROGRESS_CURRENT=0
    PROGRESS_TOTAL=$total_steps
    log_debug "[PROGRESS] Initialized with $total_steps steps"
}

# Update progress
function progress_update() {
    local step_name="$1"
    local current="${2:-$((PROGRESS_CURRENT + 1))}"
    
    PROGRESS_CURRENT=$current
    PROGRESS_STEP_NAME="$step_name"
    
    local percent=$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))
    local elapsed=$(($(date +%s) - SCAN_START_TIME))
    local eta=0
    
    if [ $PROGRESS_CURRENT -gt 0 ]; then
        local time_per_step=$((elapsed / PROGRESS_CURRENT))
        local remaining_steps=$((PROGRESS_TOTAL - PROGRESS_CURRENT))
        eta=$((remaining_steps * time_per_step))
    fi
    
    # Show progress bar if verbose
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        local bar_width=40
        local filled=$((percent * bar_width / 100))
        local bar=""
        
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=filled; i<bar_width; i++)); do bar+="░"; done
        
        echo -ne "\r${CYAN}[${bar}]${RESET} ${percent}% - ${step_name} " >&2
        
        if [ $eta -gt 0 ]; then
            echo -ne "(ETA: $(format_time $eta))" >&2
        fi
    fi
    
    log_verbose "[PROGRESS] Step $PROGRESS_CURRENT/$PROGRESS_TOTAL: $step_name ($percent%)"
}

# Complete progress
function progress_complete() {
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        echo -ne "\r${GREEN}[████████████████████████████████████████]${RESET} 100% - Complete!   \n" >&2
    fi
    
    local total_time=$(($(date +%s) - SCAN_START_TIME))
    log_success "[PROGRESS] Completed in $(format_time $total_time)"
}

# Format time in human readable format
function format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m ${secs}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Estimate scan time
function estimate_scan_time() {
    local target_count="${1:-1}"
    local scan_mode="${2:-normal}"
    local enable_toolchains="${3:-true}"
    local enable_bruteforce="${4:-false}"
    
    local base_time=180  # 3 minutes base
    local time_estimate=$base_time
    
    # Adjust for scan mode
    case "$scan_mode" in
        quick)
            time_estimate=$((time_estimate / 2))
            ;;
        full)
            time_estimate=$((time_estimate * 4))
            ;;
        stealth)
            time_estimate=$((time_estimate * 3))
            ;;
        udp)
            time_estimate=$((time_estimate * 5))
            ;;
    esac
    
    # Adjust for toolchains
    if [ "$enable_toolchains" = "true" ]; then
        time_estimate=$((time_estimate + 300))  # +5 min
    fi
    
    # Adjust for brute force
    if [ "$enable_bruteforce" = "true" ]; then
        time_estimate=$((time_estimate + 600))  # +10 min
    fi
    
    # Multiply by target count
    time_estimate=$((time_estimate * target_count))
    
    echo $time_estimate
}

# Show scan estimation
function show_scan_estimate() {
    local target_count="${1:-1}"
    local scan_mode="${2:-normal}"
    local enable_toolchains="${3:-true}"
    local enable_bruteforce="${4:-false}"
    
    local estimate
    estimate=$(estimate_scan_time "$target_count" "$scan_mode" "$enable_toolchains" "$enable_bruteforce")
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  📊 SCAN ESTIMATION${RESET}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "  ${BOLD}Targets:${RESET}         $target_count"
    echo -e "  ${BOLD}Scan Mode:${RESET}       $scan_mode"
    echo -e "  ${BOLD}Toolchains:${RESET}      $([ "$enable_toolchains" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo -e "  ${BOLD}Brute Force:${RESET}     $([ "$enable_bruteforce" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo -e "  ${BOLD}Estimated Time:${RESET}  $(format_time $estimate)"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
    echo ""
}

# Export functions
export -f progress_init progress_update progress_complete
export -f format_time estimate_scan_time show_scan_estimate
