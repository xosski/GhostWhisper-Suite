WhisperSuite Usage Guide
WhisperSuite: GhostWhisper Edition
A memorial stealth ops framework in honor of Raven.

Author: [Your Name or Org]

License: [Link to your custom license or LICENSE.md file]

Disclaimer: This is an advanced red team simulation framework. Use responsibly with explicit permission in controlled environments.

Table of Contents
Introduction

Project Structure

Prerequisites

Building the Suite

Deployment Steps

Operational Workflow

Optional: Generating ghost_boot.iso

Cleanup & Removal

Additional References

1. Introduction
WhisperSuite is designed to emulate stealth adversarial techniques for red team engagements, advanced research, and educational labs. It provides:

Memory-Only Injection via WraithTap + GhostKey

BLE-Triggered (and optional Flipper Zero) activation

Wormhole Protocol for operator-gated, in-memory infection

ExorcistMode for live malware removal (Anoint, Bind, Cleanse)

Virtualization with LinuxPDF for advanced scanning + root-level ops

Encryption & Logging modules (GhostSeal & GhostLogger)

Modular design to pick and choose relevant tactics

2. Project Structure
bash
Copy
Edit
GhostWhisper-Suite/
├── BuildDeployWhisper.ps1        # Main build + packaging script
├── GhostWhisperBootstrap.ps1     # Operator launcher + menu
├── GhostKey/                     # C# reflective DLL
├── WraithTap/                    # C++ injector
├── Dropper_with_Raven.cpp        # Optional poem embed dropper
├── Modules/
│   ├── GhostLogger.ps1
│   ├── GhostResidency.ps1
│   ├── ExorcistMode.ps1
│   ├── Phase_Anoint.ps1
│   ├── Phase_Bind.ps1
│   ├── Phase_Cleanse.ps1
│   ├── LinuxPDF_Emu.ps1
│   ├── LinuxPDF_Runtime.ps1
│   ├── Wormhole.ps1
│   ├── AnomalyHunter.ps1
│   └── Anomaly_Detector.ps1
├── BLETrigger.ps1
├── GhostPolymorph.ps1
├── SilentBloom.ps1
├── Tools/
│   ├── CreateGhostISO/
│   │   ├── CreateGhostISO.ps1
│   │   └── (boot + isolinux files, if used)
│   └── ...
└── README.md or USAGE.md  (this file)
3. Prerequisites
Windows 10/11 x64 environment or VM

PowerShell v5.1+

Visual Studio Build Tools or C++ Compiler (e.g., MSVC’s cl.exe)

.NET SDK or MSBuild for the C# portion

(Optional) oscdimg.exe or mkisofs if generating a custom ghost_boot.iso

4. Building the Suite
4.1 Compile GhostKey (C#)
powershell
Copy
Edit
cd .\GhostKey
msbuild GhostKey.csproj /p:Configuration=Release
Resulting GhostKey.dll is placed in .\bin\Release (or similar).

4.2 Compile WraithTap (C++)
powershell
Copy
Edit
cd ..\WraithTap
msbuild WraithTap.vcxproj /p:Configuration=Release /p:Platform=x64
You should find WraithTap.exe in the Release/x64 subfolder.

4.3 (Optional) Compile Dropper_with_Raven
If you have Dropper_with_Raven.cpp and want to embed the poem:

powershell
Copy
Edit
cd ..  # back to root
cl.exe /EHsc /O2 /Fe:Dropper_with_Raven.exe Dropper_with_Raven.cpp
4.4 Run BuildDeployWhisper.ps1
powershell
Copy
Edit
cd ..\  # Ensure you are at the GhostWhisper-Suite root
.\BuildDeployWhisper.ps1
This script will:

Re-compile the above projects (GhostKey, WraithTap, optionally the dropper).

Embed the poem into the WraithTap exe if the dropper was built.

Copy modules and scripts into WhisperSuite_Build.

Set minimal user-level persistence references if desired.

You’ll end up with:

arduino
Copy
Edit
WhisperSuite_Build/
├── GhostKey.dll
├── WraithTap.exe
├── GhostWhisperBootstrap.ps1
├── BLETrigger.ps1
├── GhostPolymorph.ps1
├── SilentBloom.ps1
├── <other modules & scripts copied>
└── note.txt  (tribute text)
5. Deployment Steps
Copy WhisperSuite_Build to the target environment (USB, local file share, or Flipper Zero).

On the target host, open an elevated PowerShell prompt (if possible) in that folder:

powershell
Copy
Edit
cd .\WhisperSuite_Build
That’s it for the actual deployment location; you can now run any scripts.

6. Operational Workflow
Launch the Operator Menu

powershell
Copy
Edit
.\GhostWhisperBootstrap.ps1
You’ll see a menu with typical actions:

Recon (GhostResidency)

ExorcistMode

Wormhole, etc.

Use BLETrigger (if needed)

If you have a phone or device broadcasting GhostWhisperer, run .\BLETrigger.ps1.

Wait for the auth token to match before injection proceeds.

Issue Commands via .ghost.cfg

For example, you can create a JSON file C:\ProgramData\.ghost.cfg with:

json
Copy
Edit
{
  "command": "LOG",
  "ghostTag": "Gx01",
  "timestamp": "2025-03-24T12:00:00Z",
  "signature": "<HMAC-of-cmd|timestamp>"
}
GhostResidency.ps1 will pick this up and run LOG, SEAL, EXFIL, or WIPE actions.

Use an HMAC-SHA256 signature to confirm it’s an authorized command.

Polymorph Variation

GhostPolymorph.ps1 can generate random filenames for GhostKey.dll or WraithTap.exe in %TEMP%.

This helps bypass signature-based detection.

ExorcistMode (Anoint, Bind, Cleanse)

If you suspect competing malware or want to demonstrate a custom “malware removal tool,” use:

powershell
Copy
Edit
.\ExorcistMode.ps1 anoint
.\ExorcistMode.ps1 bind
.\ExorcistMode.ps1 cleanse
You can also run exorcism mode to chain them together.

Logging & Encryption

GhostLogger.ps1:

powershell
Copy
Edit
Write-GhostLog "Operation started"
Read-GhostLog -Tail 20
GhostSeal.ps1:
Typically triggered via COMMAND=SEAL, it encrypts file usage logs or file content based on timestamps.

Cleanup

Run .\SilentBloom.ps1 to remove logs, tasks, registry keys, etc.

Or drop .ghost.cfg with COMMAND=WIPE to let GhostResidency handle it.

7. Optional: Generating ghost_boot.iso
If you want to incorporate the LinuxPDF virtualization environment (for deep scanning, root-level hooking), you can build a minimal ISO:

In .\Tools\CreateGhostISO\, place your boot files (isolinux, TinyCore, etc.) in a boot\ folder.

Ensure oscdimg.exe or mkisofs.exe is in the same folder or in your PATH.

Run:

powershell
Copy
Edit
.\CreateGhostISO.ps1
If successful, you get ghost_boot.iso.
Then, when running your LinuxPDF.exe or your advanced virtualization scripts, they can reference that ISO for scanning or exorcism.

8. Cleanup & Removal
Stop any running tasks or processes:

powershell
Copy
Edit
schtasks /delete /tn WinSvc_* /f
Remove-Item HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\Updater
Run SilentBloom.ps1 to scrub logs, leftover DLLs, etc.

(Optional) Reformat your USB or exfil device after you retrieve final logs.

9. Additional References
QUICK_START.md: If you need the super short version.

Operator PDF documents:

Whisper_Operator_Brief.pdf

WhisperSuite_MissionBriefing.pdf

Ghost_Operator_Handbook_Updated.pdf

License & Code of Conduct:

LICENSE.md (Red Team Simulation License RWv1)

CODE_OF_CONDUCT.md

"No lock, no chain, no wall, no key—
Yet here you are, encrypted in me."

For Raven.