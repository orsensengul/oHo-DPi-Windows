oHo-DPi Windows
================

ONEMLI:
Zip'in icinden bat dosyasi calistirma.
Once zip'e sag tikla ve "Extract All..." / "Tumunu Ayikla" ile normal bir klasore cikar.

1. Cikan klasoru ac.
2. start.bat dosyasina cift tikla. Bu default mod Npcap gerektirmez.
3. Status ciktisinda sunlari gormeyi bekle:
   state: running
   profile: default
   port: reachable
   wininet-proxy-match: yes
4. open-discord.bat ile Discord'u yeniden ac.
5. Isin bitince stop.bat calistir.

Proxy takili kalirsa reset-proxy.bat calistir.

Discord hala acilmazsa:
1. Npcap kur: https://npcap.com/#download
2. start-aggressive.bat calistir.
3. open-discord.bat ile Discord'u yeniden ac.
4. Aggressive hemen kapanirsa debug-aggressive.bat calistirip ciktisini paylas.

Notlar:
- Bu paket Windows 11 x64 icindir.
- SpoofDPI local proxy olarak 127.0.0.1:18080 uzerinde calisir.
- Windows proxy ayari gecici olarak degistirilir ve stop.bat ile geri alinir.
- Default mod Npcap gerektirmez; aggressive mod Npcap / wpcap.dll gerektirir.
- stop.bat sadece durdurur; ayrintili kontrol icin status.bat calistir.
- Discord yine update ekraninda kalirsa Task Manager'dan Discord/Update processlerini kapatip open-discord.bat'i tekrar dene.
