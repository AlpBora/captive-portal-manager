#!/opt/homebrew/bin/bash

# Fonksiyonları yükle
source "$HOME/captive-portal-manager/login_functions.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

Network_Name="Ankara Buyuksehir WiFi"

# Captive portal URLs (customizable)
CAPTIVE_PORTAL_LOGIN_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/dynamic/authenticate"
CAPTIVE_PORTAL_SUMMARY_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/account-summary"
CAPTIVE_PORTAL_USER_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/generic/basic-session"
CAPTIVE_PORTAL_LOGOUT_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/logout"


accounts=(
  "5075778738 tr Feanor25"
  "5300802708 tr Alpbora2708"
  "620491898 nl riKjyv-3sacsi"
  "7412984545 gb Feanor25"
  "7577225734 gb Feanor25"
  "7598328098 gb Feanor25"
  "612776705 nl Feanor25"
) #phone number - country code - password


logged_in_user="unknown"
speedtest_download="—"
success=0
now=$(date +%s)
last_update_time=$now

interval_check=5

while true; do
  now=$(date +%s)
  
  if check_internet; then # internet var

    if (( now - last_update_time >= 1200 )); then
      update
      last_update_time=$now
    fi

    sleep $interval_check

  else # internet baglantisi yokken
      
    if ! is_wifi_connected ; then
        
      echo "$(date): ❌ İnternet bağlantısı yok, baglantı bekleniyor..."
      write_log "-" "offline" "—" "—"
      connect_wifi
      
      while true; do
        if is_wifi_connected; then
          echo "Wifi baglandi login bekleniyor"

          # İnternetin gelmesini bekle 
          max_wait=9
          waited=0
          internet_ready=0
          while (( waited < max_wait )); do
            if check_internet; then
              internet_ready=1
              break
            fi
            sleep 3
            waited=$((waited + 3))
            echo "İnternet henüz yok, $waited saniye bekledi..."
          done

          if (( internet_ready == 1 )); then
            remaining_quota=$(get_quota)
            logged_in_user=$(get_user_info)
            echo "$(date): 🌐 İnternet tekrar bağlandı."
            echo "Kullanıcı: $logged_in_user"
            echo "📶 Kalan kota: $remaining_quota MB"
            write_log "$logged_in_user" "online" "$remaining_quota" "-"
            do_speedtest 
            write_log "$logged_in_user" "online" "$remaining_quota" "$speedtest_download"
            success=1
            break 2  # Hem bu loop hem while true'dan çık

          else

            tryTologin "${accounts[@]}"

            if [ $success -eq 0 ]; then
              echo "Hiçbir hesapla internet açılmadı."
              echo " Wifi kapalı olabilir"

              echo "Wifi acip baglanma deneniyor..."
              networksetup -setairportpower en0 on
              networksetup -setairportnetwork en0 "$Network_Name"
            fi

            sleep $interval_check
          fi
        fi
      done
    else
      tryTologin "${accounts[@]}"
    fi
  fi

  sleep 2  # CPU kullanımını düşürmek için
done

