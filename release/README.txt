oHo-DPi Windows
================

1. start.bat dosyasina cift tikla.
2. Status ciktisinda sunlari gormeyi bekle:
   state: running
   port: reachable
   wininet-proxy-match: yes
3. open-discord.bat ile Discord'u yeniden ac.
4. Isin bitince stop.bat calistir.

Proxy takili kalirsa reset-proxy.bat calistir.

Notlar:
- Bu paket Windows 11 x64 icindir.
- SpoofDPI local proxy olarak 127.0.0.1:18080 uzerinde calisir.
- Windows proxy ayari gecici olarak degistirilir ve stop.bat ile geri alinir.
- Discord yine update ekraninda kalirsa Task Manager'dan Discord/Update processlerini kapatip open-discord.bat'i tekrar dene.
