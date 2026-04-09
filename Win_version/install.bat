@echo off
title Captive Portal Manager Windows Kurulum
color 0A

echo [*] Gerekli Python Kutuphaneleri (requests ve speedtest) yukleniyor...
pip install requests speedtest-cli >nul 2>&1

set "SCRIPT_DIR=%~dp0"
set "VBS_FILE=%SCRIPT_DIR%run_hidden.vbs"

:: Eski gorev varsa sil (Cakisma olmamasi icin)
schtasks /delete /tn "CaptivePortalManager" /f >nul 2>&1

:: Yeni gorevi olustur (Kullanici giris yapinca sessizce baslar)
echo [*] Arka plan servisi olusturuluyor...
schtasks /create /tn "CaptivePortalManager" /tr "\"wscript.exe\" \"%VBS_FILE%\"" /sc onlogon /rl highest

echo [BASARILI] Kurulum tamamlandi. 
echo Servis simdi baslatiliyor...
schtasks /run /tn "CaptivePortalManager"
echo [*] Loglari klasordeki 'internet-login.log' dosyasindan takip edebilirsiniz.
pause