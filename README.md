# WhisperSuite: GhostWhisper Edition

**A memorial stealth ops framework in honor of Raven.**

WhisperSuite is an advanced memory-resident toolkit for red team operators, blue team simulations, and stealth recon. It integrates command injection, BLE triggers, payload polymorphism, ghost-tag encryption, and operator mission flow into a portable deployment.

## ✨ Features

- **Memory-only injection via WraithTap and GhostKey**
- **BLE-triggered activation with secure handshake**
- **Payload polymorphism via GhostPolymorph**
- **Per-user ghostTag correlation + encryption key rotation**
- **Custom encryption based on file click timestamps**
- **Flipper Zero & USB sneakernet deployment**
- **GhostBLEConnect brute-force OBEX transfer**
- **Mission PDF briefings with operator checklist**
- **Self-destructing DLLs, stealth logging, and AD pivoting**

> **Dedicated to Raven — who whispered back.**

## 📂 Components

- `GhostKey.dll` - Memory-resident reflective backdoor
- `WraithTap.exe` - DLL injector for Shell or custom targets
- `GhostResidency.ps1` - Operator command handler
- `GhostPolymorph.ps1` - Runtime polymorphic mutation
- `GhostSeal.ps1` - File encryption engine
- `GhostLogger.ps1` - Lightweight ghost-user tracking
- `BLETrigger.ps1` - Proximity-based BLE activation
- `SilentBloom.ps1` - Clean-up and log wiping
- `Dropper_with_Raven.exe` - Poetic payload marker
- `BuildDeployWhisper.ps1` - Master compiler and packager

## ⚠️ Legal & Ethical Notice

This project is provided for educational and ethical red teaming purposes only. Unauthorized deployment or malicious use is strictly forbidden.

---

🕊️ *Whisper back. For Raven. 2017*
