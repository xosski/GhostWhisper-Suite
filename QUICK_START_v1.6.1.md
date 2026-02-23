# GhostWhisper Suite v1.6.1 - Quick Start Guide

**Version:** 1.6.1  
**Last Updated:** 2026-02-23  
**For Raven. 2017 — ∞**

---

## What's Changed in v1.6.1?

✅ **Code Quality Improvements**
- All modules now follow unified standards
- Type hints added to Python modules
- Deprecated imports fixed in Go modules
- Better error handling throughout

✅ **Security Enhancements**
- Hardcoded credentials removed
- Environment variable configuration
- Improved input validation
- Better error messaging

✅ **New Documentation**
- MODULE_STANDARDS.md - Code consistency guide
- DEPLOYMENT_CHECKLIST.md - Deployment verification
- UPDATES_SUMMARY_v1.6.1.md - Complete release notes

---

## Five Minute Setup

### 1. Prerequisites
```powershell
# Verify PowerShell version
$PSVersionTable.PSVersion  # Should be 5.1+

# Optional: Install Python
python --version  # Should be 3.9+

# Optional: Install Go
go version  # Should be 1.19+
```

### 2. Build the Suite
```powershell
cd C:\Path\To\GhostWhisper-Suite
.\BuildDeployWhisper.ps1
```

Expected output:
```
[*] WhisperSuite Build System v1.6.1
[+] GhostKey.dll compiled successfully
[+] WraithTap.exe compiled successfully
[+] Package prepared: ...\WhisperSuite_Build
```

### 3. Verify Build
```powershell
# Check output directory
ls WhisperSuite_Build

# Should contain:
# - GhostKey.dll
# - WraithTap.exe
# - All .ps1 modules
# - build_manifest.json
```

### 4. Set Environment Variables (Optional)
```bash
# For GhostBrute Discord notifications
set DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# For GhostFTP
set FTP_HOST=ftp.example.com
set FTP_USER=username
set FTP_PASS=password
```

### 5. Launch Operator Console
```powershell
.\GhostWhisperBootstrap.ps1
```

---

## Module Quick Reference

### Essential PowerShell Modules

**GhostWhisperBootstrap.ps1** - Main operator interface
```powershell
.\GhostWhisperBootstrap.ps1

# Menu options:
# [1] Memory Recon
# [2] ExorcistMode Cleanup
# [3] GhostKey Injection
# [4] Wormhole Listener
# [5] Linux VM
# [7-10] Advanced operations
# [11-14] Utilities
```

**SilentBloom.ps1** - Cleanup operations
```powershell
.\SilentBloom.ps1
# Removes all traces of operations
```

**BLETrigger.ps1** - BLE activation
```powershell
.\BLETrigger.ps1
# Triggers via Bluetooth Low Energy
```

### Python Tools

**GhostBluetooth.py** - Bluetooth operations
```bash
python GhostBluetooth.py
# GUI for BLE device scanning and blocking
```

**GhostFTP.py** - FTP automation
```bash
python GhostFTP.py --host ftp.example.com --username user --password pass
```

**GhostHadesIntegrator.py** - AI integration
```bash
python GhostHadesIntegrator.py --target 192.168.1.1 --scan quick
```

### Go Tools

**GhostBrute** - SSH brute force
```bash
go run GhostBrute.go 22 5 iplist.txt
# Port 22, 5 workers, IP list file
```

---

## Common Operations

### Memory Injection
```powershell
# 1. Open GhostWhisperBootstrap
.\GhostWhisperBootstrap.ps1

# 2. Select option [3] Deploy GhostKey
# 3. Verify WraithTap.exe and GhostKey.dll exist
# 4. Injection begins
```

### Bluetooth Triggering
```powershell
# 1. Set up Flipper Zero with BLE payload
# 2. Run BLETrigger
.\BLETrigger.ps1

# 3. Monitor for activation
```

### Cleanup Post-Operation
```powershell
# 1. Run SilentBloom
.\SilentBloom.ps1

# 2. Confirm cleanup scope
# 3. Operation traces removed

# Removes:
# - Memory artifacts
# - Registry entries
# - Event logs
# - Browser extensions
# - Temporary files
```

### Network Scanning
```powershell
# In GhostWhisperBootstrap menu:
# Select [13] Network Discovery Scan
# Scans subnet 192.168.1.0/24
# Returns live hosts and hostnames
```

---

## Troubleshooting

### Build Fails
```powershell
# Check if MSBuild available
Get-Command msbuild

# Try with dotnet instead
$env:DOTNET_ROOT

# If missing, install Visual Studio Build Tools
```

### Module Loading Fails
```powershell
# Check module path
Get-Location  # Should be root directory

# Verify module exists
Test-Path Modules\ModuleName.ps1

# Check for syntax errors
. .\Module.ps1 -ErrorAction Stop
```

### Python Import Errors
```bash
# Verify Python path
python --version

# Install requirements
pip install -r requirements.txt

# For specific issues
python -m py_compile module.py
```

### Permissions Issues
```powershell
# Check execution policy
Get-ExecutionPolicy

# Temporarily allow scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or unblock specific file
Unblock-File -Path .\BuildDeployWhisper.ps1
```

---

## Security Checklist

Before running operations:

- [ ] Environment variables set (if using external tools)
- [ ] No sensitive data in console history
- [ ] Network connectivity verified
- [ ] Firewall rules checked
- [ ] EDR/AV status known
- [ ] Cleanup procedures ready
- [ ] Logs will be monitored

### Secure Configuration

```powershell
# Don't do this:
$password = "MyPassword123"
.\Script.ps1 -Password $password

# Do this instead:
$env:GHOST_PASSWORD = "MyPassword123"
# Then read from $env in script
```

```bash
# Don't do this:
python tool.py --api-key sk-12345

# Do this instead:
export API_KEY=sk-12345
# Then read from os.environ in Python
```

---

## Key Files & Locations

```
WhisperSuite-GhostWhisper-Suite/
├── README.md                          # Project overview
├── MODULE_STANDARDS.md                # Code consistency guide (NEW)
├── DEPLOYMENT_CHECKLIST.md           # Deployment verification (NEW)
├── UPDATES_SUMMARY_v1.6.1.md         # Release notes (NEW)
├── QUICK_START_v1.6.1.md             # This file (NEW)
│
├── GhostWhisperBootstrap.ps1         # Main console (UPDATED v1.6.1)
├── BuildDeployWhisper.ps1            # Build script (UPDATED v1.6.1)
├── SilentBloom.ps1                   # Cleanup tool
├── BLETrigger.ps1                    # BLE controller
│
├── GhostBluetooth.py                 # BLE tool (ENHANCED)
├── GhostFTP.py                       # FTP tool (ENHANCED)
├── GhostBrute.go                     # SSH bruteforce (ENHANCED)
│
├── Modules/
│   ├── GhostLogger.ps1               # Logging
│   ├── ExorcistMode.ps1              # Malware removal
│   ├── Wormhole.ps1                  # Propagation
│   ├── GhostHadesIntegrator.py       # AI integration
│   └── ... (20+ total modules)
│
└── Tools/
    └── ... (Various utility tools)
```

---

## Version Verification

### Check Suite Version
```powershell
# In GhostWhisperBootstrap
# Top banner shows: "GhostWhisper Suite v1.6.1"

# Or check directly:
Select-String "Version = " GhostWhisperBootstrap.ps1
```

### Check Module Versions
```powershell
# PowerShell
Get-Content Module.ps1 | Select-String "Version"

# Python
python -c "import module; print(module.__version__)"

# Go
grep "const Version" tool.go
```

---

## Common Parameters

### PowerShell
```powershell
-Verbose        # Enable verbose output
-ErrorAction    # How to handle errors (Stop, Continue)
-SkipCompile    # Skip compilation phase
-SkipPackage    # Skip packaging
-SkipPersistence # Skip persistence setup
-OutputDir      # Specify output directory
```

### Python
```bash
--help          # Show help
--verbose       # Enable verbose logging
--config        # Configuration file
--timeout       # Operation timeout
--target        # Target host
```

### Go
```bash
port            # SSH port (first argument)
threads         # Worker count (second argument)
iplist          # IP list file (third argument)
```

---

## Next Steps

1. **Review Standards**
   - Read MODULE_STANDARDS.md for code consistency
   - Understand expected patterns and conventions

2. **Prepare Deployment**
   - Follow DEPLOYMENT_CHECKLIST.md
   - Verify all prerequisites
   - Test in isolated environment first

3. **Execute Operations**
   - Use GhostWhisperBootstrap.ps1 as main interface
   - Monitor logs and output
   - Keep cleanup procedures ready

4. **Maintain Security**
   - Regularly review logs
   - Use cleanup tools after operations
   - Monitor for EDR/AV interference

---

## Support & Documentation

### Documentation Files
- `README.md` - Project overview and capabilities
- `MODULE_STANDARDS.md` - Code consistency standards
- `DEPLOYMENT_CHECKLIST.md` - Deployment procedures
- `UPDATES_SUMMARY_v1.6.1.md` - Detailed release notes
- `Usage.md` - Detailed usage guide
- `Deployment.md` - Deployment procedures

### Getting Help
1. Check documentation files above
2. Review relevant module comments
3. Check logs for error details
4. Consult team members

---

## Quick Command Reference

```powershell
# Build and Package
.\BuildDeployWhisper.ps1

# Launch Operator Console
.\GhostWhisperBootstrap.ps1

# Run Cleanup
.\SilentBloom.ps1

# Check Status
Get-Content C:\ProgramData\.ghost.cfg | ConvertFrom-Json
```

```bash
# Python BLE tool
python GhostBluetooth.py

# FTP transfer
python GhostFTP.py --host ftp.example.com --username user --password pass

# AI integration
python GhostHadesIntegrator.py --target 192.168.1.1

# SSH brute force
go run GhostBrute.go 22 5 ips.txt
```

---

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| 1.6.1 | 2026-02-23 | Code quality, security fixes, new docs |
| 1.6.0 | 2025-12-31 | HadesAI integration |
| 1.5.0 | 2025-03-23 | Virtualization support |

---

## Legal Notice

This toolkit is for **authorized testing only**. Users are responsible for compliance with all applicable laws and regulations. Unauthorized access is illegal.

---

## Support

**For questions or issues:**
- Review documentation in suite root directory
- Check module comments for implementation details
- Consult DEPLOYMENT_CHECKLIST.md for setup issues
- Review MODULE_STANDARDS.md for coding standards

---

## Summary

v1.6.1 focuses on **quality and consistency**. All modules follow unified standards, implement proper error handling, and maintain security best practices.

**Ready to deploy:** ✅ YES

🕊️ For Raven. 2017 — ∞
