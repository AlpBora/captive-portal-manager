# Captive Portal Manager

A macOS background utility that **automatically authenticates to captive Wi-Fi networks**, monitors connectivity, and keeps the session alive.  
It integrates with **LaunchAgents** for persistent execution and uses **Hammerspoon** for menu bar visibility and user notifications.

---

## Features

- **Automatic Login**  
  Detects when connected to a captive Wi-Fi and runs a custom login script.
- **Session Monitoring**  
  Periodically checks connectivity and re-authenticates if needed.
- **Persistent Background Execution**  
  Managed by `launchd` through **LaunchAgents**.
- **User Notifications**  
  Menu bar integration via Hammerspoon for status overview and quick actions.
  Desktop notifications on status changes.
- **Terminal Monitoring**
   Terminal log access for real-time monitoring.
---

---

## Installation

1. Clone the repository:

        git clone https://github.com/AlpBora/captive-portal-manager.git
        cd captive-portal-manager

2. Customize the scripts acording to the captive portal you wish to connect, add your credentials

2. Make sure scripts are executable:

        chmod +x login_functions.sh
        chmod +x login_wifi.sh

3.	Copy the LaunchAgent:

        cp com.captiveportal.manager.plist ~/Library/LaunchAgents/

4. Install Hammerspoon

    https://github.com/Hammerspoon/hammerspoon.git

5.	Copy lua file to Hammerspoon:

        cp -f hammerspoon/init.lua ~/.hammerspoon/init.lua

6.	Quit and Restart Hammerspoon to apply changes

7. When the menu icon 📶 is visible click and launch the service



## Hammerspoon Menu Bar Integration

The project uses **Hammerspoon** to provide a menu bar interface that allows real-time monitoring and control of the captive portal service. Hammerspoon does **not** handle the login itself; it only provides notifications, menu access, and overlays for status updates.

Once Hammerspoon is running, a menu bar icon (`📶`) appears. Clicking this icon or selecting menu items provides the following functionality:

### Menu Items

- **Show Status:** Displays a temporary overlay on the screen with the current WiFi status. The overlay’s font, size, color, background, border, and duration are configurable.  
- **Update Status:** Executes the login script to refresh the log file. A system notification confirms that the log has been updated.  
- **Terminal Log Output:** Opens a Terminal window running `tail -f /tmp/login_wifi.log` to continuously monitor WiFi login events.  
- **Stop Service:** Stops the background LaunchAgent responsible for automatic login. A notification confirms the service has stopped.  
- **Launch Service:** Starts the LaunchAgent again, ensuring the login script can run in the background. A notification confirms the service has launched.  
- **Clear Log:** Deletes the current log file and sends a notification to confirm that it has been cleared.  
- **Log file:** Shows the path to the current log file (non-clickable for reference).

### Overlay Popup

Clicking the menu icon shows the current status from the log file as a temporary overlay 


### Automatic Notifications

A path watcher monitors changes to the log file and triggers notifications whenever the log is updated. This ensures users receive real-time status updates without needing to manually check the log.


## Log File Format

The project maintains a log file (internet-login.log) to track the current status of the captive portal session. The log is updated dynamically by the login script and is used both for Hammerspoon menu notifications and overlay display.

Online status example:

    🌐 User: <username> | Internet: Online | 📶 Remaining: <remaining> MB | ⬇️ Download: <download> Mbit/s

Offline status example:

    ❌ Internet: Offline | 📶 Remaining: — MB | ⬇️ Download: —
    
This format ensures that the Hammerspoon menu bar icon, overlay, and notifications always display consistent, human-readable connection status.

## Troubleshooting

This section provides common troubleshooting tips for the Captive Portal Manager project.

 - If the background login service is not functioning:
Check if the service is loaded and running:

        launchctl list | grep com.captiveportal.manager

- If the service is not running, reload the plist:

        launchctl unload ~/Library/LaunchAgents/com.captiveportal.manager.plist
        launchctl load ~/Library/LaunchAgents/com.captiveportal.manager.plist

- Hammerspoon doesn’t load `init.lua`

   Ensure the correct file is coppied to .hammerspoon and reload config

        cp -f ~/captive-portal-manager/init.lua ~/.hammerspoon/init.lua

   Restart Hammerspoon after creating the symlink.


- Notifications not showing

    If you do not receive notifications from the menu bar:
    Make sure Hammerspoon has Accessibility and Notifications permissions:
    
    1   . Open System Settings → Privacy & Security
    
    2   .	Grant Hammerspoon the necessary permissions

    3   .  Restart Hammerspoon after updating permissions.