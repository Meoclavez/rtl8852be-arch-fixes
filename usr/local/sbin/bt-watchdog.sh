#!/bin/bash
# ==============================================================================
# Realtek RTL8852BE Bluetooth Watchdog & Auto-Recovery Daemon
# Automatically detects USB disconnects / AMD XHCI port locks and recovers in <3s
# ==============================================================================

PORT_DISABLE="/sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable"

while true; do
    sleep 4

    # Respect user explicit soft-block (e.g. airplane mode)
    if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
        continue
    fi

    # Check if Bluetooth HCI controller is missing from sysfs
    if [ ! -d "/sys/class/bluetooth/hci0" ] || [ ! -d "/sys/bus/usb/drivers/btusb" ]; then
        echo "bt-watchdog: Bluetooth HCI missing. Recovering AMD XHCI Port 3..."
        
        # 1. Enforce active power on AMD PCIe / XHCI hosts
        for pci_dev in "0000:00:08.1" "0000:05:00.4" "0000:05:00.3"; do
            [ -f "/sys/bus/pci/devices/$pci_dev/power/control" ] && echo on > "/sys/bus/pci/devices/$pci_dev/power/control" 2>/dev/null || true
            [ -f "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" ] && echo 0 > "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" 2>/dev/null || true
        done

        # 2. Cycle AMD XHCI USB3 Port 3 to clear port error lock
        if [ -f "$PORT_DISABLE" ]; then
            echo 1 > "$PORT_DISABLE" 2>/dev/null || true
            sleep 1
            echo 0 > "$PORT_DISABLE" 2>/dev/null || true
            sleep 2
        fi

        # 3. Ensure driver is probed and rfkill unblocked
        /sbin/modprobe btusb 2>/dev/null || true
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        
        sleep 4
    fi
done
