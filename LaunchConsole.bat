@echo off
:: GhostWhisper Suite - Console Launcher
:: Launches the GUI console with admin privileges

echo.
echo  ================================================
echo     GhostWhisper Suite - Raven Edition
echo  ================================================
echo.

:: Check for admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [*] Starting GhostConsole...
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "GhostConsole.ps1"
