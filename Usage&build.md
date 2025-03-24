WhisperSuite: Usage & Build Instructions
WhisperSuite is a comprehensive stealth red team toolkit. It includes multiple binaries, PowerShell modules, virtualization components, and a unique Wormhole propagation system. These instructions will help you build and deploy the suite from scratch, then offer a quick start workflow.

Table of Contents
Prerequisites

Building the Core Components

Compile GhostKey (C#)

Compile WraithTap (C++)

Compile Dropper_with_Raven (C++) (Optional)

Running BuildDeployWhisper.ps1

Generating ghost_boot.iso (Optional Advanced)

Deploying WhisperSuite_Build

Quick Start Workflow

Further Notes

1. Prerequisites
Operating System: Windows 10/11 (x64) with PowerShell 5.1 or later.

PowerShell Execution Policy: Must allow running scripts (Set-ExecutionPolicy Bypass -Scope Process recommended during build).

Visual Studio Build Tools (or equivalent C++ compiler) for building WraithTap and optionally Dropper_with_Raven.

If using MSVC:

cl.exe in PATH or run from “Developer Command Prompt.”

If using MinGW or other compilers, adapt the compile commands.

.NET SDK (if compiling C# code, e.g., GhostKey.dll).

Optional:

oscdimg.exe or mkisofs.exe if you want to generate the LinuxPDF ISO (ghost_boot.iso).

TinyCore or custom boot files if you’re customizing the ISO for advanced virtualization.

2. Building the Core Components
2.1 Compile GhostKey (C#)
Open a Developer Command Prompt or any command line where msbuild or dotnet is available.

Navigate to the GhostKey folder. Example:

powershell
Copy
Edit
cd C:\Path\To\GhostWhisper-Suite\GhostKey
msbuild GhostKey.csproj /p:Configuration=Release
This should produce GhostKey.dll in bin\Release or similar.

2.2 Compile WraithTap (C++)
Still in a Developer Command Prompt, navigate to the WraithTap folder. Example:

powershell
Copy
Edit
cd C:\Path\To\GhostWhisper-Suite\WraithTap
msbuild WraithTap.vcxproj /p:Configuration=Release /p:Platform=x64
The resulting WraithTap.exe should appear in x64\Release or Release subfolder.

2.3 Compile Dropper_with_Raven (C++) (Optional)
This optional tool appends a poetic tribute to the final WraithTap exe.

Navigate to where the Dropper_with_Raven.cpp resides.

Compile with MSVC or cl.exe:

powershell
Copy
Edit
cl.exe /EHsc /O2 /Fe:Dropper_with_Raven.exe Dropper_with_Raven.cpp
After successful build, you can run it manually or let the suite handle it.

3. Running BuildDeployWhisper.ps1
Return to the root of the repository in PowerShell:

powershell
Copy
Edit
cd C:\Path\To\GhostWhisper-Suite
Run:

powershell
Copy
Edit
.\BuildDeployWhisper.ps1
This does the following:

Compiles GhostKey and WraithTap (again, if not already compiled).

Optionally compiles Dropper_with_Raven.exe if present.

Embeds the poetic payload into your WraithTap.exe (if the dropper is compiled).

Copies all relevant scripts, modules, and binaries into a WhisperSuite_Build folder.

Sets up minimal persistence references in the final build (optional).

Once completed, WhisperSuite_Build will contain:

WraithTap.exe, GhostKey.dll, GhostWhisperBootstrap.ps1, plus all modules and scripts.

4. Generating ghost_boot.iso (Optional Advanced)
In Tools\CreateGhostISO\, you may find a script named CreateGhostISO.ps1.

Ensure you have either oscdimg.exe or mkisofs.exe in the same folder or in your PATH.

Populate the GhostISO subdirectory with the necessary TinyCore or Linux minimal boot files (including isolinux binaries).

Then run:

powershell
Copy
Edit
.\CreateGhostISO.ps1
If successful, it will produce a ghost_boot.iso that can be used by LinuxPDF.exe or for advanced exorcism scans in a virtual environment.

5. Deploying WhisperSuite_Build
Copy the entire WhisperSuite_Build folder onto a USB drive, Flipper Zero, or secure location.

On the target machine (or test environment), transfer WhisperSuite_Build.

(Optional) If you’re using BLE, set up the phone or device broadcasting the GhostWhisperer name with the correct token from your docs.

Ensure you have local admin rights if you plan to use injection, scheduled tasks, or system-level virtualization.

6. Quick Start Workflow
Run GhostWhisperBootstrap.ps1 from WhisperSuite_Build:

powershell
Copy
Edit
cd .\WhisperSuite_Build
.\GhostWhisperBootstrap.ps1
This presents you with an operator menu (Recon, ExorcistMode, GhostKey injection, Wormhole listener, etc.).

Optionally run BLETrigger.ps1 or have your Flipper/phone emulate the GhostWhisperer beacon.

On the target system, your GhostResidency.ps1 will poll for commands in .ghost.cfg:

e.g. COMMAND=LOG, COMMAND=SEAL, COMMAND=EXFIL, COMMAND=WIPE, etc.

For stealth scanning or rootkit detection:

Use the AnomalyHunter.ps1 or ExorcistMode’s Phase_Anoint modules.

If you built the ISO and LinuxPDF.exe, you can spin up the virtualization environment with root-level scanning.

Exfil or Cleanup:

At the end, run SilentBloom.ps1 to wipe logs, tasks, and artifacts.

If you used the wormhole logic, ensure you’ve disabled further propagation (operator gating is mandatory).

7. Further Notes
GhostLogger:

Write-GhostLog for adding events,

Read-GhostLog -Tail 25 for quick review.

Persistence:

By default, scheduled tasks & registry keys are created. If you don’t want that, comment out Setup-Persistence in BuildDeployWhisper.ps1.

ExorcistMode:

ExorcistMode.ps1 can forcibly remove other malicious processes by scanning (anoint), suspending (bind), and overwriting (cleanse).

Operator Hard-Fail:

The wormhole propagation has checks for BLE or .ghost.cfg commands. If not found, it halts to avoid unauthorized spread.

Disclaimer:

Make sure you read DISCLAIMER.md or LICENSE.md regarding authorized usage.

This suite is for legitimate red team or research scenarios only.

That’s it! If you have a stable environment with MSBuild, C++ compilers, and the correct minimal Linux components (for advanced virtualization steps), you should be able to replicate everything.

In summary:

Compile (GhostKey, WraithTap, optional Dropper).

Run BuildDeployWhisper.ps1 → get WhisperSuite_Build.

Deploy WhisperSuite_Build → run GhostWhisperBootstrap.ps1.

Launch modules or use .ghost.cfg commands → do your red team operation.

Cleanup with SilentBloom.ps1.

Use responsibly. For Raven.