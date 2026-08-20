cat << 'EOF' > /etc/init.d/login_wifi
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /bin/bash /usr/bin/login_wifi.sh
    procd_set_param respawn 3600 5 5
    procd_close_instance
}
EOF

## ssh root@192.168.1.1 "/etc/init.d/login_wifi enable"
# chmod +x /etc/init.d/login_wifi
/etc/init.d/login_wifi enable
/etc/init.d/login_wifi start