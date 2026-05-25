# oHo-DPi Windows

Windows 11 icin Discord odakli SpoofDPI deneme paketidir. Amac, Superonline gibi GoodbyeDPI'nin calismadigi hatlarda Discord desktop `update failed` / login akisini temiz bir local proxy denemesiyle test etmektir.

## En Kolay Kullanım

1. GitHub Releases sayfasindan `oHo-DPi-Windows.zip` indir.
2. Zip'i bir klasore cikar.
3. `start.bat` dosyasina cift tikla.
4. Status ciktisinda sunlari gormeyi bekle:

```text
state: running
port: reachable
wininet-proxy-match: yes
```

5. `open-discord.bat` ile Discord'u yeniden ac.
6. Isin bitince `stop.bat` calistir.

Proxy takili kalirsa `reset-proxy.bat` calistir.

## Zip Icerigi

```text
oHo-DPi-Windows/
  start.bat
  stop.bat
  status.bat
  open-discord.bat
  reset-proxy.bat
  oHo-DPi.ps1
  config/spoofdpi.discord.toml
  bin/spoofdpi.exe
  README.txt
```

`spoofdpi.exe` repo'ya commit edilmez. GitHub Actions Windows x64 binary build eder ve release zip'e koyar.

## Bat Dosyaları

- `start.bat`: SpoofDPI'i baslatir, WinINET proxy'yi `127.0.0.1:18080` yapar, admin ise WinHTTP proxy'yi de ayarlar.
- `stop.bat`: SpoofDPI'i durdurur ve proxy ayarlarini geri alir.
- `status.bat`: process, port ve proxy eslesmesini gosterir.
- `open-discord.bat`: Discord'u proxy hazirken kapatip yeniden acar.
- `reset-proxy.bat`: SpoofDPI calismasa bile proxy ayarlarini temizlemeye calisir.

## PowerShell CLI

Zip disinda repo kaynaklariyla calismak istersen:

```powershell
cd .\windows
powershell -ExecutionPolicy Bypass -File .\oHo-DPi.ps1 status
powershell -ExecutionPolicy Bypass -File .\oHo-DPi.ps1 start
powershell -ExecutionPolicy Bypass -File .\oHo-DPi.ps1 open-discord
powershell -ExecutionPolicy Bypass -File .\oHo-DPi.ps1 stop
```

Kaynak modunda `spoofdpi.exe` su konumlardan birinde aranir:

```text
windows/bin/spoofdpi.exe
%LOCALAPPDATA%\oHo-DPi\bin\spoofdpi.exe
windows/vendor/spoofdpi.exe
PATH icinde spoofdpi.exe
```

## Runtime Dosyaları

```text
%APPDATA%\oHo-DPi\spoofdpi.discord.toml
%APPDATA%\oHo-DPi\spoofdpi.pid
%APPDATA%\oHo-DPi\spoofdpi.log
%APPDATA%\oHo-DPi\spoofdpi.err.log
%APPDATA%\oHo-DPi\wininet-proxy-backup.json
```

## Durum Mantığı

- `state: not-installed`: `spoofdpi.exe` bulunamadi.
- `state: stopped`: SpoofDPI kurulu ama process, port ve proxy kapali.
- `state: running`: process var, `127.0.0.1:18080` reachable ve WinINET proxy eslesiyor.
- `state: degraded`: process, port veya proxy arasinda uyumsuzluk var.

## Manuel Test

```powershell
Invoke-WebRequest -Proxy http://127.0.0.1:18080 https://updates.discord.com
```

Bu komut proxy uzerinden Discord update endpoint'ine ulasmayi dener. Son karar yine Discord desktop update/login akisi ile verilir.

## Release Build

Release zip GitHub Actions ile uretilir:

- Manual: Actions > Build Windows release zip > Run workflow
- Tag: `v*` tag push edilirse release asset olarak `oHo-DPi-Windows.zip` yuklenir.

## v2 Notları

Basarisiz olursa siradaki denemeler:

- `socks5` mode
- Discord icin process-level proxy fallback
- SpoofDPI Windows TUN gercekci hale gelirse TUN profili
