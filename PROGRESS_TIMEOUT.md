# Progress Indicators & Timeout Management

## Overview
HackerEnv v2.0.1 includes robust progress tracking and timeout management to prevent tool hangs and provide better user feedback.

## Features

### 1. Progress Indicators
- **Real-time Progress Bars** - Visual feedback during long-running operations
- **Time Estimation** - ETA for scan completion
- **Step Tracking** - Current operation and progress percentage
- **Elapsed Time** - Shows how long operations have been running

### 2. Timeout Management
- **Automatic Timeouts** - Prevents tools from hanging indefinitely
- **Graceful Termination** - TERM signal before KILL
- **Hang Detection** - Detects uninterruptible sleep states (D)
- **Zombie Prevention** - Automatically cleans up zombie processes

### 3. Enhanced Monitoring
- **Process State Tracking** - Monitors process health
- **Progress Updates** - Regular status updates (every 5-30s depending on verbosity)
- **Responsive to Interrupts** - Quick Ctrl+C handling
- **Auto-kill on Hang** - Kills processes stuck for >30s

## Usage

### Basic Timeout Wrapper
```bash
# Run command with 600-second timeout and progress
run_with_timeout 600 "Tool-Name" tool_command --args

# Examples:
run_with_timeout 600 "Hydra-SSH" hydra -L users.txt -P pass.txt ssh://target
run_with_timeout 300 "Nmap-Scan" nmap -sV -p- target
```

### Monitor Existing Process
```bash
# Start command in background
command &
pid=$!

# Monitor with progress (max_wait, update_interval)
monitor_command "$pid" "Process-Name" 300 10
```

### Hang Detection
```bash
# Watch process and auto-kill if hung
command &
pid=$!

# Will kill process if in D/Z state for >60s
watch_for_hang "$pid" "Process-Name" 60
```

### Check if Process is Hung
```bash
if is_process_hung "$pid"; then
    kill_hung_process "$pid" "Process-Name"
fi
```

## Verbosity Levels

### Level 0 (QUIET)
- No progress indicators
- Errors only

### Level 1 (NORMAL)
- Status updates every 30 seconds
- Success/error messages
- No progress bars

### Level 2 (VERBOSE)
- Live progress bars
- 5-second updates
- ETA calculations
- Process state monitoring

### Level 3 (DEBUG)
- All of level 2
- Debug messages
- Detailed process information

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 124  | Timeout reached |
| 125  | Hang detected |
| 130  | User interrupt (Ctrl+C) |

## Updated Modules

### Hydra Module
All brute force operations now use `run_with_timeout`:
- SSH brute force (600s timeout)
- FTP brute force (600s timeout)
- Telnet brute force (600s timeout)
- SMB brute force (600s timeout)
- MySQL brute force (600s timeout)

### SSH Module
- SSH brute force with progress (600s timeout)

### Metasploit Module
- Exploit execution with monitoring
- Live process state tracking
- Auto-kill on hang
- 300s default timeout

## Examples

### Example 1: SSH Brute Force with Progress
```bash
$ ./hackerEnv2 -t 192.168.1.100 -v 2 --brute-force

[Hydra-SSH] Running: 30s / 600s (5%) - ETA: 570s
[████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 5% - SSH brute force
```

### Example 2: Metasploit with Monitoring
```bash
$ ./hackerEnv2 -t 192.168.1.100 --toolchains -v 2

[MSF-ssh_login] Running: 60s / 300s (20%) - State: S
[████████████████░░░░░░░░░░░░░░░░░░░░] 20% - Running Metasploit
```

### Example 3: Hang Detection
```bash
[WARNING] [Hydra-FTP] Process appears hung (state: D) - killing
[SUCCESS] [Hydra-FTP] Process killed successfully
```

## Configuration

### Timeout Settings (config/settings.conf)
```ini
[general]
timeout=300              # Default timeout in seconds

[scanning]
scan_delay=5            # Delay between operations

[bruteforce]
delay_between_attempts=1  # Delay between brute force attempts
```

### Environment Variables
```bash
export VERBOSITY=2      # Enable progress bars
export LOG_FILE=/path/to/log.txt  # Log file location
```

## Benefits

### 1. **No More Hangs**
- Tools automatically killed if hung
- Maximum wait times enforced
- Uninterruptible sleep detection

### 2. **Better UX**
- Visual progress feedback
- Time remaining estimates
- Clear status messages

### 3. **Improved Reliability**
- Consistent timeout handling
- Graceful process termination
- Clean resource cleanup

### 4. **Resource Management**
- Automatic zombie cleanup
- Process group termination
- Memory leak prevention

## Technical Details

### Timeout Wrapper Implementation
```bash
# Monitors command with timeout
timeout_with_progress() {
    - Starts command in background
    - Monitors every 1 second
    - Shows progress every 5 seconds
    - Detects hung states (D/Z)
    - Kills with TERM then KILL
    - Returns proper exit codes
}
```

### Hang Detection Algorithm
```bash
# Checks process state
1. Get process state (ps -p $pid -o state=)
2. If state is D (uninterruptible) or Z (zombie)
3. Track how long in that state
4. If > threshold (default 30s), kill process
5. Try TERM, wait 2s, then KILL if needed
```

### Process Monitoring
```bash
# Regular health checks
- CPU usage
- Memory usage  
- Process state (R/S/D/Z/T)
- Elapsed time
- Progress percentage
```

## Troubleshooting

### Issue: No Progress Bars Showing
**Solution:** Increase verbosity level
```bash
./hackerEnv2 -t target -v 2
# or
export VERBOSITY=2
```

### Issue: Timeouts Too Short
**Solution:** Adjust timeout in config or use custom values
```bash
# In code
run_with_timeout 1200 "Tool" command  # 20 minutes
```

### Issue: Process Killed Too Early
**Solution:** Check hang detection threshold
```bash
# Increase hang timeout
watch_for_hang "$pid" "Process" 120  # 2 minutes
```

## Future Enhancements
- [ ] Network bandwidth monitoring
- [ ] Disk I/O tracking
- [ ] Multi-bar progress for parallel operations
- [ ] JSON progress output for APIs
- [ ] Configurable progress formats

## See Also
- `lib/progress.sh` - Progress tracking functions
- `lib/timeout_wrapper.sh` - Timeout wrapper implementation
- `lib/utils.sh` - Core utility functions
- `ADVANCED_FEATURES.md` - Other advanced features

---

**Version:** 2.0.1
**Last Updated:** 2025-11-16
**Author:** HackerEnv Team
