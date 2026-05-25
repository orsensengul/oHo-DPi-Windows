@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0oHo-DPi.ps1" (
  echo [oHo-DPi] oHo-DPi.ps1 bulunamadi.
  echo [oHo-DPi] Zip dosyasinin icinden calistirma. Once zip'e sag tikla, "Extract All..." / "Tumunu Ayikla" ile klasore cikar.
  echo [oHo-DPi] Sonra cikan klasordeki start.bat dosyasina cift tikla.
  echo.
  pause
  exit /b 1
)
echo [oHo-DPi] Starting SpoofDPI and enabling Windows proxy...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" start
echo.
echo [oHo-DPi] Current status:
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" status
echo.
pause
