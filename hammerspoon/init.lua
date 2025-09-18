-- -- Önce eski varsa sil
-- rm -f "$HOME/.hammerspoon/init.lua"

-- -- Symlink olustur
-- ln -s "$HOME/captive-portal-manager/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"

-- Log dosyasının yolu
local logPath = os.getenv("HOME") .. "/captive-portal-manager/internet-login.log"

-- Bildirim gönderen fonksiyon
local function notifyLogStatus()
    local file = io.open(logPath, "r")
    local statusLine
    if file then
        statusLine = file:read("*l")
        file:close()
    else
        statusLine = "❓ Durum: Bilgi yok"
    end

    -- Bildirim gönder
    hs.notify.new({title="WiFi Durumu", informativeText=statusLine}):send()
end

local function showLogOverlay()
    local file = io.open(logPath, "r")
    local statusLine
    if file then
        statusLine = file:read("*l")
        file:close()
    else
        statusLine = "❓ Durum: Bilgi yok"
    end

    -- Önceden açıksa sil
    if _G.logOverlay then
        _G.logOverlay:delete()
        _G.logOverlay = nil
    end

    -- ======================================
    -- Kullanıcı tarafından kolayca değiştirilebilir ayarlar
    -- ======================================

    local textSize = 18          -- Yazı boyutu (daha büyük sayılar yazıyı büyütür)
    local paddingX = 0          -- Metin etrafındaki yatay boşluk (pencereyi genişletir)
    local paddingY = 8           -- Metin etrafındaki dikey boşluk (pencereyi yüksek yapar)
    local cornerRadius = 20       -- Pencere köşe yuvarlama (10 iyice yuvarlatılmış)
    local bgColor = {red=0, green=0, blue=0, alpha=0.7}   -- Arka plan rengi ve opaklık
    local borderColor = {white=1, alpha=0.8}             -- Kenarlık rengi ve opaklık
    local borderWidth = 2       -- Kenarlık kalınlığı
    local displayDuration = 10  -- Ekranda kalma süresi (saniye)
    local topOffset = 0       -- Ekranın üstünden boşluk (pencerenin Y konumu)
    local textFont = "Menlo"    -- Yazı tipi
    local textColor = {white=1} -- Yazı rengi

    -- ======================================
    -- Pencere boyutu hesaplama
    -- ======================================
    -- statusLine uzunluğuna göre pencere genişliğini ayarlıyoruz
    -- 1 karakter ~ 0.6 * textSize genişlik kaplar
    local textWidth = #statusLine * (textSize * 0.6)
    local canvasWidth = textWidth + paddingX * 2
    local canvasHeight = textSize + paddingY * 2

    local screenFrame = hs.screen.mainScreen():frame()
    -- Pencereyi yatayda ortala
    local canvasX = screenFrame.x + (screenFrame.w - canvasWidth)/2
    -- Pencereyi ekranda üstten topOffset kadar konumlandır
    local canvasY = screenFrame.y + topOffset

    -- ======================================
    -- Overlay oluşturma
    -- ======================================
    _G.logOverlay = hs.canvas.new({x=canvasX, y=canvasY, w=canvasWidth, h=canvasHeight})
        :appendElements({
            type = "rectangle",
            action = "fill",
            fillColor = bgColor,
            strokeColor = borderColor,
            strokeWidth = borderWidth,
            roundedRectRadii = {xRadius=cornerRadius, yRadius=cornerRadius}
        })
        :appendElements({
            type = "text",
            text = statusLine,
            textSize = textSize,
            textFont = textFont,
            textColor = textColor,
            textAlignment = "center",
            frame = {x=0, y = (canvasHeight - textSize)/2, w=canvasWidth, h=canvasHeight} -- Metni pencereye tam ortala
        })
        :show()

    -- Belirli süre sonra kaybolsun
    hs.timer.doAfter(displayDuration, function() 
        if _G.logOverlay then
            _G.logOverlay:delete()
            _G.logOverlay = nil
        end
    end)
end

-- Menü çubuğu objesi
local wifiMenu = hs.menubar.new()
wifiMenu:setTitle("📶")
wifiMenu:setTooltip("WiFi Log Menu")
wifiMenu:setMenu({
    { title = "Show Status", fn = showLogOverlay },
    { title = "Update Status", fn = function()
        hs.execute('source $HOME/captive-portal-manager/login_functions.sh && update &')
        hs.notify.show("WiFi Status", "", "Log Updated")
    end },
    { title = "Terminal Log Output", fn = function()
    hs.execute('osascript -e \'tell application "Terminal" to do script "tail -f /tmp/login_wifi.log"\'') end },
    { title = "Stop Service", fn = function()
    -- 1. LaunchAgent'ı unload et
    hs.execute('launchctl unload ~/Library/LaunchAgents/com.captiveportal.manager.plist')
    
    -- 2. login_wifi.sh ve ilgili log komutlarını öldür
    hs.execute([[
        pkill -f '/Users/alpbora/captive-portal-manager/login_wifi.sh'
        pkill -f 'tail -f /tmp/login_wifi.log'
    ]])

    -- 3. Bildirim göster
    hs.notify.show("WiFi Service", "", "Service Stopped")
end },

    { title = "Launch Service", fn = function()
        hs.execute('launchctl load ~/Library/LaunchAgents/com.captiveportal.manager.plist')
        hs.notify.show("WiFi Service", "", "Service Launched")
    end },
    
    { title = "Clear Log", fn = function()
        hs.execute('rm /tmp/login_wifi.log')
        hs.notify.show("WiFi Log", "", "Log file cleared")
    end },
    { title = "Log file: " .. logPath, disabled = true }
})

-- İkon tıklanınca overlay popup aç
wifiMenu:setClickCallback(function()
    showLogOverlay()
end)

-- Dosya değişimini izleyen watcher
local logWatcher = hs.pathwatcher.new(logPath, function(paths, flags)
    notifyLogStatus()
end)
logWatcher:start()

-- Başlangıçta mevcutsa bildirim gönder
if io.open(logPath, "r") then
    notifyLogStatus()
end