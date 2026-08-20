#!/bin/bash

# Argüman verilmediyse varsayılan 50/50, verildiyse girilen yüzdeyi alır ($1)
ETH_WEIGHT=${1:-50}

if [ "$EUID" -ne 0 ]; then
  echo "[-] Bu betiği 'sudo' ile çalıştırmalısınız: sudo bash load_balancing.sh [ETH_YUZDESI]"
  exit 1
fi

if [ "$ETH_WEIGHT" -lt 0 ] || [ "$ETH_WEIGHT" -gt 100 ]; then
  echo "[-] Lütfen 0 ile 100 arasında bir yüzde değeri girin."
  exit 1
fi

WIFI_WEIGHT=$(( 100 - ETH_WEIGHT ))

echo "[*] Eski PF kuralları temizleniyor..."
pfctl -F all 2>/dev/null
pfctl -d 2>/dev/null

WIFI_IF=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
WIFI_IF=${WIFI_IF:-en0}
WIFI_GW=$(netstat -rn -f inet | grep default | grep "$WIFI_IF" | awk '{print $2}' | head -n 1)

ETH_IF=""
ETH_GW=""

for iface in $(ifconfig -l); do
    if [ "$iface" != "$WIFI_IF" ] && [ "$iface" != "lo0" ]; then
        IF_IP=$(ifconfig "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}')
        if [ -n "$IF_IP" ]; then
            GW=$(netstat -rn -f inet | grep "$iface" | grep -E 'default|UGs|link#' | awk '{print $2}' | head -n 1)
            if [ -z "$GW" ] || [[ "$GW" == *":"* ]]; then
                GW=$(route -n get default -ifp "$iface" 2>/dev/null | grep gateway | awk '{print $2}')
            fi

            if [ -n "$GW" ]; then
                ETH_IF=$iface
                ETH_GW=$GW
                break
            fi
        fi
    fi
done

if [ -z "$ETH_IF" ] || [ -z "$ETH_GW" ]; then
    echo "[-] Aktif Ethernet arabirimi veya Gateway bulunamadı!"
    exit 1
fi

# -------------------------------------------------------------
# macOS Sistem Önceliği (Priority / Service Order) Ayarı
# -------------------------------------------------------------
if [ "$ETH_WEIGHT" -gt 50 ]; then
    echo "[*] macOS Ağ Sıralaması: Ethernet Öncelikli ayarlanıyor..."
    networksetup -ordernetworkservices "Ethernet" "Wi-Fi" 2>/dev/null
else
    echo "[*] macOS Ağ Sıralaması: Wi-Fi/Eşit Öncelikli ayarlanıyor..."
    networksetup -ordernetworkservices "Wi-Fi" "Ethernet" 2>/dev/null
fi

echo "[+] Ethernet ($ETH_IF): GW: $ETH_GW | Oran: %$ETH_WEIGHT"
echo "[+] Wi-Fi    ($WIFI_IF): GW: $WIFI_GW | Oran: %$WIFI_WEIGHT"

PF_CONF="/tmp/pf_loadbalance.conf"

echo "ext_if1 = \"$ETH_IF\"" > "$PF_CONF"
echo "ext_if2 = \"$WIFI_IF\"" >> "$PF_CONF"
echo "gw1 = \"$ETH_GW\"" >> "$PF_CONF"
echo "gw2 = \"$WIFI_GW\"" >> "$PF_CONF"
echo "" >> "$PF_CONF"
echo "pass out quick proto { tcp, udp } to port 53" >> "$PF_CONF"
echo "pass out quick to 10.0.0.0/8" >> "$PF_CONF"
echo "pass out quick to 172.16.0.0/12" >> "$PF_CONF"
echo "pass out quick to 192.168.0.0/16" >> "$PF_CONF"
echo "" >> "$PF_CONF"
echo "pass out all keep state" >> "$PF_CONF"

# PF Probability (Olasılık) ile dynamic yük dengeleme kuralı
if [ "$ETH_WEIGHT" -eq 100 ]; then
    echo 'pass out route-to ( $ext_if1 $gw1 ) proto { tcp, udp } from any to any' >> "$PF_CONF"
elif [ "$ETH_WEIGHT" -eq 0 ]; then
    echo 'pass out route-to ( $ext_if2 $gw2 ) proto { tcp, udp } from any to any' >> "$PF_CONF"
else
    PROB_DECIMAL=$(awk "BEGIN {print $ETH_WEIGHT/100}")
    echo "pass out route-to ( \$ext_if1 \$gw1 ) probability $PROB_DECIMAL proto { tcp, udp } from any to any keep state" >> "$PF_CONF"
    echo "pass out route-to ( \$ext_if2 \$gw2 ) proto { tcp, udp } from any to any keep state" >> "$PF_CONF"
fi

sysctl -w net.inet.ip.forwarding=1 > /dev/null
pfctl -e -f "$PF_CONF" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "[+] Yük dengeleme aktif! Oran: %$ETH_WEIGHT Ethernet / %$WIFI_WEIGHT Wi-Fi"
fi

while true; do
  eth_in=$(netstat -I "$ETH_IF" -b | awk 'NR==2 {print $7}')
  wifi_in=$(netstat -I "$WIFI_IF" -b | awk 'NR==2 {print $7}')
  sleep 1
  eth_in2=$(netstat -I "$ETH_IF" -b | awk 'NR==2 {print $7}')
  wifi_in2=$(netstat -I "$WIFI_IF" -b | awk 'NR==2 {print $7}')
  eth_speed=$(( (eth_in2 - eth_in) / 1024 ))
  wifi_speed=$(( (wifi_in2 - wifi_in) / 1024 ))
  total_speed=$(( eth_speed + wifi_speed ))

  printf "Ethernet : %5d KB/s | Wi-Fi : %5d KB/s ===> TOPLAM: %6d KB/s\n" "$ETH_IF" "$eth_speed" "$WIFI_IF" "$wifi_speed" "$total_speed"
done