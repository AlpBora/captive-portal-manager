#!/opt/homebrew/bin/bash

Network_Name="Ankara Buyuksehir WiFi"

# Captive portal URLs (customizable)
CAPTIVE_PORTAL_LOGIN_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/dynamic/authenticate"
CAPTIVE_PORTAL_SUMMARY_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/account-summary"
CAPTIVE_PORTAL_USER_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/generic/basic-session"
CAPTIVE_PORTAL_LOGOUT_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/logout"

COOKIE_FILE="$HOME/captive-portal-manager/.wifi_cookie"
LOGFILE="$HOME/captive-portal-manager/internet-login.log"
cookie_file=""
speedtest_download="-"
quota_exhausted=()

# for VPN
APP1="X-VPN"
APP2="TunnelBear"

save_cookie() {
  echo "$cookie_file" > "$COOKIE_FILE"
}

load_cookie() {
  if [ -f "$COOKIE_FILE" ]; then
      cookie_file=$(cat "$COOKIE_FILE")
  fi
}


write_log() {
  local log_user="$1"
  local log_status="$2"
  local log_remaining="$3"
  local log_download="$4"
  local log_ping="$5" 
  if [[ "$log_status" == "online" ]]; then
      echo "🌐 User: $log_user | 📶 Kalan: ${log_remaining} MB | ⬇️ Hız: ${log_download} Mbit/s | 🏓 Ping: ${log_ping} " > "$LOGFILE"
  else
      echo "❌ Internet: Offline | 📶 Kalan: — MB | ⬇️ Hız: — | 🏓 Ping: —" > "$LOGFILE"
  fi
}

get_user_info() {

  load_cookie
  if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
    local response
    response=$(curl -s -b "$cookie_file" "$CAPTIVE_PORTAL_USER_URL")
    local username
    username=$(echo "$response" | jq -r '.username // "unknown"')
    echo "$username"
  else
    echo "unknown"
  fi
}

check_internet() {
  curl -s --max-time 5 https://www.google.com >/dev/null
}

fail_count=0

check_internet_stable() {
  tries=0

  while [ "$tries" -lt 3 ]; do
    if check_internet; then
      fail_count=0
      return 0   # kesin VAR
    fi

    tries=$((tries + 1))
    sleep 5
  done

  fail_count=$((fail_count + 1))
  return 1       # kesin YOK
}

get_quota() {
  
  local quota_resp
  load_cookie
  if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
    quota_resp=$(curl -s -b "$cookie_file" "$CAPTIVE_PORTAL_SUMMARY_URL")
    echo "$quota_resp" | jq '.products[0].remainingQuota'
  else
    echo "null"
  fi
}

is_quota_exhausted() {
    local phone="$1"
    for q in "${quota_exhausted[@]}"; do
        [[ "$q" == "$phone" ]] && return 0
    done
    return 1
}

do_speedtest() {
  SPEEDTEST="/opt/homebrew/bin/speedtest-cli"
  speedtest_download="—"
  speedtest_ping="—" 
  
  if [ -x "$SPEEDTEST" ]; then
    local speedtest_output ping_value download_value upload_value
    speedtest_output=$("$SPEEDTEST" --simple 2>/dev/null)
    ping_value=$(echo "$speedtest_output" | grep -Eo "Ping: [0-9.]+ ms" | awk '{print $2}')
    download_value=$(echo "$speedtest_output" | grep -Eo "Download: [0-9.]+ Mbit/s" | awk '{print $2}')
    upload_value=$(echo "$speedtest_output" | grep -Eo "Upload: [0-9.]+ Mbit/s" | awk '{print $2}')

    echo "🏓 Ping: ${ping_value:-—} ms" 
    echo "⬇️  Download: ${download_value:-—} Mbit/s" 
    echo "⬆️  Upload: ${upload_value:-—} Mbit/s" 
  
    speedtest_download="${download_value:-—}"
    speedtest_ping="${ping_value:-—}" 
  else
    speedtest_download="-"
    speedtest_ping="-"
  fi
}

update() {
  local skip_speedtest=$1 

  if is_vpn_active; then
      echo "$(date): ⚠️ VPN bağlı."
      wait_for_vpn_disconnect 
  fi

  remaining_quota=$(get_quota)
  logged_in_user=$(get_user_info)
  
  echo "$(date): 🌐 İnternet bağlantısı aktif."
  echo "Kullanıcı: $logged_in_user"
  echo "📶 Güncel kota: $remaining_quota MB"

  local current_ping="—"
  local quality_text=""

  if [ "$skip_speedtest" != "--no-speedtest" ]; then
    echo "🚀 Hiz ölçülüyor..."
    do_speedtest 
    current_ping="$speedtest_ping"
    # Aktif hız testi yapıldığında kaliteyi hıza göre de yorumlayabilirsin
  else
    # TCP Ping ölçümü
    current_ping=$(curl -o /dev/null -s -w "%{time_connect}\n" https://www.google.com | awk '{print int($1 * 1000)}')
    
    if [ -z "$current_ping" ] || [ "$current_ping" -eq 0 ]; then
        current_ping="—"
        quality_text="(Bağlantı Yok)"
    elif [ "$current_ping" -lt 35 ]; then
        quality_text="(Mükemmel)"
    elif [ "$current_ping" -lt 75 ]; then
        quality_text="(İyi)"
    elif [ "$current_ping" -lt 150 ]; then
        quality_text="(Orta)"
    else
        quality_text="(Kötü)"
    fi
    
    # Hız ölçülmediği için hız kısmına "-" yazıyoruz
    speedtest_download="—"
     # Ekrana basarken ping'in yanına kaliteyi ekle
    echo "🏓 Ping: ${current_ping} ms ($quality_text)"
  fi


  # Log yazarken kaliteyi PİNG kısmına dahil et
  # Format: ... | ⬇️ Hız: — | 🏓 Ping: 29 ms (Mükemmel)
  write_log "$logged_in_user" "online" "$remaining_quota" "$speedtest_download" "${current_ping} ms ${quality_text}"
}


is_logged_in() {
  load_cookie
  if [ -z "$cookie_file" ]; then
    return 1  # Cookie yok, login değil
  fi

  RESPONSE_CODE=$(curl -s -b "$cookie_file" -o /dev/null -w "%{http_code}" -X GET "$CAPTIVE_PORTAL_SUMMARY_URL")
  if [ "$RESPONSE_CODE" = "200" ]; then
    return 0 # Login olmuş
  else
    return 1  # Login değil
  fi
}


handle_portal_popup() {
  osascript -e 'tell application "Captive Network Assistant" to quit' 2>/dev/null
}


# Wi-Fi açık mı kontrol
is_wifi_on() {
    local status
    status=$(networksetup -getairportpower en0 | awk '{print $4}')
    if [ "$status" = "On" ]; then
        return 0  # Wi-Fi açık
    else
        return 1  # Wi-Fi kapalı
    fi
}

is_wifi_connected() {
  local ip
  ip=$(ipconfig getifaddr en0 2>/dev/null)
  if [ -n "$ip" ]; then
    return 0  # WiFi bağlı, IP var
  else
    return 1  # WiFi bağlı değil veya IP yok
  fi
}

# Wi-Fi aç ve bağlan
connect_wifi() {
    local ssid="$Network_Name"
    
    # Wi-Fi kapalıysa aç
    if ! is_wifi_on; then
        echo "Wi-Fi kapalı, açılıyor..."
        networksetup -setairportpower en0 on
        sleep 2
    fi

    # Wi-Fi açık ama ağa bağlı değilse bağlan
    if ! is_wifi_connected; then
        echo "Ağa bağlanılıyor..."
        networksetup -setairportnetwork en0 "$ssid"
        sleep 2
    fi
    
}

is_vpn_active() {
    # macOS için kontrol (TunnelBear, X-VPN vs.)
    scutil --nc list | grep -q "Connected"
}

wait_for_vpn_disconnect() {
  echo "$(date): ⏳ kopmasını bekliyorum..."
  while is_vpn_active; do
    sleep 5
  done
  echo "$(date): 🔌 VPN bağlantısı koptu."
  osascript -e "quit app \"$APP1\""
  osascript -e "quit app \"$APP2\""
}

login() {
  local phone=$1
  local country=$2
  local password=$3

  JSON_PAYLOAD=$(printf '{"gsmNo":{"localGsmNo":"%s","gsmNoCountry":"%s"},"password":"%s"}' "$phone" "$country" "$password")
  
  load_cookie

  if [[ -n "$cookie_file" ]]; then
    rm -f "$cookie_file"
  fi

  cookie_file=$(mktemp)

  RESPONSE_CODE=$(curl -s -c "$cookie_file" -w "%{http_code}" -o /dev/null -X POST "$CAPTIVE_PORTAL_LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
  save_cookie

  if [ "$RESPONSE_CODE" = "200" ]; then
    echo "Login başarılı! Kullanıcı: $phone"

    remaining_quota=$(get_quota)
    echo "📶 Kalan kota: $remaining_quota MB"
    logged_in_user=$phone
    write_log "$logged_in_user" "online" "$remaining_quota" "-" "-"
    
    return 0
  else
  #Login başarısız!
    if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
      rm -f "$cookie_file"
    fi
    cookie_file=""
    save_cookie
    return 1
  fi
}

logout() {
  load_cookie
  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$cookie_file" -X GET "$CAPTIVE_PORTAL_LOGOUT_URL")
  if [ "$RESPONSE_CODE" = "200" ]; then
    if [[ -n "$cookie_file" && -f "$cookie_file" ]]; then
      rm -f "$cookie_file"
    fi
    cookie_file=""
    save_cookie
    echo "Logout yapıldı."
    return 0
  else
  #Logout basarisiz!
    return 1
  fi
}

tryTologin(){
  between_accounts_delay=5
  local accounts=("$@")  # array olarak al

  if is_vpn_active; then
      echo "$(date): ⚠️ VPN bağlı."
      wait_for_vpn_disconnect 
  fi

  echo "$(date): ❌ İnternet bağlantısı koptu, login deneniyor..."
  write_log "-" "offline" "—" "—" "-"

  i=0
  fail=0
  while [ $i -lt ${#accounts[@]} ]; do
    
    set -- ${accounts[$i]}
    phone=$1
    country=$2
    password=$3

    if is_quota_exhausted "$phone"; then
      i=$((i+1))
      continue
    fi

    if login "$phone" "$country" "$password"; then
        
        remaining_quota=$(get_quota)

        if [ $remaining_quota -eq 0 ]; then
            echo "⚠️ Kota dolu. Logout yapılıyor ve diğer hesaba geçiliyor."
            logout
            quota_exhausted+=("$phone")
            continue
        fi

        if check_internet_stable; then
            break  # İşlem başarılı, döngüden çık
        else
            if [ "$fail" -eq 1 ]; then
              echo "⚠️ $phone Login başarılı ama internet yok, sonraki hesabi dene"
              fail=0
              logout 
              i=$((i+1)) # Bir sonraki hesaba geç
              continue
            else
              echo "⚠️ $phone Login başarılı ama internet yok, hesabı tekrar dene"
              fail=1
              logout
              continue
            fi
        fi
    else
        if [ "$fail" -eq 0 ]; then
          echo "❌ $phone Login olamadi, aynı hesap bir kez daha deneniyor"
          fail=1
          continue
        else
          echo "❌ $phone İkinci deneme de tutmadı, sonraki hesaba geç"
          fail=0
          i=$((i+1))
          continue
        fi
      fi

    sleep $between_accounts_delay
  done
}
