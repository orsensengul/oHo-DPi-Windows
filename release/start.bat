@echo off
setlocal
cd /d "%~dp0"
echo [oHo-DPi] Starting SpoofDPI and enabling Windows proxy...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" start
echo.
echo [oHo-DPi] Current status:
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" status
echo.
pause
