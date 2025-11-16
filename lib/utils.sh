#!/bin/bash
# lib/utils.sh - Common utility functions for HackerEnv
# Version: 2.0

set -euo pipefail

# Get lib directory (don't override SCRIPT_DIR from parent)
if [ -z "${SCRIPT_DIR:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source timeout wrapper if available
if [ -f "$LIB_DIR/timeout_wrapper.sh" ]; then
    source "$LIB_DIR/timeout_wrapper.sh"
fi

# Color definitions
export RED='\e[1;91m'
export GREEN='\e[32m'
export BLUE='\e[1;34m'
export YELLOW='\e[1;33m'
export CYAN='\e[1;36m'
export MAGENTA='\e[1;35m'
export BOLD='\e[1m'
export RESET='\e[0m'

# Verbosity levels
# 0 = QUIET    (errors only)
# 1 = NORMAL   (errors, warnings, success)
# 2 = VERBOSE  (+ info messages)
# 3 = DEBUG    (+ debug messages)
export VERBOSITY="${VERBOSITY:-1}"

# Logging functions
LOG_FILE="${LOG_FILE:-./logs/hackerenv_$(date +%Y%m%d_%H%M%S).log}"
mkdir -p "$(dirname "$LOG_FILE")"

function log_msg() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

function log_info() {
    # Show only if VERBOSITY >= 2
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        echo -e "${BLUE}[INFO]${RESET} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE"
}

function log_success() {
    # Show only if VERBOSITY >= 1
    if [ "${VERBOSITY:-1}" -ge 1 ]; then
        echo -e "${GREEN}[SUCCESS]${RESET} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "$LOG_FILE"
}

function log_error() {
    # Always show errors
    echo -e "${RED}[ERROR]${RESET} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE"
}

function log_warning() {
    # Show only if VERBOSITY >= 1
    if [ "${VERBOSITY:-1}" -ge 1 ]; then
        echo -e "${YELLOW}[WARNING]${RESET} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*" >> "$LOG_FILE"
}

function log_debug() {
    # Show only if VERBOSITY >= 3
    if [ "${VERBOSITY:-1}" -ge 3 ]; then
        echo -e "${CYAN}[DEBUG]${RESET} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "$LOG_FILE"
}

function log_verbose() {
    # Show only if VERBOSITY >= 2
    if [ "${VERBOSITY:-1}" -ge 2 ]; then
        echo -e "${MAGENTA}[VERBOSE]${RESET} $*" >&2
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [VERBOSE] $*" >> "$LOG_FILE"
}

function set_verbosity() {
    local level="$1"
    case "$level" in
        0|quiet|QUIET)
            export VERBOSITY=0
            log_debug "Verbosity set to QUIET (0)"
            ;;
        1|normal|NORMAL)
            export VERBOSITY=1
            log_debug "Verbosity set to NORMAL (1)"
            ;;
        2|verbose|VERBOSE)
            export VERBOSITY=2
            log_debug "Verbosity set to VERBOSE (2)"
            ;;
        3|debug|DEBUG)
            export VERBOSITY=3
            log_debug "Verbosity set to DEBUG (3)"
            ;;
        *)
            log_error "Invalid verbosity level: $level (use 0-3 or quiet/normal/verbose/debug)"
            return 1
            ;;
    esac
}

# Input validation
function valid_ip() {
    local ip="$1"
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        [[ ${ADDR[0]} -le 255 && ${ADDR[1]} -le 255 && \
           ${ADDR[2]} -le 255 && ${ADDR[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function sanitize_ip() {
    local ip="$1"
    # Remove any non-IP characters
    ip="${ip//[^0-9.]/}"
    echo "$ip"
}

function valid_cidr() {
    local cidr="$1"
    if [[ $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip="${cidr%/*}"
        local mask="${cidr#*/}"
        if valid_ip "$ip" && [ "$mask" -ge 0 ] && [ "$mask" -le 32 ]; then
            return 0
        fi
    fi
    return 1
}

function sanitize_path() {
    local path="$1"
    # Remove potential command injection
    path="${path//;/}"
    path="${path//\$/}"
    path="${path//\`/}"
    path="${path//\(/}"
    path="${path//\)/}"
    echo "$path"
}

# File operations
function safe_create_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

function safe_remove() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path" 2>/dev/null || {
            log_warning "Failed to remove: $path"
            return 1
        }
    fi
}

# Process management
declare -A BACKGROUND_JOBS

function start_background_job() {
    local job_name="$1"
    local command="$2"
    
    log_debug "Starting background job: $job_name"
    eval "$command" &
    BACKGROUND_JOBS["$job_name"]=$!
    log_debug "Job $job_name started with PID: ${BACKGROUND_JOBS[$job_name]}"
}

function wait_for_job() {
    local job_name="$1"
    local timeout="${2:-300}"
    
    if [ -z "${BACKGROUND_JOBS[$job_name]:-}" ]; then
        log_error "Job not found: $job_name"
        return 1
    fi
    
    local pid="${BACKGROUND_JOBS[$job_name]}"
    log_debug "Waiting for job $job_name (PID: $pid) with timeout: ${timeout}s"
    
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            log_warning "Job $job_name timed out after ${timeout}s"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 0.5
            kill -KILL "$pid" 2>/dev/null || true
            return 1
        fi
        sleep 1
        ((elapsed++))
    done
    
    # Use wait with a timeout-like approach
    wait "$pid" 2>/dev/null || true
    local exit_code=$?
    unset "BACKGROUND_JOBS[$job_name]"
    
    if [ $exit_code -eq 0 ]; then
        log_success "Job $job_name completed successfully"
    else
        log_error "Job $job_name failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

function wait_for_all_jobs() {
    local timeout="${1:-300}"
    local failed=0
    
    for job_name in "${!BACKGROUND_JOBS[@]}"; do
        if ! wait_for_job "$job_name" "$timeout"; then
            ((failed++))
        fi
    done
    
    return $failed
}

function cleanup_jobs() {
    # Kill all background jobs immediately on interrupt
    for job_name in "${!BACKGROUND_JOBS[@]}"; do
        local pid="${BACKGROUND_JOBS[$job_name]}"
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Killing job: $job_name (PID: $pid)"
            # Kill process group to stop all children
            kill -TERM -"$pid" 2>/dev/null || true
            sleep 0.5
            # Force kill if still alive
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL -"$pid" 2>/dev/null || true
            fi
        fi
    done
    BACKGROUND_JOBS=()
}

# Configuration loading
function load_config() {
    local config_file="${1:-./config/settings.conf}"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^#.*$ || -z $key ]] && continue
        # Skip section headers
        [[ $key =~ ^\[.*\]$ ]] && continue
        
        # Export as environment variable
        key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
        # Trim leading/trailing whitespace but preserve internal spaces
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        export "CONFIG_${key}=${value}"
    done < "$config_file"
    
    log_debug "Configuration loaded from: $config_file"
}

# Cleanup handler with immediate exit on interrupt
function handle_interrupt() {
    echo "" >&2
    log_warning "Interrupt received - cleaning up..."
    cleanup_jobs
    exit 130
}

# Error handling
function error_exit() {
    log_error "$1"
    cleanup_jobs
    exit "${2:-1}"
}

# Set up signal handlers
trap handle_interrupt INT
trap cleanup_jobs EXIT TERM

# Export functions for use in other scripts
export -f log_msg log_info log_success log_error log_warning log_debug
export -f valid_ip sanitize_ip valid_cidr sanitize_path
export -f safe_create_dir safe_remove
export -f start_background_job wait_for_job wait_for_all_jobs cleanup_jobs
export -f load_config error_exit
