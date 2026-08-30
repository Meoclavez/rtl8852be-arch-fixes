#!/bin/bash
# Automatically reset Realtek RTL8852BE Wi-Fi & Bluetooth on suspend/resume

case "$1" in
    pre)
        # Unload bluetooth and Wi-Fi drivers before entering low-power sleep state
        /usr/bin/modprobe -r btusb 2>/dev/null || true
        /usr/bin/modprobe -r rtw89_8852be rtw89_8852b rtw89_pci rtw89_8852b_common rtw89_core 2>/dev/null || true
        ;;
    post)
        # Re-enable PCIe root port bridge power control & rescan PCI bus
        if [ -f "/sys/bus/pci/devices/0000:00:02.2/power/control" ]; then
            echo on > /sys/bus/pci/devices/0000:00:02.2/power/control
        fi
        echo 1 > /sys/bus/pci/rescan
        
        # Load Wi-Fi driver stack
        /usr/bin/modprobe rtw89_8852be
        
        # Power cycle USB Port 3 on AMD XHCI host to recover from sleep EMI/disable
        USB_PORT="/sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable"
        if [ -f "$USB_PORT" ]; then
            echo 1 > "$USB_PORT" 2>/dev/null || true
            sleep 1
            echo 0 > "$USB_PORT" 2>/dev/null || true
        fi
        
        # Ensure rfkill is unblocked
        /usr/bin/rfkill unblock wifi 2>/dev/null || true
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        
        # Trigger the self-healing delayed loader in background
        (/usr/local/sbin/btusb-delayed-loader.sh &)
        ;;
esac
