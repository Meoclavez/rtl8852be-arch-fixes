#!/bin/bash
# Robust delayed loader for Realtek RTL8852BE Bluetooth (btusb)
# Prevents coexistence collisions with rtw89_8852be and self-heals if first probe hits error -71

echo "btusb-loader: Waiting 20s for Wi-Fi (rtw89) coexistence and rfkill to settle..."
sleep 20

MAX_ATTEMPTS=5
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "btusb-loader: Attempt $ATTEMPT/$MAX_ATTEMPTS: Loading btusb module..."
    /sbin/modprobe btusb
    sleep 3

    # Check if a Bluetooth HCI controller interface has a valid MAC address in sysfs
    HCI_ADDR=$(cat /sys/class/bluetooth/hci*/address 2>/dev/null | head -n 1 || true)
    if [ -n "$HCI_ADDR" ] && [ "$HCI_ADDR" != "00:00:00:00:00:00" ]; then
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        echo "btusb-loader: Success! Bluetooth controller ($HCI_ADDR) initialized."
        exit 0
    fi

    echo "btusb-loader: Warning: No valid HCI MAC address found (error -71 or uninitialized). Unloading and retrying..."
    /sbin/modprobe -r btusb 2>/dev/null || true
    sleep 2

    ATTEMPT=$((ATTEMPT + 1))
done

echo "btusb-loader: Error: Failed to initialize Bluetooth HCI after $MAX_ATTEMPTS attempts."
exit 1
