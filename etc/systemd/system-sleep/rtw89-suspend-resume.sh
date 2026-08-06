#!/bin/bash
# Automatically reset Realtek RTL8852BE Wi-Fi & Bluetooth on suspend/resume

case "$1" in
    pre)
        # Unload driver before entering low-power sleep state to prevent firmware/xtal freezes
        /usr/bin/modprobe -r rtw89_8852be rtw89_8852b rtw89_pci rtw89_8852b_common rtw89_core 2>/dev/null || true
        ;;
    post)
        # Re-enable PCIe root port bridge power control & rescan PCI bus
        if [ -f "/sys/bus/pci/devices/0000:00:02.2/power/control" ]; then
            echo on > /sys/bus/pci/devices/0000:00:02.2/power/control
        fi
        echo 1 > /sys/bus/pci/rescan
        
        # Load driver stack
        /usr/bin/modprobe rtw89_8852be
        
        # Ensure rfkill is unblocked
        /usr/bin/rfkill unblock wifi 2>/dev/null || true
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        ;;
esac
