# oHo-DPi Windows 11 CLI

Windows 11 icin oHo-DPi v1, macOS uygulamasindaki mantigin CLI karsiligidir:

- SpoofDPI local HTTP proxy olarak `127.0.0.1:18080` uzerinde calisir.
- Windows WinINET system proxy ayari bu local proxy'ye yonlendirilir.
- Admin olarak calisirsa WinHTTP proxy de ayni adrese cekilir.
- Discord desktop update/login akisi proxy hazirken yeniden baslatilir.

Bu surum UI/tray degildir. Once Superonline gibi GoodbyeDPI'nin calismadigi hatlarda temiz SpoofDPI denemesi yapmak icindir.

## Gereksinimler

- Windows 11
- PowerShell 5.1 veya PowerShell 7
- `spoofdpi.exe`

Not: SpoofDPI `v1.5.3` release asset listesinde Windows binary gorunmuyor. Bu nedenle v1 CLI, binary'yi otomatik indirmez. Asagidaki yollardan biri gerekir:

1. `windows/vendor/spoofdpi.exe`
2. `%LOCALAPPDATA%\oHo-DPi\bin\spoofdpi.exe`
3. `PATH` icinde `spoofdpi.exe`

## Kullanım

PowerShell'i repo kokunde ac:

```powershell
cd .\windows
.\oHo-DPi.ps1 status
```

Komutlar:

```powershell
.\oHo-DPi.ps1 install
.\oHo-DPi.ps1 start
.\oHo-DPi.ps1 status
.\oHo-DPi.ps1 open-discord
.\oHo-DPi.ps1 stop
.\oHo-DPi.ps1 restart
.\oHo-DPi.ps1 reset-proxy
```

Execution policy sorun cikarirsa:

```powershell
powershell -ExecutionPolicy Bypass -File .\oHo-DPi.ps1 status
```

## Dosya Konumları

Runtime:

```text
%APPDATA%\oHo-DPi\spoofdpi.discord.toml
%APPDATA%\oHo-DPi\spoofdpi.pid
%APPDATA%\oHo-DPi\spoofdpi.log
%APPDATA%\oHo-DPi\spoofdpi.err.log
%APPDATA%\oHo-DPi\wininet-proxy-backup.json
```

Binary:

```text
%LOCALAPPDATA%\oHo-DPi\bin\spoofdpi.exe
```

## Durum Mantığı

`status` authoritative state basar:

- `state: not-installed`: `spoofdpi.exe` bulunamadi.
- `state: stopped`: SpoofDPI kurulu ama process, port ve proxy kapali.
- `state: running`: process var, `127.0.0.1:18080` reachable ve WinINET proxy eslesiyor.
- `state: degraded`: process, port veya proxy arasinda uyumsuzluk var.

## Proxy Davranışı

- `start`, mevcut WinINET proxy ayarini ilk calistirmada yedekler.
- `stop`, yedegi geri yukler.
- `reset-proxy`, SpoofDPI calismasa bile proxy ayarini yedekten geri almaya calisir.
- Admin olarak calisirsa WinHTTP proxy de set/reset edilir.

WinINET ayari cogu Windows uygulamasi ve Electron uygulamasi icin yeterli olabilir. Discord desktop bu ayari bypass ederse v2 icin process-level proxy veya TUN/proxy fallback gerekir.

## Discord Test Akışı

1. `.\oHo-DPi.ps1 status`
2. `.\oHo-DPi.ps1 start`
3. `.\oHo-DPi.ps1 status`
4. `Invoke-WebRequest -Proxy http://127.0.0.1:18080 https://updates.discord.com`
5. `.\oHo-DPi.ps1 open-discord`
6. Discord update/login sonucunu kontrol et.
7. Isin bitince `.\oHo-DPi.ps1 stop`

## Sorun Giderme

- `state: not-installed`: `spoofdpi.exe` dosyasini vendor, local bin veya PATH konumlarindan birine koy.
- `state: degraded`: `status` ciktisindaki process/port/proxy satirlarini karsilastir.
- Internet proxy'de takili kalirsa `.\oHo-DPi.ps1 reset-proxy` calistir.
- Port `18080` doluysa CLI baska process'i oldurmez; once cakismayi elle coz.
- Discord yine update ekraninda kalirsa Discord'u Task Manager'dan tamamen kapatip `open-discord` ile yeniden baslat.

## v2 Notları

Basarisiz olursa siradaki denemeler:

- `socks5` mode
- Discord icin process-level proxy fallback
- SpoofDPI Windows TUN gercekci hale gelirse TUN profili
- GitHub Actions ile Windows `spoofdpi.exe` artifact uretimi
