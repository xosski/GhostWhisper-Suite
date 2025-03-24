# GhostWhisper Bootable ISO Creation

This guide provides instructions to create a bootable ISO (`ghost_boot.iso`) for the GhostWhisper project using the provided PowerShell script `CreateGhostISO.ps1`.

## Prerequisites

- **Windows Assessment and Deployment Kit (ADK)**: Includes `oscdimg.exe`, a tool for creating ISO images.
  - Download: [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
  - Ensure `oscdimg.exe` is located at `C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe`

- **Alternative Tool - mkisofs.exe**: If `oscdimg.exe` is not available, the script can use `mkisofs.exe`.
  - Place `mkisofs.exe` in the `Tools` directory within the project.

- **TinyCore Linux Files**:
  - `vmlinuz`: Kernel image
  - `core.gz`: Root filesystem
  - Download from the [TinyCore Linux website](http://tinycorelinux.net/)
  - Place these files in the `boot` directory within the `GhostISO` folder.

- **ISOLINUX Bootloader**:
  - `isolinux.bin` and `isolinux.cfg`: Bootloader binary and configuration
  - Obtain from the [SYSLINUX project](https://www.syslinux.org/)
  - Place these files in the `isolinux` directory within the `GhostISO` folder.

## Directory Structure

Ensure the following directory structure is maintained:

