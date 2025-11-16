#!/bin/bash
# lib/timeout_wrapper.sh - Timeout wrapper with progress and hang prevention
# Version: 2.0.1

set -euo pipefail

# Enhanced timeout with progress monitoring
function timeout_with_progress() {
    local timeout_seconds="$1"
    local command_name="$2"
    shift 2
    local command=("$@")
    
    local pid_file="/tmp/timeout_wrapper_$$.pid"
    local progress_file="/tmp/timeout_wrapper_$$_progress.txt"
    local last_output_file="/tmp/timeout_wrapper_$$_output.txt"
    
    # Cleanup function
    function cleanup_timeout_wrapper() {
        rm -f "$pid_file" "$progress_file" "$last_output_file"
        if [ -n "${monitor_pid:-}" ] && kill -0 "$monitor_pid" 2>/dev/null; then
            kill -TERM "$monitor_pid" 2>/dev/null || true
        fi
    }
    trap cleanup_timeout_wrapper EXIT INT TERM
    
    # Start command in background
    "${command[@]}" &
    local cmd_pid=$!
    echo "$cmd_pid" > "$pid_file"
    
    # Monitor progress
    local elapsed=0
    local last_check=0
    local check_interval=5
    local hang_threshold=30
    local last_output_time=$elapsed
    
    log_verbose "[$command_name] Started (PID: $cmd_pid, timeout: ${timeout_seconds}s)"
    
    while kill -0 "$cmd_pid" 2>/dev/null; do
        if [ $elapsed -ge $timeout_seconds ]; then
            log_warning "[$command_name] Timeout reached (${timeout_seconds}s) - killing process"
            kill -TERM "$cmd_pid" 2>/dev/null || true
            sleep 1
            if kill -0 "$cmd_pid" 2>/dev/null; then
                kill -KILL "$cmd_pid" 2>/dev/null || true
            fi
            cleanup_timeout_wrapper
            return 124  # Standard timeout exit code
        fi
        
        # Progress indicator every 5 seconds
        if [ $((elapsed % check_interval)) -eq 0 ] && [ $elapsed -ne $last_check ]; then
            last_check=$elapsed
            local percent=$((elapsed * 100 / timeout_seconds))
            local remaining=$((timeout_seconds - elapsed))
            
            if [ "${VERBOSITY:-1}" -ge 2 ]; then
                echo -ne "\r${CYAN}[$command_name]${RESET} Running: ${elapsed}s / ${timeout_seconds}s (${percent}%) - ETA: ${remaining}s   " >&2
            elif [ "${VERBOSITY:-1}" -ge 1 ]; then
                if [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                    log_info "[$command_name] Still running... ${elapsed}s elapsed, ${remaining}s remaining"
                fi
            fi
            
            # Hang detection - check if process is actually doing work
            if [ $((elapsed - last_output_time)) -ge $hang_threshold ]; then
                # Check if process is in sleep/wait state (might be hung)
                if ps -p "$cmd_pid" -o state= 2>/dev/null | grep -qE '^[DZ]'; then
                    log_warning "[$command_name] Process appears hung (state: $(ps -p $cmd_pid -o state= 2>/dev/null || echo 'unknown')) - killing"
                    kill -TERM "$cmd_pid" 2>/dev/null || true
                    sleep 1
                    if kill -0 "$cmd_pid" 2>/dev/null; then
                        kill -KILL "$cmd_pid" 2>/dev/null || true
                    fi
                    cleanup_timeout_wrapper
                    return 125  # Custom hang detection exit code
                fi
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    # Wait for exit code
    wait "$cmd_pid" 2>/dev/null || true
    local exit_code=$?
    
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        echo -ne "\r${GREEN}[$command_name]${RESET} Completed in ${elapsed}s                                    \n" >&2
    fi
    
    cleanup_timeout_wrapper
    return $exit_code
}

# Run command with timeout and progress (simpler interface)
function run_with_timeout() {
    local timeout_seconds="$1"
    local command_name="$2"
    shift 2
    
    timeout_with_progress "$timeout_seconds" "$command_name" "$@"
}

# Monitor long-running command with progress updates
function monitor_command() {
    local pid="$1"
    local command_name="$2"
    local max_wait="${3:-300}"
    local update_interval="${4:-10}"
    
    local elapsed=0
    local last_update=0
    
    log_verbose "[$command_name] Monitoring PID: $pid (max: ${max_wait}s)"
    
    while kill -0 "$pid" 2>/dev/null; do
        if [ $elapsed -ge $max_wait ]; then
            log_warning "[$command_name] Max wait time exceeded (${max_wait}s)"
            return 124
        fi
        
        if [ $((elapsed - last_update)) -ge $update_interval ]; then
            last_update=$elapsed
            
            # Get process state
            local state
            state=$(ps -p "$pid" -o state= 2>/dev/null || echo "X")
            
            # Check for hung states
            if [[ "$state" == "D" ]]; then
                log_warning "[$command_name] Process in uninterruptible sleep (D) - might be hung"
            elif [[ "$state" == "Z" ]]; then
                log_error "[$command_name] Process is zombie (Z)"
                return 1
            fi
            
            # Show progress
            local percent=$((elapsed * 100 / max_wait))
            local remaining=$((max_wait - elapsed))
            
            if [ "${VERBOSITY:-1}" -ge 2 ]; then
                echo -ne "\r${CYAN}[$command_name]${RESET} Running: ${elapsed}s / ${max_wait}s (${percent}%) - State: $state   " >&2
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        echo -ne "\r${GREEN}[$command_name]${RESET} Completed in ${elapsed}s                                    \n" >&2
    fi
    
    # Get exit code
    wait "$pid" 2>/dev/null || true
    return $?
}

# Kill hung process with logging
function kill_hung_process() {
    local pid="$1"
    local process_name="${2:-process}"
    
    if ! kill -0 "$pid" 2>/dev/null; then
        log_debug "[$process_name] Process $pid already dead"
        return 0
    fi
    
    log_warning "[$process_name] Killing hung process (PID: $pid)"
    
    # Try TERM first
    kill -TERM "$pid" 2>/dev/null || true
    sleep 2
    
    # Check if still alive
    if kill -0 "$pid" 2>/dev/null; then
        log_warning "[$process_name] TERM failed, sending KILL"
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    # Verify death
    if kill -0 "$pid" 2>/dev/null; then
        log_error "[$process_name] Failed to kill process $pid"
        return 1
    fi
    
    log_success "[$process_name] Process killed successfully"
    return 0
}

# Check if command is hung (uninterruptible sleep or zombie)
function is_process_hung() {
    local pid="$1"
    
    if ! kill -0 "$pid" 2>/dev/null; then
        return 1  # Process doesn't exist
    fi
    
    local state
    state=$(ps -p "$pid" -o state= 2>/dev/null || echo "X")
    
    # D = uninterruptible sleep (usually I/O), Z = zombie
    if [[ "$state" =~ ^[DZ] ]]; then
        return 0  # Hung
    fi
    
    return 1  # Not hung
}

# Watch for process hang with auto-kill
function watch_for_hang() {
    local pid="$1"
    local command_name="$2"
    local hang_timeout="${3:-60}"  # Seconds in D state before killing
    
    local hang_start=0
    local in_hung_state=false
    
    while kill -0 "$pid" 2>/dev/null; do
        if is_process_hung "$pid"; then
            if [ "$in_hung_state" = "false" ]; then
                in_hung_state=true
                hang_start=$(date +%s)
                log_warning "[$command_name] Process appears hung (PID: $pid)"
            else
                local hang_duration=$(( $(date +%s) - hang_start ))
                if [ $hang_duration -ge $hang_timeout ]; then
                    log_error "[$command_name] Process hung for ${hang_duration}s - killing"
                    kill_hung_process "$pid" "$command_name"
                    return 125  # Hang detected exit code
                fi
            fi
        else
            if [ "$in_hung_state" = "true" ]; then
                log_info "[$command_name] Process recovered from hung state"
                in_hung_state=false
            fi
        fi
        
        sleep 2
    done
    
    return 0
}

# Export functions
export -f timeout_with_progress run_with_timeout monitor_command
export -f kill_hung_process is_process_hung watch_for_hang
