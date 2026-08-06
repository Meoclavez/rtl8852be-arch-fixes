#!/bin/bash
# Hook triggered when Wi-Fi is toggled ON (rfkill unblock / nmcli / KDE system tray)

sleep 0.5

# Check if wlp3s0 is responsive
if ! /usr/bin/iw dev wlp3s0 info >/dev/null 2>&1 || [ "$(nmcli -g GENERAL.STATE device show wlp3s0 2>/dev/null)" = "20 (unavailable)" ]; then
    logger -t rtw89-hook "Wi-Fi toggled ON but card is uninitialized. Auto-resetting rtw89 driver..."
    
    # 1. Unload module stack
    /usr/bin/modprobe -r rtw89_8852be rtw89_8852b rtw89_pci rtw89_8852b_common rtw89_core 2>/dev/null || true
    
    # 2. Perform Function Level Reset (FLR) on hardware PCIe endpoint
    if [ -f "/sys/bus/pci/devices/0000:03:00.0/reset" ]; then
        echo 1 > /sys/bus/pci/devices/0000:03:00.0/reset 2>/dev/null || true
    fi
    
    # 3. Reload rtw89 driver stack
    /usr/bin/modprobe rtw89_8852be
    
    # 4. Ensure rfkill unblocked
    /usr/bin/rfkill unblock wifi 2>/dev/null || true
    
    logger -t rtw89-hook "rtw89 driver auto-reset successfully."
fi
