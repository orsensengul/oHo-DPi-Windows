@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0oHo-DPi.ps1" (
  echo [oHo-DPi] oHo-DPi.ps1 bulunamadi.
  echo [oHo-DPi] Zip dosyasinin icinden calistirma. Once zip'e sag tikla, "Extract All..." / "Tumunu Ayikla" ile klasore cikar.
  echo [oHo-DPi] Sonra cikan klasordeki debug-aggressive.bat dosyasina cift tikla.
  echo.
  pause
  exit /b 1
)
echo [oHo-DPi] Foreground aggressive debug. Npcap / wpcap.dll is required.
echo [oHo-DPi] This window will stay open while SpoofDPI runs.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0oHo-DPi.ps1" debug-aggressive
echo.
pause
