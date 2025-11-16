# HackerEnv v2 - Toolchains & Workflows

## Overview

HackerEnv v2 now includes integrated toolchains that orchestrate multiple tools in logical workflows for comprehensive security assessments.

## Toolchain Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HackerEnv Core                           │
├─────────────────────────────────────────────────────────────┤
│  Discovery → Enumeration → Exploitation → Post-Exploitation │
└─────────────────────────────────────────────────────────────┘
```

## Available Toolchains

### 1. Web Application Toolchain
**Purpose**: Complete web application security assessment

**Tools Integrated**:
- whatweb (technology detection)
- nikto (web vulnerability scanner)
- dirb/gobuster (directory enumeration)
- wapiti (web app scanner)
- sqlmap (SQL injection)
- xsstrike (XSS detection)

**Workflow**:
```
HTTP/HTTPS detected → whatweb → nikto → dirb → wapiti → sqlmap
```

### 2. Database Toolchain
**Purpose**: Database enumeration and exploitation

**Tools Integrated**:
- mysql client
- psql (PostgreSQL)
- mongo shell
- redis-cli
- mssql-cli

**Workflow**:
```
DB port detected → version check → enum users/databases → weak passwords
```

### 3. SMB/CIFS Toolchain
**Purpose**: Windows network shares enumeration

**Tools Integrated**:
- enum4linux
- smbclient
- smbmap
- crackmapexec

**Workflow**:
```
SMB detected → enum4linux → smbmap → null session → share access
```

### 4. Active Directory Toolchain
**Purpose**: Active Directory reconnaissance

**Tools Integrated**:
- ldapsearch
- rpcclient
- kerbrute
- bloodhound (optional)

**Workflow**:
```
LDAP/AD detected → ldapsearch → user enum → kerberos enum
```

### 5. Email/SMTP Toolchain
**Purpose**: Email server enumeration

**Tools Integrated**:
- smtp-user-enum
- swaks (SMTP test)

**Workflow**:
```
SMTP detected → banner grab → user enumeration → relay test
```

### 6. DNS Toolchain
**Purpose**: DNS reconnaissance

**Tools Integrated**:
- dig
- dnsrecon
- dnsenum
- fierce

**Workflow**:
```
DNS detected → zone transfer → subdomain enum → reverse lookup
```

## Workflow Engine

### Automatic Workflow Selection

Based on detected services, HackerEnv automatically selects and executes appropriate toolchains:

```bash
if [[ service == "http" ]]; then
    run_web_toolchain
elif [[ service == "mysql" ]]; then
    run_database_toolchain
fi
```

### Manual Workflow Execution

```bash
# Run specific toolchain
./hackerEnv2 -t 192.168.1.100 --toolchain web

# Run multiple toolchains
./hackerEnv2 -t 192.168.1.100 --toolchain web,smb,dns

# Run all available toolchains
./hackerEnv2 -t 192.168.1.100 --toolchain all
```

## Workflow Configuration

### Enable/Disable Toolchains

Edit `config/toolchains.conf`:

```ini
[web_toolchain]
enabled=true
tools=whatweb,nikto,dirb
aggressive=false

[smb_toolchain]
enabled=true
tools=enum4linux,smbmap
null_session_test=true

[database_toolchain]
enabled=true
brute_force=false
```

## Advanced Workflows

### 1. Full Network Assessment Workflow

```
Phase 1: Discovery
├─ Host discovery (fping)
├─ Port scanning (nmap)
└─ Service detection

Phase 2: Enumeration
├─ Run service-specific toolchains
├─ Gather credentials
└─ Map attack surface

Phase 3: Exploitation
├─ Run exploit modules
├─ Test weak credentials
└─ Attempt exploits

Phase 4: Reporting
├─ Generate findings report
├─ Create attack graph
└─ Export results
```

### 2. Stealth Assessment Workflow

```
Phase 1: Passive Recon
├─ DNS enumeration
├─ SSL certificate analysis
└─ Public data gathering

Phase 2: Light Touch
├─ Stealth port scan
├─ Minimal service probes
└─ No active exploitation

Phase 3: Documentation
├─ Service inventory
├─ Potential vulnerabilities
└─ Recommendations
```

### 3. Red Team Workflow

```
Phase 1: OSINT
├─ Subdomain enumeration
├─ Email harvesting
└─ Employee profiling

Phase 2: Initial Access
├─ Phishing preparation
├─ Password spraying
└─ Exploit development

Phase 3: Post-Compromise
├─ Privilege escalation
├─ Lateral movement
└─ Persistence
```

## Toolchain Output Structure

```
targets/192.168.1.100/
├─ nmap_scan/
├─ web_toolchain/
│  ├─ whatweb_results.txt
│  ├─ nikto_scan.txt
│  ├─ dirb_output.txt
│  └─ sqlmap_results.txt
├─ smb_toolchain/
│  ├─ enum4linux.txt
│  └─ smbmap.txt
└─ toolchain_summary.txt
```

## Integration Points

### 1. Metasploit Integration
```bash
# Export results to Metasploit
./hackerEnv2 -t 192.168.1.100 --export-msf

# Generates: workspace import file
```

### 2. Burp Suite Integration
```bash
# Export HTTP targets to Burp
./hackerEnv2 -t 192.168.1.0/24 --export-burp

# Generates: burp_targets.xml
```

### 3. Report Generation
```bash
# Generate HTML report with toolchain results
./hackerEnv2 -t 192.168.1.100 --report html

# Generate Markdown report
./hackerEnv2 -t 192.168.1.100 --report markdown
```

## Toolchain Best Practices

### 1. Tool Installation
```bash
# Check available tools
./hackerEnv2 --check-tools

# Install missing tools
./hackerEnv2 --install-tools

# Update all tools
./hackerEnv2 --update-tools
```

### 2. Performance Tuning
```ini
[performance]
max_parallel_toolchains=3
tool_timeout=300
aggressive_mode=false
```

### 3. Output Management
```ini
[output]
keep_raw_output=true
compress_old_scans=true
max_scan_age_days=30
```

## Custom Toolchain Development

### Creating a Custom Toolchain

Create `toolchains/custom_chain.sh`:

```bash
#!/bin/bash
# Custom toolchain template

function custom_toolchain_init() {
    local target="$1"
    local output_dir="$2"
    
    log_info "[CUSTOM] Starting custom toolchain for $target"
}

function custom_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    
    # Your custom logic here
    tool1 "$target" > "${output_dir}/tool1_output.txt"
    tool2 "$target" > "${output_dir}/tool2_output.txt"
    
    log_success "[CUSTOM] Toolchain completed"
}

export -f custom_toolchain_init custom_toolchain_run
```

### Register Custom Toolchain

Add to `config/toolchains.conf`:

```ini
[custom_toolchain]
enabled=true
script=toolchains/custom_chain.sh
trigger_service=custom-service
priority=medium
```

## Toolchain Triggers

### Service-Based Triggers

| Service | Triggered Toolchains |
|---------|---------------------|
| http/https | web_toolchain |
| mysql | database_toolchain |
| smb | smb_toolchain |
| ldap | active_directory_toolchain |
| smtp | email_toolchain |
| dns | dns_toolchain |
| ftp | file_transfer_toolchain |
| ssh | secure_shell_toolchain |

### Conditional Triggers

```bash
# Only run if specific version detected
if [[ $service_version == "Apache 2.4.29" ]]; then
    run_apache_exploit_chain
fi

# Only run if port range detected
if [[ $port_count -gt 50 ]]; then
    run_extensive_enumeration
fi
```

## Parallel Toolchain Execution

```bash
# Run toolchains in parallel
./hackerEnv2 -t 192.168.1.100 --parallel

# Limit parallel jobs
./hackerEnv2 -t 192.168.1.100 --parallel --max-jobs 4
```

## Toolchain Results Analysis

### Automated Analysis

```bash
# Analyze all toolchain results
./hackerEnv2 --analyze targets/192.168.1.100/

# Generate attack paths
./hackerEnv2 --analyze --attack-paths targets/192.168.1.100/

# Find credential reuse
./hackerEnv2 --analyze --credentials targets/192.168.1.100/
```

### Manual Review

```bash
# View toolchain summary
cat targets/192.168.1.100/toolchain_summary.txt

# Search for vulnerabilities
grep -r "vulnerable\|exploit\|weak" targets/192.168.1.100/toolchains/
```

## Example Usage

### Quick Web Assessment
```bash
./hackerEnv2 -t example.com -m quick --toolchain web
```

### Full Network Audit
```bash
./hackerEnv2 -t 192.168.1.0/24 -m full --toolchain all --parallel
```

### Targeted Database Assessment
```bash
./hackerEnv2 -t db.example.com --toolchain database --bruteforce
```

### Stealth Domain Recon
```bash
./hackerEnv2 -t example.com -m stealth --toolchain dns,web --passive
```

---

*Toolchains transform HackerEnv from a scanner into a complete security assessment platform*
