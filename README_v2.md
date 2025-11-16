# HackerEnv v2.0 - Refactored Edition

## What Changed?

This is a **complete refactoring** of the original hackerEnv tool with focus on:
- ✅ **Security**: Authorization checking, input validation, audit logging
- ✅ **Reliability**: Proper error handling, job management, timeout controls  
- ✅ **Maintainability**: Modular architecture, 80% code reduction in main script
- ✅ **Best Practices**: Configuration files, testing framework, clean code

---

## Directory Structure

```
hackerEnv/
├── hackerEnv2           # New main script (9KB vs 106KB original)
├── hackerEnv            # Original script (kept for reference)
├── config/
│   └── settings.conf    # Centralized configuration
├── lib/
│   ├── utils.sh         # Common utilities (logging, validation)
│   └── authorization.sh # Authorization & audit logging
├── core/
│   └── scanner.sh       # Scanning engine
├── modules/
│   └── ssh.sh          # SSH module (FTP, SMB, etc. can be added)
├── tests/
│   └── run_tests.sh    # Test suite
├── logs/               # Activity & audit logs
├── reports/            # Scan reports
├── targets/            # Per-target results
└── .authorized_targets # Authorized IPs/networks
```

---

## Key Improvements

### 1. **Security Enhancements**
- ✅ **Authorization File**: Require explicit target approval
- ✅ **Audit Logging**: All actions logged with timestamps
- ✅ **Input Sanitization**: Prevents command injection
- ✅ **User Confirmation**: Optional manual authorization step
- ✅ **Credential Protection**: No plaintext passwords in logs

### 2. **Code Quality**
- ✅ **Modular Design**: 7 separate files vs 1 monolithic script
- ✅ **Error Handling**: `set -euo pipefail` + proper error trapping
- ✅ **Job Management**: Replace `sleep` with proper process control
- ✅ **No Code Duplication**: DRY principle applied throughout

### 3. **Reliability**
- ✅ **Timeout Controls**: All scans have configurable timeouts
- ✅ **Dependency Checking**: Verify tools before execution
- ✅ **Graceful Degradation**: Continue on non-fatal errors
- ✅ **State Management**: Better handling of incomplete scans

### 4. **Usability**
- ✅ **Configuration File**: Customize without editing code
- ✅ **Better Logging**: Structured logs with levels (INFO/WARN/ERROR)
- ✅ **Help System**: Comprehensive --help documentation
- ✅ **Progress Indicators**: Know what's happening

---

## Quick Start

### 1. Setup
```bash
cd /opt/hackerEnv

# Edit authorized targets (REQUIRED)
nano .authorized_targets

# Add your authorized IPs/networks:
# 192.168.1.0/24
# 10.0.0.50

# Review configuration
nano config/settings.conf
```

### 2. Basic Usage
```bash
# Scan a single target
./hackerEnv2 -t 192.168.1.100

# Scan a network
./hackerEnv2 -t 192.168.1.0/24

# Aggressive mode
./hackerEnv2 -t 192.168.1.100 --aggressive

# With bruteforce (use responsibly)
./hackerEnv2 -t 192.168.1.100 --bruteforce
```

### 3. Check Results
```bash
# View scan results
ls -la targets/192.168.1.100/

# Read logs
tail -f logs/hackerenv_*.log

# Audit trail
cat logs/audit_*.log
```

---

## Configuration Options

Edit `config/settings.conf`:

```ini
[general]
log_level=INFO          # DEBUG, INFO, WARNING, ERROR
max_threads=10          # Parallel operations
timeout=300            # Default timeout (seconds)

[scanning]
aggressive_mode=false   # -p- scan all ports
scan_delay=5           # Delay between scans
nmap_options=-sV -T4 -A -O

[bruteforce]
enabled=false          # Enable password attacks
max_attempts=1000      # Limit attempts
wordlist=/usr/share/wordlists/rockyou.txt

[authorization]
require_auth_file=true  # Enforce authorization checking
log_all_activity=true   # Audit logging
```

---

## Testing

```bash
# Run test suite
./tests/run_tests.sh

# Expected output:
# ✓ Valid IP: 192.168.1.1
# ✓ Sanitize IP with injection
# ✓ Config value loaded
# All tests passed!
```

---

## Comparison: v1 vs v2

| Feature | Original | v2.0 Refactored |
|---------|----------|-----------------|
| Lines of code | 1,811 | ~400 (main) |
| Files | 1 | 7 (modular) |
| Authorization | ❌ | ✅ Required |
| Audit logging | ❌ | ✅ Complete |
| Error handling | ⚠️ Minimal | ✅ Comprehensive |
| Tests | ❌ | ✅ Test suite |
| Configuration | ❌ Hardcoded | ✅ Config file |
| Input validation | ⚠️ Basic | ✅ Sanitized |
| Job management | ⚠️ `sleep 40` | ✅ Proper waits |
| Maintenance | 🔴 Abandoned | 🟢 Documented |

---

## Migration Guide

### For existing users:

1. **Backup your old setup**
   ```bash
   cp -r /opt/hackerEnv /opt/hackerEnv.backup
   ```

2. **The original script still works**
   ```bash
   ./hackerEnv -t 192.168.1.100  # Old version
   ```

3. **Try the new version**
   ```bash
   # Create authorization file first!
   echo "192.168.1.0/24" > .authorized_targets
   ./hackerEnv2 -t 192.168.1.100  # New version
   ```

4. **Key differences**:
   - Must create `.authorized_targets` file
   - All activity logged to `logs/`
   - Results in `targets/` directory
   - Configure via `config/settings.conf`

---

## Adding New Modules

Example: Create `modules/ftp.sh`

```bash
#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

MODULE_NAME="FTP"

function ftp_module_main() {
    local target="$1"
    local scan_dir="$2"
    
    log_info "[$MODULE_NAME] Starting for: $target"
    
    # Your exploitation logic here
    
    log_info "[$MODULE_NAME] Completed for: $target"
}

export -f ftp_module_main
```

Then load in `hackerEnv2`:
```bash
source "${SCRIPT_DIR}/modules/ftp.sh"
# ... in main loop:
ftp_module_main "$target" "$target_dir"
```

---

## Security Considerations

### ⚠️ This tool is LOUD
- Nmap scans are easily detected by IDS/IPS
- Bruteforce attempts trigger account lockouts
- Activity is logged on target systems

### ✅ Use responsibly
1. Only test systems you own or have written permission
2. Review authorization file before each scan
3. Check audit logs regularly
4. Understand what each command does
5. Test in isolated lab environment first

### 📋 Authorization checklist
- [ ] Written permission obtained
- [ ] Scope documented (IPs, dates, restrictions)
- [ ] Stakeholders notified
- [ ] Targets added to `.authorized_targets`
- [ ] Backup plan if something breaks
- [ ] Incident response contact ready

---

## Known Limitations

1. **Only SSH module refactored** - FTP, SMB, etc. still need work
2. **No GUI** - Command-line only
3. **Linux only** - Tested on Kali/Parrot
4. **Exploits dated** - Focus on 2008-2017 vulnerabilities
5. **No stealth mode** - Scans are noisy

---

## Future Roadmap

- [ ] Refactor remaining modules (FTP, SMB, Telnet, Apache)
- [ ] Add report generation (HTML/JSON)
- [ ] Implement rate limiting for stealth
- [ ] Add CI/CD pipeline
- [ ] Python rewrite for better async
- [ ] Web dashboard for results
- [ ] Plugin system for custom modules

---

## Troubleshooting

### "Authorization file not found"
```bash
# Create it:
touch .authorized_targets
echo "192.168.1.0/24" >> .authorized_targets
```

### "Missing required dependencies"
```bash
# Install on Kali:
sudo apt update
sudo apt install nmap fping xmlstarlet jq
```

### "Target not authorized"
```bash
# Add to authorization file:
echo "192.168.1.100" >> .authorized_targets
```

### "Permission denied"
```bash
# Make scripts executable:
chmod +x hackerEnv2 lib/*.sh core/*.sh modules/*.sh
```

---

## Contributing

This refactored version demonstrates best practices for security tools:

1. **Security first**: Authorization before action
2. **Modular design**: Easy to extend
3. **Proper logging**: Audit trail required
4. **Error handling**: Fail gracefully
5. **Testing**: Verify functionality
6. **Documentation**: Explain everything

Feel free to:
- Report bugs
- Suggest improvements  
- Add new modules
- Improve documentation
- Submit pull requests

---

## Credits

- Original HackerEnv: @abdulr7mann
- v2.0 Refactoring: Security best practices applied
- Community: Thanks for feedback and bug reports

---

## License

Same as original: GNU General Public License v3.0

See LICENSE file for details.

---

## Disclaimer

**USE AT YOUR OWN RISK**

This tool is for AUTHORIZED security testing only. Unauthorized access to computer systems is illegal. The developers assume no liability for misuse or damage caused by this program.

All activity is logged for audit purposes.

By using this tool, you agree to comply with all applicable laws.

---

**Ready to test responsibly? Start with `./hackerEnv2 --help`**
