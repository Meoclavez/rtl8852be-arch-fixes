#!/bin/bash
# Robust delayed loader for Realtek RTL8852BE Bluetooth (btusb)
# Prevents coexistence collisions with rtw89_8852be and self-heals if first probe hits error -71

echo "btusb-loader: Waiting 25s for Wi-Fi (rtw89) coexistence and rfkill to settle..."
sleep 25

MAX_ATTEMPTS=4
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "btusb-loader: Attempt $ATTEMPT/$MAX_ATTEMPTS: Loading btusb module..."
    /sbin/modprobe btusb
    sleep 3

    # Check if a Bluetooth HCI controller interface appeared in sysfs
    if compgen -G "/sys/class/bluetooth/hci*" > /dev/null; then
        echo "btusb-loader: Success! Bluetooth HCI controller detected."
        exit 0
    fi

    echo "btusb-loader: Warning: No HCI controller found (possibly error -71). Unloading and retrying..."
    /sbin/modprobe -r btusb 2>/dev/null || true
    sleep 2

    ATTEMPT=$((ATTEMPT + 1))
done

echo "btusb-loader: Error: Failed to initialize Bluetooth HCI after $MAX_ATTEMPTS attempts."
exit 1
