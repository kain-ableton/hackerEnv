# HackerEnv - Installation Location

## Current Location

```
/home/k/hackerEnv/
```

**Moved from:** `/opt/hackerEnv/` on 2025-11-16

---

## Quick Access

```bash
# Navigate to hackerEnv
cd ~/hackerEnv

# Run the refactored version
./hackerEnv2 --help

# Run tests
./tests/run_tests.sh

# View documentation
cat README_v2.md
```

---

## Optional: Create Alias

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# HackerEnv aliases
alias hackerenv='cd ~/hackerEnv'
alias henv2='~/hackerEnv/hackerEnv2'
alias henv='~/hackerEnv/hackerEnv'
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

Usage after alias:
```bash
hackerenv          # Go to hackerEnv directory
henv2 --help       # Run refactored version
henv2 -t 127.0.0.1 # Scan localhost
```

---

## Optional: Add to PATH

```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$HOME/hackerEnv:$PATH"

# Reload
source ~/.bashrc

# Now you can run from anywhere
hackerEnv2 -t 192.168.1.100
```

---

## File Structure

```
/home/k/hackerEnv/
├── hackerEnv2              # New refactored script
├── hackerEnv               # Original script
├── config/
│   └── settings.conf       # Configuration
├── lib/
│   ├── utils.sh           # Utilities
│   └── authorization.sh   # Authorization & audit
├── core/
│   └── scanner.sh         # Scanning engine
├── modules/
│   └── ssh.sh             # SSH module
├── tests/
│   └── run_tests.sh       # Test suite
├── .authorized_targets     # Target authorization
├── logs/                  # Activity logs
├── reports/               # Generated reports
└── targets/               # Scan results (created on first run)
```

---

## Permissions

All files are owned by user `k`:

```bash
$ ls -la ~/hackerEnv/
drwxr-xr-x 11 k k   4096 Nov 16 02:39 .
-rwxrwxr-x  1 k k   9851 Nov 16 02:33 hackerEnv2
-rwxr-xr-x  1 k k 106999 Nov 16 02:13 hackerEnv
```

Scripts are executable and ready to use.

---

## Next Steps

1. **Review authorized targets:**
   ```bash
   nano ~/hackerEnv/.authorized_targets
   ```

2. **Run your first scan:**
   ```bash
   cd ~/hackerEnv
   echo "127.0.0.1" > .authorized_targets
   ./hackerEnv2 -t 127.0.0.1
   ```

3. **Check results:**
   ```bash
   ls ~/hackerEnv/targets/127.0.0.1/
   cat ~/hackerEnv/logs/hackerenv_*.log
   ```

---

**Location:** `/home/k/hackerEnv/` ✅  
**Status:** Ready to use
