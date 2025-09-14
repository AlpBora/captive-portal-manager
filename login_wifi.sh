#!/opt/homebrew/bin/bash

# Fonksiyonları yükle
source "$HOME/login_functions.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

accounts=()          # boş array oluştur
accounts+=("1234567890 tr dummyPassword")   # dummy hesap ekle
accounts+=("0987654321 gb dummyPassword")   # başka dummy hesap


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
              networksetup -setairportnetwork en0 "Ankara Buyuksehir WiFi"
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

