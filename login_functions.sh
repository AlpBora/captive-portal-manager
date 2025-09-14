#!/opt/homebrew/bin/bash

COOKIE_FILE="$HOME/captive-portal-manager/.wifi_cookie"
LOGFILE="$HOME/captive-portal-manager/internet-login.log"
cookie_file=""
speedtest_download="-"

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

  if [[ "$log_status" == "online" ]]; then
      echo "🌐 User: $log_user | Internet: Online | 📶 Remaining: ${log_remaining} MB | ⬇️ Download: ${log_download} Mbit/s" > "$LOGFILE"
  else
      echo "❌ Internet: Offline | 📶 Remaining: — MB | ⬇️ Download: —" > "$LOGFILE"
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
  curl -s --max-time 3 https://www.gstatic.com/generate_204 -o /dev/null && return 0
  curl -s --max-time 3 http://10.3.128.1 -o /dev/null && return 0
  return 1
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

do_speedtest() {

  SPEEDTEST="/opt/homebrew/bin/speedtest-cli"
  speedtest_download="—"
  if [ -x "$SPEEDTEST" ]; then
    local speedtest_output ping_value download_value upload_value
    speedtest_output=$("$SPEEDTEST" --simple 2>/dev/null)
    ping_value=$(echo "$speedtest_output" | grep -Eo "Ping: [0-9.]+ ms" | awk '{print $2}')
    download_value=$(echo "$speedtest_output" | grep -Eo "Download: [0-9.]+ Mbit/s" | awk '{print $2}')
    upload_value=$(echo "$speedtest_output" | grep -Eo "Upload: [0-9.]+ Mbit/s" | awk '{print $2}')

    echo "🏓 Ping: ${ping_value:-—} ms" "$ping_value"
    echo "⬇️  Download: ${download_value:-—} Mbit/s" "$download_value"
    echo "⬆️  Upload: ${upload_value:-—} Mbit/s" "$upload_value"
  
    speedtest_download="${download_value:-—}"
  else
    speedtest_download="-"
  fi
}

update(){

  if is_vpn_active; then
      echo "$(date): ⚠️ VPN bağlı."
      wait_for_vpn_disconnect 
  fi

  remaining_quota=$(get_quota)
  logged_in_user=$(get_user_info)
  echo "$(date): 🌐 İnternet bağlantısı aktif."
  echo "Kullanıcı: $logged_in_user"
  echo "📶 Güncel kota: $remaining_quota MB"
  do_speedtest
  write_log "$logged_in_user" "online" "$remaining_quota" "$speedtest_download"
  
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
        sleep 2  # Açılmasını bekle
    fi

    # Wi-Fi açık ama ağa bağlı değilse bağlan
    if ! is_wifi_connected; then
        echo "Ağa, bağlanılıyor..."
        networksetup -setairportnetwork en0 "$ssid"
        sleep 2  # Bağlanmasını bekle
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
    write_log "$logged_in_user" "online" "$remaining_quota" "-"
    if ! [ $remaining_quota -eq 0 ]; then
      do_speedtest
      write_log "$logged_in_user" "online" "$remaining_quota" "$speedtest_download"
    fi

    return 0
  else
    echo "Login başarısız! Kullanıcı: $phone Status code: $RESPONSE_CODE"
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
    echo "Logout basarisiz! HTTP kodu: $RESPONSE_CODE"
    return 1
  fi
}

tryTologin(){
  between_accounts_delay=2
  local accounts=("$@")  # array olarak al

  if is_vpn_active; then
      echo "$(date): ⚠️ VPN bağlı."
      wait_for_vpn_disconnect 
  fi

  echo "$(date): ❌ İnternet bağlantısı koptu, login deneniyor..."
  write_log "-" "offline" "—" "—"

  i=0
  fail=0
  while [ $i -lt ${#accounts[@]} ]; do
    read -r phone country password <<< "${accounts[$i]}"
    if login "$phone" "$country" "$password"; then
        sleep 2
        remaining_quota=$(get_quota)

        if (( remaining_quota == 0 )); then
            echo "Kota dolu. Logout yapılıyor ve diğer hesaba geçiliyor."
            logout
            i=$((i+1))  # Bir sonraki hesaba geç
            continue
        fi

        if check_internet; then
            break  # İşlem başarılı, döngüden çık
        else
            if ["$fail" -eq 1]; then
              echo "Login başarılı ama internet yok, sonraki hesabi dene"
              fail=0
              logout 
              i=$((i+1)) # Bir sonraki hesaba geç
              continue
            else
              echo "Login başarılı ama internet yok, hesabı tekrar dene"
              fail=$((fail + 1))
              logout
              continue
            fi
        fi
    else
        echo "Login başarısız! Kullanıcı: $phone Logout yapılıp tekrar deneniyor."
        if logout; then
          sleep 1
          continue
        else
          echo " Wifi kapalı olabilir veya VPN bagli"

          # demek ki wifi kapali
          connect_wifi
          break
        fi
    fi

    sleep $between_accounts_delay
  done
}
