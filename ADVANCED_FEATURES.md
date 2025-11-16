# HackerEnv v2 - Advanced Features

## Automatic Host Discovery Retry (-Pn)

HackerEnv v2 now automatically detects when a host appears to be down due to firewall rules blocking ping probes and retries the scan with the `-Pn` flag.

### How It Works

1. **Initial Scan**: Performs standard nmap scan with host discovery
2. **Detection**: Checks scan output for:
   - "Host seems down"
   - "0 hosts up"
3. **Automatic Retry**: If host appears down, automatically retries with `-Pn` flag
4. **Smart Results**: Uses retry results if they find open ports

### Example Output

```
[INFO] Starting NORMAL scan on: 192.168.1.100
[WARNING] Host 192.168.1.100 appears down, retrying with -Pn (skip host discovery)
[SUCCESS] Retry successful! Host is up with firewall blocking ping
```

### Benefits

- No manual intervention needed
- Finds hosts behind restrictive firewalls
- Automatically handles false negatives
- Saves time on manual retries

## Service-Based Nmap Scripts

HackerEnv v2 automatically runs targeted nmap scripts based on detected services.

### Supported Services

| Service | Scripts Run |
|---------|-------------|
| **HTTP/HTTPS** | http-enum, http-headers, http-methods, http-robots.txt, http-title, http-shellshock, http-vuln-* |
| **SSH** | ssh-auth-methods, ssh-hostkey, ssh2-enum-algos, sshv1 |
| **FTP** | ftp-anon, ftp-bounce, ftp-brute, ftp-proftpd-backdoor, ftp-vsftpd-backdoor |
| **SMB** | smb-enum-shares, smb-enum-users, smb-os-discovery, smb-protocols, smb-security-mode, smb-vuln-* |
| **MySQL** | mysql-info, mysql-empty-password, mysql-users, mysql-databases, mysql-vuln-* |
| **PostgreSQL** | pgsql-brute, postgresql-databases, postgresql-brute |
| **SMTP** | smtp-commands, smtp-enum-users, smtp-open-relay, smtp-vuln-* |
| **DNS** | dns-zone-transfer, dns-nsid, dns-recursion, dns-service-discovery |
| **RDP** | rdp-enum-encryption, rdp-vuln-ms12-020 |
| **VNC** | vnc-info, vnc-brute |
| **SNMP** | snmp-info, snmp-processes, snmp-sysdescr, snmp-win32-services |
| **LDAP** | ldap-rootdse, ldap-search, ldap-brute |
| **MongoDB** | mongodb-info, mongodb-databases, mongodb-brute |
| **Redis** | redis-info, redis-brute |

### How It Works

1. **Service Detection**: Initial scan detects services with `-sV`
2. **Service Extraction**: Extracts service names from XML output
3. **Script Mapping**: Maps services to relevant nmap scripts
4. **Automated Execution**: Runs service-specific scripts automatically
5. **Results Storage**: Saves output to `service_scripts_<target>_<service>.*`

### Example Output

```
[INFO] Running service-specific nmap scripts for 192.168.1.100
[INFO] Running HTTP/HTTPS enumeration scripts on 192.168.1.100
[INFO] Running SSH enumeration scripts on 192.168.1.100
[INFO] Running SMB enumeration scripts on 192.168.1.100
[SUCCESS] Ran service-specific scripts for 3 service(s)
```

### Output Files

Service script results are saved in the target directory:

```
targets/192.168.1.100/
├── nmap_192.168.1.100.xml          # Main scan
├── service_scripts_192.168.1.100_http.xml
├── service_scripts_192.168.1.100_ssh.xml
├── service_scripts_192.168.1.100_smb.xml
└── ...
```

## Combined Features Example

When scanning a host that blocks ping and has web services:

```bash
./hackerEnv2 -t 192.168.1.100 -m normal
```

**Output:**
```
[INFO] Starting NORMAL scan on: 192.168.1.100
[WARNING] Host 192.168.1.100 appears down, retrying with -Pn
[SUCCESS] Retry successful! Host is up with firewall blocking ping
[SUCCESS] Port scan completed for 192.168.1.100
[INFO] Open ports found:
80/tcp http Apache httpd 2.4.41
443/tcp ssl/http Apache httpd 2.4.41
22/tcp ssh OpenSSH 8.2p1

[INFO] Running service-specific nmap scripts for 192.168.1.100
[INFO] Running HTTP/HTTPS enumeration scripts on 192.168.1.100
[INFO] Running SSH enumeration scripts on 192.168.1.100
[SUCCESS] Ran service-specific scripts for 2 service(s)
```

## Benefits

### Time Savings
- Automatic retry eliminates manual intervention
- Service scripts run in parallel with exploit modules
- No need to manually determine which scripts to run

### Better Results
- More complete reconnaissance
- Service-specific vulnerability checks
- Catches hosts that would otherwise be missed

### Improved Workflow
- Everything runs automatically
- Comprehensive results in one command
- Organized output files for analysis

## Configuration

### Disable Service Scripts

To disable automatic service scripts, you can modify `core/scanner.sh` and comment out the line:

```bash
# run_service_scripts "$target" "$output_dir"
```

### Add Custom Service Mappings

Edit `core/scanner.sh` in the `run_service_scripts()` function to add new services:

```bash
case "$service" in
    myservice)
        scripts="myservice-enum,myservice-vuln-*"
        log_info "Running My Service enumeration scripts on $target"
        ;;
    # ... existing services ...
esac
```

## Performance Impact

- **-Pn Retry**: Adds 30-60 seconds if triggered (only for down hosts)
- **Service Scripts**: Adds 1-5 minutes per service type
- **Overall**: Minimal impact with significant value gain

## Troubleshooting

### Service Scripts Not Running

Check if services were detected:
```bash
cat targets/<IP>/services.txt
```

### -Pn Retry Not Triggering

The host must show "Host seems down" or "0 hosts up" in initial scan output.

### Script Timeouts

Long-running scripts may timeout. Check error files:
```bash
cat targets/<IP>/service_scripts_*_<service>.err
```

For more information, see the main README.md or SCAN_MODES.md
