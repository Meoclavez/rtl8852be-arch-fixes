#!/usr/bin/env bash
# Automatically reset Realtek RTL8852BE Wi-Fi & Bluetooth on suspend/resume

case "$1" in
    pre)
        # Unload drivers before sleep to prevent PCIe crystal/bus desync
        /usr/bin/modprobe -r btusb 2>/dev/null || true
        /usr/bin/modprobe -r rtw89_8852be rtw89_8852b rtw89_pci rtw89_8852b_common rtw89_core 2>/dev/null || true
        ;;
    post)
        # Re-enable PCIe root port bridge power control & rescan PCI bus
        if [ -f "/sys/bus/pci/devices/0000:00:02.2/power/control" ]; then
            echo on > "/sys/bus/pci/devices/0000:00:02.2/power/control" 2>/dev/null || true
            echo 0 > "/sys/bus/pci/devices/0000:00:02.2/d3cold_allowed" 2>/dev/null || true
        fi
        if [ -f "/sys/bus/pci/devices/0000:00:08.1/power/control" ]; then
            echo on > "/sys/bus/pci/devices/0000:00:08.1/power/control" 2>/dev/null || true
            echo 0 > "/sys/bus/pci/devices/0000:00:08.1/d3cold_allowed" 2>/dev/null || true
        fi
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
        
        # Load Wi-Fi driver stack
        /usr/bin/modprobe rtw89_8852be 2>/dev/null || true
        
        # Ensure rfkill is unblocked
        /usr/bin/rfkill unblock wifi 2>/dev/null || true
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        
        # Trigger the self-healing delayed loader in background
        if [ -x "/usr/local/sbin/btusb-delayed-loader.sh" ]; then
            (/usr/local/sbin/btusb-delayed-loader.sh &)
        fi
        ;;
esac
