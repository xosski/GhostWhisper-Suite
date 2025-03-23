WhisperSuite: GhostWhisper Edition
A memorial stealth ops framework in honor of Raven.

WhisperSuite is an advanced memory-resident toolkit designed for red team operators, blue team simulations, and stealth reconnaissance. It integrates command injection, BLE triggers, payload polymorphism, ghost-tag encryption, hybrid wormhole propagation logic, and structured operator mission flow into a portable deployment.

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

Hybrid wormhole infection module with randomized memory tracking

Per-user ghostTag correlation & rotating encryption keys

Timestamp-based encryption tied to file access events

Flipper Zero & USB sneakernet compatibility

OBEX brute-force support with GhostBLEConnect_v2.ps1

PDF mission briefings and operator checklist generation

Self-destructing DLLs, lightweight logging, and stealth AD pivoting

Operator-gated fallback logic to ensure containment

Fully integrated with GhostLogger.ps1 for activity tracking

📂 Components
GhostKey.dll – Memory-resident reflective backdoor

WraithTap.exe – Shell-targeting DLL injector

GhostResidency.ps1 – Operator memory session handler

GhostPolymorph.ps1 – Runtime mutation module

GhostSeal.ps1 – File encryption engine using click timestamps

GhostLogger.ps1 – Lightweight activity logging and tail review

BLETrigger.ps1 – BLE-triggered remote injection controller

SilentBloom.ps1 – Evidence cleaner & forensic log scrubber

Dropper_with_Raven.exe – Tribute payload wrapper

BuildDeployWhisper.ps1 – Suite builder, polymorph wrapper, wormhole packager

GhostWhisperBootstrap.ps1 – Operator control launcher with module wiring

ExorcistMode.ps1 – Hostile malware removal protocol (Anoint, Bind, Cleanse)

LinuxPDF_Emu.ps1 – Virtualized scanning support with syscall anomaly hooks

AnomalyHunter.ps1 – Rootkit and hypervisor anomaly detection

🧠 Wormhole Logic (BuildDeployWhisper.ps1)
Memory-only propagation, no persistent writes

Infection maps reside only in runtime memory

Prevents duplicate infection on same host

BLE handshake required or fallback to internal GhostResidency control

Operator hard-fail exit logic to ensure ethical operation

Fully traceable through GhostLogger.ps1

⚠️ Legal & Ethical Notice
This project is for educational, research, and ethical red teaming use only.
Unauthorized deployment, malicious replication, or use outside legal boundaries is strictly forbidden.
All contributors and users must uphold ethical use in accordance with local and international laws.

🕊️ Whisper back.
For Raven.
2017 — ∞
