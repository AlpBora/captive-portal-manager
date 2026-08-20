-- ==========================================
-- 🌐 ROUTER (OPENWRT) YÖNETİM MENÜSÜ
-- ==========================================
local routerMenu = hs.menubar.new()
routerMenu:setTitle("🌐")
routerMenu:setTooltip("Router (OpenWrt) Manager")

routerMenu:setMenu({

    { title = "Open Terminal SSH", fn = function()
        hs.execute('osascript -e \'tell application "Terminal" to do script "ssh root@192.168.2.1"\'')
    end },
    
    { title = "Router Log Output (SSH)", fn = function()
        hs.execute('osascript -e \'tell application "Terminal" to do script "ssh root@192.168.2.1 \\"tail -f /tmp/login_wifi.log\\""\'')
    end },

    { title = "Deploy Scripts to Router", fn = function()
        local cmd = "cd /Users/alpbora/captive-portal-manager/OpenWRT_version && " ..
                    "ssh root@192.168.2.1 \"rm -f /usr/bin/login_wifi.sh /usr/bin/login_functions.sh\" && " ..
                    "cat login_functions.sh | ssh root@192.168.2.1 \"cat > /usr/bin/login_functions.sh\" && " ..
                    "cat login_wifi.sh | ssh root@192.168.2.1 \"cat > /usr/bin/login_wifi.sh\" && " ..
                    "ssh root@192.168.2.1 \"chmod +x /usr/bin/login_wifi.sh /usr/bin/login_functions.sh\""
        
        hs.execute(cmd)
    end },

    { title = "Update Status", fn = function()
        hs.execute('ssh root@192.168.2.1 "bash -c \\"source /usr/bin/login_functions.sh && update\\""')
    end },
    
    { title = "Logout Wifi", fn = function()
        hs.execute('ssh root@192.168.2.1 "bash -c \\"source /usr/bin/login_functions.sh && logout\\""')
    end },
    
    { title = "Start Router Service", fn = function()
        hs.execute('ssh root@192.168.2.1 "/etc/init.d/login_wifi start"')
    end },
    
    { title = "Stop Router Service", fn = function()
        hs.execute('ssh root@192.168.2.1 "/etc/init.d/login_wifi stop"')
    end },
    
   { title = "Restart Router Service", fn = function()
    hs.execute('ssh root@192.168.2.1 "pkill -f login_wifi; > /tmp/login_wifi.log; /etc/init.d/login_wifi restart"')
end },
    
    { title = "Router: 192.168.2.1", disabled = true }
})