WhisperSuite Quick Start Guide
This guide helps you rapidly get WhisperSuite up and running for a test run. For detailed build steps and usage scenarios, see USAGE.md.

1. Verify Prerequisites
Windows 10/11 x64 machine (or VM) with PowerShell (v5.1+).

C++ and .NET build tools installed (Visual Studio, MSBuild, or Developer Command Prompt).

oscdimg.exe or mkisofs.exe if you plan to generate the optional ghost_boot.iso.

2. Pull or Clone the Repo
bash
Copy
Edit
git clone https://github.com/<YourOrg>/GhostWhisper-Suite.git
cd GhostWhisper-Suite
Ensure you have all subfolders:

GhostKey

WraithTap

Modules

Tools

(Optional) LinuxPDF code for virtualization, if used.

3. Build Everything
From a Developer Command Prompt (for MSVC) or a shell with msbuild in PATH:

Compile GhostKey (C#):

powershell
Copy
Edit
cd .\GhostKey
msbuild GhostKey.csproj /p:Configuration=Release
Compile WraithTap (C++):

powershell
Copy
Edit
cd ..\WraithTap
msbuild WraithTap.vcxproj /p:Configuration=Release /p:Platform=x64
Compile Dropper_with_Raven (optional):

powershell
Copy
Edit
cd ..
cl.exe /EHsc /O2 /Fe:Dropper_with_Raven.exe Dropper_with_Raven.cpp
4. Run the Main Build & Packager
Back at the repo root:

powershell
Copy
Edit
.\BuildDeployWhisper.ps1
This will:

(Re)compile the projects if needed.

Embed the Raven poem (if Dropper_with_Raven.exe is present).

Assemble all scripts, modules, EXEs, and DLLs into a WhisperSuite_Build folder.

5. Deploy to Target / Lab Environment
Copy or move WhisperSuite_Build to a USB drive or a test environment.

On the target machine, open a PowerShell prompt as admin (if possible), then:

powershell
Copy
Edit
cd .\WhisperSuite_Build
6. Launch the Operator Menu
powershell
Copy
Edit
.\GhostWhisperBootstrap.ps1
A menu appears with typical options:

Start Recon (GhostResidency)

ExorcistMode (Anoint, Bind, Cleanse)

Inject GhostKey with WraithTap

Enable Wormhole Listener

Exit

Pick whatever suits your scenario. (For more advanced usage and custom commands, see the references in USAGE.md.)

7. (Optional) Use BLETrigger, GhostLogger, or ExorcistMode
BLETrigger: If you have a phone or Flipper Zero broadcasting as GhostWhisperer, you can run:

powershell
Copy
Edit
.\BLETrigger.ps1
to look for a valid BLE token to trigger memory injection.

GhostLogger: Light activity logging. E.g.:

powershell
Copy
Edit
. .\Modules\GhostLogger.ps1
Write-GhostLog "Beginning operation"
Read-GhostLog -Tail 10
ExorcistMode: If you suspect other malware or want to demonstrate advanced self-cleaning, run:

powershell
Copy
Edit
.\ExorcistMode.ps1 anoint
or

powershell
Copy
Edit
.\ExorcistMode.ps1 bind
or

powershell
Copy
Edit
.\ExorcistMode.ps1 cleanse
8. Cleanup & Safe Exit
When done, run:

powershell
Copy
Edit
.\SilentBloom.ps1
to wipe logs, registry entries, tasks, and any leftover references. If you used any wormhole logic or integrated .ghost.cfg commands, ensure you’ve triggered a final WIPE command to remove all presence.

9. (Advanced) Generating and Using ghost_boot.iso
If you need the advanced LinuxPDF virtualization:

Build the ISO in Tools\CreateGhostISO\:

powershell
Copy
Edit
cd Tools\CreateGhostISO
.\CreateGhostISO.ps1
Ensure ghost_boot.iso is created. Combine that with LinuxPDF.exe if you plan to run advanced Emulated Root Access scanning:

powershell
Copy
Edit
.\LinuxPDF.exe --mode=exorcism --target=C:\Test --offline --log
(Parameters will vary.)

Done! You’re Ghosted.
At this point:

You have an advanced stealth suite for red team simulation.

All modules are loaded from the final build folder.

You can stealthily inject, pivot, log, or exorcise malicious processes, all in a memory-resident manner.

Clean up after yourself with SilentBloom.ps1 or the ExorcistMode’s final cleanse.

Remember: This is for ethical, authorized usage only. If you have any confusion, re-check the disclaimers, code-of-conduct, or license docs. Use responsibly—For Raven.