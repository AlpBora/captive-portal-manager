#!/bin/bash

# Fonksiyonları yükle (Router'da dosyaların bulunduğu yol)
source "/usr/bin/login_functions.sh"

export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

accounts=(
 
  "5075778738 tr Feanor25"
  "5300802708 tr Alpbora2708"
  "620491898 nl riKjyv-3sacsi"
  "7412984545 gb Feanor25"
  "7577225734 gb Feanor25"
  "7598328098 gb Feanor25"
  "612776705 nl Feanor25"
  "5552361750 tr Ortunc@1"
  "5426941737 tr Ortunc@1"
   #"phone number - country code - password"
) 


logged_in_user="unknown"
success=0
interval_check=10
attempts=0
max_attempts=3
now=$(date +%s)
last_update_time=$((now - 2400)) # Zamanı 40 dakika geriye sararak başlat


# 1. Dosya boyut kontrolü
if [ -f /tmp/login_wifi.log ] && [ $(stat -c%s /tmp/login_wifi.log 2>/dev/null || echo 0) -gt 204800 ]; then
    > /tmp/login_wifi.log
fi

# 2. En net, en sade ve asla çift yazmayan klasik yönlendirme
exec >> /tmp/login_wifi.log 2>&1


while true; do
  check_internet && internet_ready=1 || internet_ready=0

  if [ "$internet_ready" -eq 1 ]; then
  # internet VAR
  
    if [ $(( $(date +%s) - last_update_time )) -ge 2400 ]; then
        last_update_time=$(date +%s)
        update
        check_internet_stable && internet_ready=1 || internet_ready=0
    fi

    sleep 10

  else # internet baglantisi yokken

    check_internet_stable && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 1 ]; then
      update 
      success=1
      continue
    fi
    echo "$(date): ❌ İnternet bağlantısı koptu, bekleniyor..."
    sleep 3
    check_internet && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 1 ]; then
      update 
      success=1
      continue
    fi

    echo "Hâlâ yok, login deneniyor..."
    tryTologin "${accounts[@]}"
    sleep 3

    check_internet && internet_ready=1 || internet_ready=0

    if [ "$internet_ready" -eq 0 ]; then
      echo "$(date): ❌ Hiçbir hesapla internet açılmadı. Script sıfırdan yeniden başlatılıyor (Restart)..."
      logout
      sleep 3
      
      # Script'i kendi üzerinde sıfırdan baştan başlatır
      exec "$0" "$@"
    else
      success=1
    fi
    
  fi

  sleep $interval_check  # CPU kullanımını düşürmek için
done

