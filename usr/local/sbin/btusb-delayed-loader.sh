#!/bin/bash
# ==============================================================================
# Realtek RTL8852BE Bluetooth Controlled Loader & USB Port Reset
# ==============================================================================

# 1. Enforce active power states on AMD PCIe root bridge and XHCI host
for pci_dev in "0000:00:08.1" "0000:05:00.4" "0000:05:00.3"; do
    [ -f "/sys/bus/pci/devices/$pci_dev/power/control" ] && echo on > "/sys/bus/pci/devices/$pci_dev/power/control" 2>/dev/null || true
    [ -f "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" ] && echo 0 > "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" 2>/dev/null || true
done

# 2. Reset AMD USB root-hub Port 3 to clear port-disable / EMI locks from sleep
USB_PORT="/sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable"
if [ -f "$USB_PORT" ]; then
    echo "btusb-loader: Power cycling USB3 Port 3 to clear AMD XHCI port disable/EMI lock..."
    echo 1 > "$USB_PORT" 2>/dev/null || true
    sleep 1
    echo 0 > "$USB_PORT" 2>/dev/null || true
    sleep 2
fi

# 3. Controlled load loop with hardware verification
MAX_ATTEMPTS=4
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "btusb-loader: Attempt $ATTEMPT/$MAX_ATTEMPTS: Loading btusb..."
    /sbin/modprobe btusb 2>/dev/null || true
    sleep 2

    if compgen -G "/sys/class/bluetooth/hci*/rfkill*" > /dev/null; then
        echo "btusb-loader: Success! Bluetooth HCI controller verified and active."
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        exit 0
    fi

    echo "btusb-loader: Retrying USB port cycle & driver reload..."
    /sbin/modprobe -r btusb 2>/dev/null || true
    if [ -f "$USB_PORT" ]; then
        echo 1 > "$USB_PORT" 2>/dev/null || true
        sleep 1
        echo 0 > "$USB_PORT" 2>/dev/null || true
        sleep 2
    fi

    ATTEMPT=$((ATTEMPT + 1))
done

echo "btusb-loader: Error: Failed to initialize Bluetooth after $MAX_ATTEMPTS attempts."
exit 1
