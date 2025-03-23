# WhisperSuite: GhostWhisper Edition  
*A memorial stealth ops framework in honor of Raven.*

WhisperSuite is an advanced memory-resident toolkit for red team operators, blue team simulations, and stealth recon. It integrates command injection, BLE triggers, payload polymorphism, ghost-tag encryption, and operator mission flow into a portable deployment.

---

## ✨ Features

- Memory-only injection via `WraithTap` and `GhostKey`
- BLE-triggered activation with secure handshake
- Payload polymorphism via `GhostPolymorph`
- Per-user `ghostTag` correlation + encryption key rotation
- Custom encryption based on file click timestamps
- Flipper Zero & USB sneakernet deployment
- `GhostBLEConnect` brute-force OBEX transfer
- Hybrid worm logic with:
  - Memory-resident infection mapping
  - Randomized function & module naming
  - Anti-reinfection logic
  - Operator-triggered staging via wrapper module
  - Hard-fail safeguard if no operator detected
- Mission PDF briefings with operator checklist
- Self-destructing DLLs, stealth logging, and AD pivoting

---

## 📂 Components

- `GhostKey.dll` – Memory-resident reflective backdoor
- `WraithTap.exe` – DLL injector for `Shell.exe` or custom targets
- `GhostResidency.ps1` – Operator command handler & control logic
- `GhostPolymorph.ps1` – Runtime polymorphic mutation
- `GhostSeal.ps1` – File encryption engine with timestamp rotation
- `GhostLogger.ps1` – Lightweight ghost-user tracking
- `BLETrigger.ps1` – Proximity-based BLE activation with fallback
- `SilentBloom.ps1` – Clean-up and log wiping
- `Dropper_with_Raven.exe` – Poetic payload marker
- `BuildDeployWhisper.ps1` – Master compiler and packager
- `wormhole.psm1` – Hybrid worm logic module (fileless, memory-only)

---

## 🛡️ Operational Design

- Operates under stealth-first, memory-only principles
- Beacon activation via BLE or internal command
- Polymorphic worm module uses entropy-based infection pathing
- Logs infection in-memory to prevent reinfection
- Self-destruct on mission complete or anomaly
- No action unless operator presence is confirmed
- Designed to pierce silence, not replicate unchecked

---

## ⚠️ Legal & Ethical Notice

This project is provided **for educational, red teaming, and research simulation** purposes only.  
Any **unauthorized use, real-world deployment, or malicious action** violates the intended use and spirit of this memorial project.

> *Dedicated to Raven — who whispered back.*  
> For her memory. For the silence. For the dark it moves through.

Last updated: 2025-03-23

