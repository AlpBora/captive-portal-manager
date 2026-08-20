#!/bin/bash

Network_Name="Ankara Buyuksehir WiFi"

# Captive portal URLs
CAPTIVE_PORTAL_LOGIN_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/dynamic/authenticate"
CAPTIVE_PORTAL_SUMMARY_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/account-summary"
CAPTIVE_PORTAL_USER_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/generic/basic-session"
CAPTIVE_PORTAL_LOGOUT_URL="https://ankarabbld.wifiprofesyonel.com/api/portal/welcome/logout"

# OpenWrt Yolları (RAM tabanlı /tmp kullanımı)
COOKIE_FILE="/tmp/.wifi_cookie_pointer"
quota_exhausted=()


get_user_info() {
    if [[ -n "$COOKIE_FILE" && -f "$COOKIE_FILE" ]]; then
        local response
        response=$(curl -s -b "$COOKIE_FILE" -c "$COOKIE_FILE" "$CAPTIVE_PORTAL_USER_URL")
        local username
        username=$(echo "$response" | jq -r '.username // "unknown"' 2>/dev/null)
        echo "${username:-unknown}"
    else
        echo "unknown"
    fi
}


check_internet() {
  curl -s --connect-timeout 3 --max-time 5 https://www.google.com >/dev/null
}


check_internet_stable() {
  local tries=0

  while [ "$tries" -lt 3 ]; do
    if check_internet; then
      return 0   # kesin VAR
    fi

    tries=$((tries + 1))
    sleep 2
  done

  return 1       # kesin YOK
}


get_quota() {
    local quota_resp
    if [[ -n "$COOKIE_FILE" && -f "$COOKIE_FILE" ]]; then
        quota_resp=$(curl -s -b "$COOKIE_FILE" -c "$COOKIE_FILE" "$CAPTIVE_PORTAL_SUMMARY_URL")
        echo "$quota_resp" | jq '.products[0].remainingQuota // "null"' 2>/dev/null
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


update() {
  
  remaining_quota=$(get_quota)
  logged_in_user=$(get_user_info)
  
  echo "$(date): 🌐 İnternet bağlantısı aktif."
  echo "Kullanıcı: $logged_in_user"
  echo "📶 Güncel kota: $remaining_quota MB"

  local current_ping="—"
  local quality_text=""

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
    
  echo "🏓 Ping: ${current_ping} ms ($quality_text)"

}


is_logged_in() {

  if [ -z "$COOKIE_FILE" ]; then
    return 1  # Cookie yok, login değil
  fi

  RESPONSE_CODE=$(curl -s -b "$COOKIE_FILE" -o /dev/null -w "%{http_code}" -X GET "$CAPTIVE_PORTAL_SUMMARY_URL")
  if [ "$RESPONSE_CODE" = "200" ]; then
    return 0 # Login olmuş
  else
    return 1  # Login değil
  fi
}


login() {
  local phone=$1
  local country=$2
  local password=$3

  JSON_PAYLOAD=$(printf '{"gsmNo":{"localGsmNo":"%s","gsmNoCountry":"%s"},"password":"%s"}' "$phone" "$country" "$password")

  # Eski çerezi temizle
  rm -f "$COOKIE_FILE"

  # curl -c ile doğrudan sabit çerez dosyasına kaydetsin
  RESPONSE_CODE=$(curl -s -c "$COOKIE_FILE" -w "%{http_code}" -o /dev/null -X POST "$CAPTIVE_PORTAL_LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

  if [ "$RESPONSE_CODE" = "200" ]; then
    echo "Login başarılı! Kullanıcı: $phone"

    remaining_quota=$(get_quota)
    echo "📶 Kalan kota: $remaining_quota MB"
    logged_in_user=$phone
    
    return 0
  else
  #Login başarısız!
    if [[ -n "$COOKIE_FILE" && -f "$COOKIE_FILE" ]]; then
      rm -f "$COOKIE_FILE"
    fi
    return 1
  fi
}

logout() {

  local RESPONSE_CODE=""
  RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -X GET "$CAPTIVE_PORTAL_LOGOUT_URL")
    
  if [ "$RESPONSE_CODE" = "200" ]; then

    if [[ -f "$COOKIE_FILE" ]]; then
        rm -f "$COOKIE_FILE"
    fi

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

  i=0
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
      # Eğer gelen değer null veya boşsa, hata vermemesi için 0 kabul et veya kontrol et
      if [ -z "$remaining_quota" ] || [ "$remaining_quota" = "null" ]; then
        remaining_quota=0
      fi

      if [ $remaining_quota -eq 0 ]; then
        echo "⚠️ Kota dolu. Logout yapılıyor ve diğer hesaba geçiliyor."
        logout
        quota_exhausted+=("$phone")
        continue
      fi

      if check_internet_stable; then
          break  # İşlem başarılı, döngüden çık
      else
          echo "⚠️ $phone Login başarılı ama internet yok, sonraki hesabi dene"
          logout 
          i=$((i+1)) # Bir sonraki hesaba geç
          continue
      fi
    else
      echo "❌ $phone Login olamadi."
      
      # Eğer hâlâ içeride (logged in) görünüyorsak, bu askıdan kaynaklıdır.
      # Hesabı kaybetmeden önce logout olup, AYNI hesabı tekrar deneyelim!
      if is_logged_in; then
          echo "⚠️ Askıda koturum tespit edildi.Logout yap ve tekrar dene."
          logout
          # i değerini artırmıyoruz, döngü aynı i indexinde (aynı hesapla) başa dönecek
          continue
      fi
      
      # Gerçekten login olamadıysa (oturum yoksa), o zaman sıradaki hesaba geçebiliriz
      echo "➡️ Sonraki hesaba geçiliyor..."
      fail=0
      i=$((i+1))
      continue
    fi

    sleep $between_accounts_delay
  done
}
