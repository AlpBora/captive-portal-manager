import os
import sys
import time
import json
import requests
import subprocess
import re
from datetime import datetime
import urllib3

# SSL Uyarılarını gizle
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- AYARLAR ---
NETWORK_NAME = "Ankara Buyuksehir WiFi"
CAPTIVE_PORTAL_LOGIN_URL = "https://ankarabbld.wifiprofesyonel.com/api/portal/dynamic/authenticate"
CAPTIVE_PORTAL_SUMMARY_URL = "https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/account-summary"
CAPTIVE_PORTAL_USER_URL = "https://ankarabbld.wifiprofesyonel.com/api/portal/generic/basic-session"
CAPTIVE_PORTAL_LOGOUT_URL = "https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/logout"

# Dosya yolları (Arka planda çalışırken doğru yeri bulması için)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(BASE_DIR, "internet-login.log")

# VPN Uygulamalarının Windows'taki Exe adları
VPN_APPS = ["X-VPN.exe", "TunnelBear.exe"]

# Hesaplar (phone number - country code - password)
ACCOUNTS = [
    ("5075778738", "tr", "Feanor25"),
    ("5300802708", "tr", "Alpbora2708"),
    ("620491898", "nl", "riKjyv-3sacsi"),
    ("7412984545", "gb", "Feanor25"),
    ("7577225734", "gb", "Feanor25"),
    ("7598328098", "gb", "Feanor25"),
    ("612776705", "nl", "Feanor25")
]

# Durum Değişkenleri
logged_in_user = "unknown"
speedtest_download = "—"
quota_exhausted = []
interval_check = 5
max_attempts = 3

# Çerez(Cookie) yönetimi için Requests Session
session = requests.Session()

def write_log(log_user, log_status, log_remaining, log_download):
    """Log dosyasına Mac'teki formatın birebir aynısıyla yazar."""
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        if log_status == "online":
            f.write(f"🌐 User: {log_user} | Internet: Online | 📶 Remaining: {log_remaining} MB | ⬇️ Download: {log_download} Mbit/s\n")
        else:
            f.write("❌ Internet: Offline | 📶 Remaining: — MB | ⬇️ Download: —\n")

def get_user_info():
    try:
        res = session.get(CAPTIVE_PORTAL_USER_URL, timeout=5, verify=False)
        if res.status_code == 200:
            return res.json().get("username", "unknown")
    except:
        pass
    return "unknown"

def check_internet():
    try:
        requests.get("https://www.google.com", timeout=5)
        return True
    except:
        return False

def check_internet_stable():
    global fail_count
    tries = 0
    while tries < 3:
        if check_internet():
            return True
        tries += 1
        time.sleep(5)
    return False

def get_quota():
    try:
        res = session.get(CAPTIVE_PORTAL_SUMMARY_URL, timeout=5, verify=False)
        if res.status_code == 200:
            return res.json().get("products", [{}])[0].get("remainingQuota", 0)
    except:
        pass
    return 0

def do_speedtest():
    global speedtest_download
    speedtest_download = "—"
    try:
        # pip install speedtest-cli gerektirir
        result = subprocess.run(["speedtest-cli", "--simple"], capture_output=True, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        output = result.stdout
        
        ping_match = re.search(r"Ping:\s+([0-9.]+)\s+ms", output)
        down_match = re.search(r"Download:\s+([0-9.]+)\s+Mbit/s", output)
        up_match = re.search(r"Upload:\s+([0-9.]+)\s+Mbit/s", output)

        ping_val = ping_match.group(1) if ping_match else "—"
        down_val = down_match.group(1) if down_match else "—"
        up_val = up_match.group(1) if up_match else "—"

        print(f"🏓 Ping: {ping_val} ms")
        print(f"⬇️  Download: {down_val} Mbit/s")
        print(f"⬆️  Upload: {up_val} Mbit/s")
        
        speedtest_download = down_val
    except:
        speedtest_download = "—"

def is_vpn_active():
    """Windows'ta görev yöneticisine bakarak VPN açık mı kontrol eder."""
    try:
        output = subprocess.check_output('tasklist', text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        for app in VPN_APPS:
            if app in output:
                return True
        return False
    except:
        return False

def wait_for_vpn_disconnect():
    print(f"{datetime.now()}: ⏳ VPN kopmasını bekliyorum...")
    while is_vpn_active():
        time.sleep(5)
    print(f"{datetime.now()}: 🔌 VPN bağlantısı koptu.")
    # Uygulamaları zorla kapat (Mac'teki osascript quit karşılığı)
    for app in VPN_APPS:
        subprocess.run(['taskkill', '/F', '/IM', app], capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)

def update():
    global logged_in_user
    if is_vpn_active():
        print(f"{datetime.now()}: ⚠️ VPN bağlı.")
        wait_for_vpn_disconnect()

    remaining_quota = get_quota()
    logged_in_user = get_user_info()
    print(f"{datetime.now()}: 🌐 İnternet bağlantısı aktif.")
    print(f"Kullanıcı: {logged_in_user}")
    print(f"📶 Güncel kota: {remaining_quota} MB")
    do_speedtest()
    write_log(logged_in_user, "online", remaining_quota, speedtest_download)

def is_wifi_connected():
    """Windows'ta ağa bağlı mı kontrol eder."""
    try:
        output = subprocess.check_output('netsh wlan show interfaces', text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        if "State" in output and "connected" in output and NETWORK_NAME in output:
            return True
        return False
    except:
        return False

def connect_wifi():
    """Windows'ta Wi-Fi'a bağlanmayı dener."""
    if not is_wifi_connected():
        print("Ağa bağlanılıyor...")
        subprocess.run(f'netsh wlan connect name="{NETWORK_NAME}"', shell=True, capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        time.sleep(2)

def login(phone, country, password):
    global logged_in_user
    payload = {
        "gsmNo": {
            "localGsmNo": phone,
            "gsmNoCountry": country
        },
        "password": password
    }
    
    session.cookies.clear()
    
    try:
        res = session.post(CAPTIVE_PORTAL_LOGIN_URL, json=payload, timeout=10, verify=False)
        if res.status_code == 200:
            print(f"Login başarılı! Kullanıcı: {phone}")
            remaining_quota = get_quota()
            print(f"📶 Kalan kota: {remaining_quota} MB")
            logged_in_user = phone
            write_log(logged_in_user, "online", remaining_quota, "-")
            return True
    except:
        pass
    
    session.cookies.clear()
    return False

def logout():
    try:
        res = session.get(CAPTIVE_PORTAL_LOGOUT_URL, timeout=5, verify=False)
        if res.status_code == 200:
            session.cookies.clear()
            print("Logout yapıldı.")
            return True
    except:
        pass
    return False

def try_to_login():
    global quota_exhausted
    between_accounts_delay = 5

    if is_vpn_active():
        print(f"{datetime.now()}: ⚠️ VPN bağlı.")
        wait_for_vpn_disconnect()

    print(f"{datetime.now()}: ❌ İnternet bağlantısı koptu, login deneniyor...")
    write_log("-", "offline", "—", "—")

    i = 0
    fail = 0
    while i < len(ACCOUNTS):
        phone, country, password = ACCOUNTS[i]

        if phone in quota_exhausted:
            i += 1
            continue

        if login(phone, country, password):
            remaining_quota = get_quota()

            if remaining_quota == 0 or remaining_quota == "0" or remaining_quota == None:
                print("Kota dolu. Logout yapılıyor ve diğer hesaba geçiliyor.")
                logout()
                quota_exhausted.append(phone)
                continue

            if check_internet_stable():
                break  # Başarılı, döngüden çık
            else:
                if fail == 1:
                    print(f"{phone} Login başarılı ama internet yok, sonraki hesabı dene")
                    fail = 0
                    logout()
                    i += 1
                    continue
                else:
                    print(f"{phone} Login başarılı ama internet yok, hesabı tekrar dene")
                    fail = 1
                    logout()
                    continue
        else:
            if fail == 0:
                print(f"{phone} Login olamadı, aynı hesap bir kez daha deneniyor")
                fail = 1
                continue
            else:
                print(f"{phone} İkinci deneme de tutmadı, sonraki hesaba geç")
                fail = 0
                i += 1
                continue
        
        time.sleep(between_accounts_delay)

def main():
    now_time = int(time.time())
    last_update_time = now_time
    hourly_update_time = now_time

    while True:
        now_time = int(time.time())
        internet_ready = 1 if check_internet() else 0

        if internet_ready == 1:
            if (now_time - last_update_time) >= 1200:
                update()
                last_update_time = now_time
                internet_ready = 1 if check_internet_stable() else 0

            if (now_time - hourly_update_time) >= 3660:
                update()
                hourly_update_time = now_time
                internet_ready = 1 if check_internet_stable() else 0

            time.sleep(30)
        else:
            if not is_wifi_connected():
                print(f"{datetime.now()}: ❌ İnternet bağlantısı yok, bağlantı bekleniyor...")
                write_log("-", "offline", "—", "—")

                attempts = 0
                while True:
                    connect_wifi()
                    if is_wifi_connected():
                        print("Wi-Fi başarıyla bağlandı! login bekleniyor")
                        break
                    attempts += 1
                    print(f" Wifi bağlantı başarısız, tekrar denenecek ({attempts}/{max_attempts})...")
                    time.sleep(2)

            internet_ready = 1 if check_internet_stable() else 0

            if internet_ready == 1:
                update()
                continue

            print("Internet yok, bekleniyor...")
            time.sleep(3)
            internet_ready = 1 if check_internet() else 0

            if internet_ready == 1:
                update()
                continue

            print("Hâlâ yok, login deneniyor...")
            try_to_login()

            internet_ready = 1 if check_internet() else 0

            if internet_ready == 0:
                print("Hiçbir hesapla internet açılmadı. Restart...")
                logout()
                time.sleep(8)
                sys.exit(1)
            else:
                update()

        time.sleep(interval_check)

if __name__ == "__main__":
    main()