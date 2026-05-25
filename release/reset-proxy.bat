@echo off
setlocal
cd /d "%~dp0"
echo [oHo-DPi] Resetting Windows proxy settings managed by oHo-DPi...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" reset-proxy
echo.
pause
