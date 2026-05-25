@echo off
setlocal
cd /d "%~dp0"
echo [oHo-DPi] Stopping SpoofDPI and restoring proxy...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" stop
echo.
echo [oHo-DPi] Current status:
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" status
echo.
pause
