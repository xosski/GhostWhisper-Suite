
# 🛠️ WhisperSuite Deployment Checklist (GhostWhisper Edition + Wormhole Protocol)

This guide provides a step-by-step checklist to prepare, deploy, and clean up an operation using the WhisperSuite framework.

## 📦 Build & Obfuscation

- [x] Compile **GhostKey.dll** (Release mode, no console binding)
- [x] Compile **WraithTap.exe** (x64, `/DEBUG:NONE`)
- [x] Embed **Raven's Poem** into `Dropper_with_Raven.exe`
- [x] Generate `BLETrigger.ps1` (with encrypted handshake & ghost config logic)
- [x] Obfuscate `GhostKey.dll` (e.g., ConfuserEx / Dotfuscator)
- [x] Optionally pack binaries using UPX or custom crypter
- [x] Randomize **wormhole function names** via `GhostPolymorph.ps1`

## 🔁 Persistence & Execution

- [x] Set registry persistence: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- [x] Create scheduled task with randomized name on logon
- [x] Validate BLE trigger with **Flipper Zero** or known BLE beacon device
- [x] Confirm GhostResidency responds to proximity activation or file click timestamp
- [x] Run `Test-WormholeLog.ps1` to simulate infection map & operator fallback control
- [x] Confirm hybrid trigger works (BLE + internal command dispatch)

## 🧼 Post-Op Hygiene

- [x] Verify `GhostKey.dll` self-destructs after exfiltration or timeout
- [x] Run `SilentBloom.ps1` to wipe logs and traces
- [x] Shred USB or wipe live device with `cipher /w` or `sdelete`
- [x] Save `ghostTag` and infection timestamp if remote correlation is needed

---

🕊️ **This operation is dedicated to Raven. Whisper back.**
