#!/bin/bash
# ==============================================================================
# Realtek RTL8852BE Bluetooth Controlled Loader (btusb)
# Fully manages driver lifecycle, coexistence settling, power rails, & recovery
# ==============================================================================

# 1. Enforce active power states on AMD PCIe root bridge and XHCI USB host
for pci_dev in "0000:00:08.1" "0000:05:00.4" "0000:05:00.3"; do
    if [ -f "/sys/bus/pci/devices/$pci_dev/power/control" ]; then
        echo on > "/sys/bus/pci/devices/$pci_dev/power/control" 2>/dev/null || true
    fi
    if [ -f "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" ]; then
        echo 0 > "/sys/bus/pci/devices/$pci_dev/d3cold_allowed" 2>/dev/null || true
    fi
done

# 2. Wait for Wi-Fi (rtw89_8852be) combo radio initialization to settle
echo "btusb-loader: Settling combo radio coexistence..."
sleep 15

# 3. Controlled load loop with hardware verification
MAX_ATTEMPTS=4
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "btusb-loader: Attempt $ATTEMPT/$MAX_ATTEMPTS: Probing btusb module..."
    /sbin/modprobe btusb 2>/dev/null || true
    sleep 2

    # Verification: Check if a registered Bluetooth HCI interface with active rfkill exists
    if compgen -G "/sys/class/bluetooth/hci*/rfkill*" > /dev/null; then
        echo "btusb-loader: Success! Bluetooth HCI controller verified and active."
        /usr/bin/rfkill unblock bluetooth 2>/dev/null || true
        exit 0
    fi

    echo "btusb-loader: Warning: Controller not ready (possible error -71). Unloading and retrying..."
    /sbin/modprobe -r btusb 2>/dev/null || true
    sleep 2

    ATTEMPT=$((ATTEMPT + 1))
done

echo "btusb-loader: Error: Failed to initialize Bluetooth after $MAX_ATTEMPTS attempts."
exit 1
