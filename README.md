WhisperSuite: GhostWhisper Edition
A memorial stealth ops framework in honor of Raven.

WhisperSuite is an advanced memory-resident toolkit for red team operators, blue team simulations, and stealth reconnaissance. It integrates command injection, BLE triggers, payload polymorphism, ghost-tag encryption, wormhole propagation logic, structured operator missions, and a virtualized cleansing approach that gives the operator a hidden hand in the dark, orchestrating everything from behind the scenes.

🕳️ The Wormhole Protocol
A stealth-capable propagation model with:

Hybrid defensive triggers (BLE + in-memory coordination)

Operator handshake gating to prevent rogue replication

Volatile memory maps to track infected hosts

SMB fallback & polymorphic payloads

Hard-fail exit logic when no operator is present

✨ Features
Memory-only injection via WraithTap.exe and GhostKey.dll

BLE-triggered activation with secure token handshake

Payload polymorphism via GhostPolymorph.ps1

Hybrid wormhole infection with randomized memory tracking

Per-user ghostTag correlation & rotating encryption keys

Timestamp-based encryption tied to file access events

Flipper Zero & USB sneakernet compatibility

OBEX brute-force support with GhostBLEConnect_v2.ps1

PDF mission briefings and operator checklist generation

Self-destructing DLLs, lightweight logging, stealth AD pivoting

Operator-gated fallback logic to ensure containment

Fully integrated with GhostLogger.ps1 for activity tracking

Advanced Linux virtualization for stealth recon & exorcism flows

📂 Components
GhostKey.dll – Memory-resident reflective backdoor

WraithTap.exe – Shell-targeting DLL injector

GhostResidency.ps1 – Operator memory session handler

GhostPolymorph.ps1 – Runtime mutation module

GhostSeal.ps1 – File encryption engine using click timestamps

GhostLogger.ps1 – Lightweight activity logging and tail review

BLETrigger.ps1 – BLE-triggered remote injection controller

SilentBloom.ps1 – Evidence cleaner & forensic log scrubber

Dropper_with_Raven.exe – Tribute payload wrapper (appends a memorial poem at build time)

BuildDeployWhisper.ps1 – Suite builder, polymorph wrapper, wormhole packager

GhostWhisperBootstrap.ps1 – Operator control launcher with module wiring

ExorcistMode.ps1 – Hostile malware removal protocol (Anoint, Bind, Cleanse)

LinuxPDF_Emu.ps1 / LinuxPDF_Runtime.ps1 – Virtualized scanning with syscall anomaly hooks

AnomalyHunter.ps1 – Rootkit & hypervisor anomaly detection

ghost_boot.iso – Minimal Linux environment for advanced recon & exorcism, built via CreateGhostISO.ps1

LinuxPDF.exe – .NET-based virtualization harness that boots/emulates ghost_boot.iso, enabling stealth operator flow akin to a “hand in the dark”

🧠 Wormhole Logic (BuildDeployWhisper.ps1)
Memory-only propagation, no persistent writes

Infection maps reside only in runtime memory

Prevents duplicate infection on the same host

BLE handshake required or fallback to internal GhostResidency control

Operator hard-fail exit to ensure ethical operation

Fully traceable via GhostLogger.ps1

🚀 Virtualized Cleansing: ghost_boot.iso + LinuxPDF.exe
For ExorcistMode or advanced recon, you can:

Build a minimal ISO (ghost_boot.iso) with CreateGhostISO.ps1.

Launch LinuxPDF.exe in the desired mode (--mode=exorcism, --target=C:\Temp, etc.).

Emulate root-level scanning or stealth exorcism via ephemeral system calls, analyzing or neutralizing threats in isolation.

This approach acts like a “hand in the dark,” granting root-level access from behind the scenes, while preserving your primary host OS and ensuring minimal footprints.

⚠️ Legal & Ethical Notice
This project is for educational, research, and ethical red teaming use only. Unauthorized deployment, malicious replication, or use beyond legal boundaries is strictly forbidden. By using this toolkit, you acknowledge and agree to follow all applicable laws and uphold ethical usage.

All contributors and users must respect local and international regulations, ensuring no harm is done outside sanctioned engagements.

🕊️ Whisper back.
For Raven.
2017 — ∞