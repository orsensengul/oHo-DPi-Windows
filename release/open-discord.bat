@echo off
setlocal
cd /d "%~dp0"
echo [oHo-DPi] Opening Discord through the prepared proxy environment...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" open-discord
echo.
pause
