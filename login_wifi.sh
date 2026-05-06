#!/opt/homebrew/bin/bash

# Fonksiyonları yükle
source "$HOME/captive-portal-manager/login_functions.sh"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

accounts=(

   "phone number - country code - password"
) 



logged_in_user="unknown"
speedtest_download="—"
success=0
interval_check=5
attempts=0
max_attempts=3
now=$(date +%s)
last_update_time=$((now - 1200)) # Zamanı 20 dakika geriye sararak başlat
is_first_run=1 # İlk çalışma bayrağı

while true; do
  now=$(date +%s)
  check_internet && internet_ready=1 || internet_ready=0

  if [ "$internet_ready" -eq 1 ]; then
  # internet VAR
  
    if [ $(( now - last_update_time )) -ge 1200 ]; then

      if [ "$is_first_run" -eq 1 ]; then
        update # İlk açılışta parametresiz çağır (Hız testi yapar)
        is_first_run=0 
      else
        update "--no-speedtest" # Sonrakilerde sadece Ping atar
      fi
      
      last_update_time=$(date +%s)
      check_internet_stable && internet_ready=1 || internet_ready=0
    fi

    sleep 30

  else # internet baglantisi yokken
      
    if ! is_wifi_connected ; then
        echo "$(date): ❌ İnternet bağlantısı yok, baglantı bekleniyor..."
        write_log "-" "offline" "—" "—" "—"
      
      while true; do
        connect_wifi

        # Bağlantı kontrolü
        if is_wifi_connected; then
            echo "Wi-Fi başarıyla bağlandı! login bekleniyor"
            handle_portal_popup
            break
        fi
        echo " Wifi bağlantı başarısız, tekrar denenecek ($attempts/$max_attempts)..."
        sleep 2

      done
    fi

    # İnternetin gelmesini bekle 
    # max_wait=9
    # waited=0
    # while (( waited < max_wait )); do
    #   sleep 3
    #   waited=$((waited + 3))
    #   echo "İnternet henüz yok, $waited saniye bekledi..."
    # done

    check_internet_stable && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 1 ]; then
      update "--no-speedtest"
      success=1
      continue
    fi

    echo "Internet yok, bekleniyor..."
    sleep 3
    check_internet && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 1 ]; then
      update "--no-speedtest"
      success=1
      continue
    fi

    echo "Hâlâ yok, login deneniyor..."
    handle_portal_popup
    tryTologin "${accounts[@]}"
    sleep 3

    check_internet && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 0 ]; then
      echo "Hiçbir hesapla internet açılmadı. Restart..."
      logout
      sleep 3
      exit 1  
    else
      update "--no-speedtest" 
      success=1
    fi
    
  fi

  sleep $interval_check  # CPU kullanımını düşürmek için
done

