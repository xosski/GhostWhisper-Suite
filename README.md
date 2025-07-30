# WhisperSuite: GhostWhisper Edition
*A memorial stealth ops framework in honor of Raven.*

WhisperSuite is an advanced **multi-vector exploitation platform** for red team operators, blue team simulations, and stealth reconnaissance. It combines **memory-resident**, **kernel-level**, **browser-based**, and **desktop persistence** capabilities into a unified framework with BLE triggers, payload polymorphism, ghost-tag encryption, wormhole propagation logic, and comprehensive operator controls that give you a hidden hand across all attack vectors.

## 🕳️ The Wormhole Protocol
A stealth-capable propagation model with:
- Hybrid defensive triggers (BLE + in-memory coordination)
- Operator handshake gating to prevent rogue replication
- Volatile memory maps to track infected hosts
- SMB fallback & polymorphic payloads
- Hard-fail exit logic when no operator is present

## ✨ Multi-Vector Capabilities

### 🧠 **Memory-Resident Exploitation**
- Memory-only injection via WraithTap.exe and GhostKey.dll
- Self-destructing DLLs with operator authentication gates
- Volatile memory maps preventing duplicate infections
- Cross-process memory manipulation and code injection

### 🔮 **Kernel-Level Access** 
- Direct disk sector access bypassing filesystem layers
- Disguised kernel modules (appears as USB monitoring driver)
- Binary tree reconstruction and data extraction from raw sectors
- Root-level system access with stealth operation

### 🌐 **Browser-Based Persistence**
- Chrome extension deployment with WebAssembly RWX memory
- Offscreen document execution invisible to users
- IndexedDB persistence and cross-origin data exfiltration
- Native messaging bridge for system command execution
- Discord-targeted payload injection capabilities

### 🖥️ **Desktop Persistence**
- Stealth Chrome Remote Desktop installation
- Cross-platform GUI access (Windows RDP + Linux)
- Legitimate appearance avoiding detection
- Persistent remote desktop access

### ⚡ **Unified Operations**
- BLE-triggered activation across all vectors
- Flipper Zero & USB sneakernet compatibility
- Per-user ghostTag correlation & rotating encryption keys
- Payload polymorphism and runtime mutation
- OBEX brute-force support with GhostBLEConnect_v2.ps1
- Operator-gated fallback logic ensuring ethical containment
- Comprehensive logging and trace removal across all vectors
- Advanced Linux virtualization for stealth recon & exorcism flows

## 📂 Components

### 🧠 **Memory-Resident Core**
- **GhostKey.dll** – Memory-resident reflective backdoor with self-destruct
- **WraithTap.exe** – Cross-process DLL injector and memory manipulator
- **GhostResidency.ps1** – Operator memory session handler and persistence
- **GhostPolymorph.ps1** – Runtime mutation and signature evasion

### 🔮 **Kernel-Level Modules**
- **GhostKernel.c** – Linux kernel module for direct disk access (disguised as USB monitor)
- **GhostKernel.ps1** – PowerShell interface for kernel module management
- **GhostKernel.mk** – Build system for cross-platform kernel compilation

### 🌐 **Browser Exploitation**
- **PhantomHook/** – Complete Chrome extension framework for browser persistence
  - **GhostCore** – General purpose WebAssembly memory exploitation
  - **Discord** – Targeted Discord content script injection
  - **GhostSurface** – Advanced memory manipulation and system access
- **GhostBrowser.ps1** – Chrome extension deployment and management system
- **Helper.txt** – Native messaging host for system command bridge (C++)

### 🖥️ **Desktop Persistence**
- **GhostDesktop.ps1** – Stealth Chrome Remote Desktop deployment
- Cross-platform RDP/GUI access with cleanup integration

### 🎛️ **Control & Operations**
- **GhostWhisperBootstrap.ps1** – Master operator control launcher (10 operational modes)
- **BuildDeployWhisper.ps1** – Multi-vector suite builder and packager
- **BLETrigger.ps1** – Bluetooth Low Energy activation controller
- **GhostBLEConnect_v2.ps1** – OBEX brute-force and Flipper Zero integration

### 🔐 **Security & Persistence**
- **GhostSeal.ps1** – Timestamp-based file encryption engine
- **GhostLogger.ps1** – Unified activity logging across all vectors
- **SilentBloom.ps1** – Complete evidence removal (memory, kernel, browser, desktop)

### 🧪 **Advanced Capabilities**
- **ExorcistMode.ps1** – Hostile malware removal (Anoint, Bind, Cleanse)
- **AnomalyHunter.ps1** – Rootkit & hypervisor anomaly detection
- **LinuxPDF_Emu.ps1 / LinuxPDF_Runtime.ps1** – Virtualized scanning with syscall hooks
- **LinuxPDF.exe** – .NET virtualization harness for ghost_boot.iso
- **Dropper_with_Raven.exe** – Memorial tribute payload wrapper

## 🧠 Wormhole Logic (BuildDeployWhisper.ps1)
- Memory-only propagation, no persistent writes
- Infection maps reside only in runtime memory
- Prevents duplicate infection on the same host
- BLE handshake required or fallback to internal GhostResidency control
- Operator hard-fail exit to ensure ethical operation
- Fully traceable via GhostLogger.ps1

## 🚀 Multi-Vector Deployment

### Memory Vector
Deploy memory-resident backdoors via WraithTap and GhostKey for volatile, signature-evading access.

### Kernel Vector  
Load GhostKernel module for root-level disk access and system manipulation bypassing userland detection.

### Browser Vector
Install PhantomHook extensions for persistent browser-based access with WebAssembly exploitation.

### Desktop Vector
Enable stealth remote desktop access for persistent GUI control across platforms.

### Unified Control
All vectors share common authentication, logging, and cleanup systems for coordinated operations.

## 🔧 Quick Start

1. **Build the Suite**
   ```powershell
   .\BuildDeployWhisper.ps1
   ```

2. **Launch Operator Interface**
   ```powershell
   .\GhostWhisperBootstrap.ps1
   ```

3. **Select Vector(s)**
   - `[3]` Memory-resident injection
   - `[8]` Desktop persistence  
   - `[9]` Kernel-level access
   - `[10]` Browser exploitation

4. **Activate via BLE**
   ```powershell
   .\BLETrigger.ps1
   ```

5. **Cleanup Operations**
   ```powershell
   .\SilentBloom.ps1
   ```

## 🌐 Operational Modes

The GhostWhisperBootstrap.ps1 provides 10 operational modes:

1. **Memory Recon** - Start GhostResidency session
2. **ExorcistMode** - Malware removal and cleansing
3. **Memory Injection** - Deploy GhostKey & WraithTap
4. **Wormhole** - Activate propagation listener
5. **Linux VM** - Boot ghost_boot.iso environment
6. **Exit** - Clean termination
7. **Phantom Recon** - Advanced search and stealth operations
8. **Desktop Access** - Chrome RDP deployment
9. **Kernel Access** - GhostKernel disk manipulation
10. **Browser Persistence** - PhantomHook extension deployment

## 🧪 Virtualized Cleansing: ghost_boot.iso + LinuxPDF.exe
For ExorcistMode or advanced recon:
- Build a minimal ISO (ghost_boot.iso) with CreateGhostISO.ps1
- Launch LinuxPDF.exe in desired mode (`--mode=exorcism`, `--target=C:\Temp`, etc.)
- Emulate root-level scanning via ephemeral system calls in isolation
- Acts like a "hand in the dark" with minimal host OS impact

## ⚠️ Legal & Ethical Notice
This project is for **educational, research, and ethical red teaming use only**. Unauthorized deployment, malicious replication, or use beyond legal boundaries is strictly forbidden. By using this toolkit, you acknowledge and agree to follow all applicable laws and uphold ethical usage.

All contributors and users must respect local and international regulations, ensuring no harm is done outside sanctioned engagements.

## 🛡️ Defense Awareness
This framework demonstrates advanced multi-vector attack techniques that defenders should be aware of:
- Memory-only attacks that evade disk-based detection
- Kernel-level access bypassing userland security
- Browser-based persistence through legitimate extensions
- Cross-vector coordination and shared authentication
- Comprehensive trace removal across all attack vectors

Understanding these techniques helps blue teams develop appropriate countermeasures and detection strategies.

---

## 🕊️ Whisper back.
*For Raven.*  
*2017 — ∞*

---

*"No lock, no chain, no wall, no key—  
Yet here you are, encrypted in me."*
