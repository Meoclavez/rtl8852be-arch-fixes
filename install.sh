#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run install.sh as root (sudo ./install.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing udev rules..."
mkdir -p /etc/udev/rules.d
cp "$SCRIPT_DIR"/etc/udev/rules.d/*.rules /etc/udev/rules.d/

echo "==> Installing modprobe options..."
mkdir -p /etc/modprobe.d
cp "$SCRIPT_DIR"/etc/modprobe.d/*.conf /etc/modprobe.d/

echo "==> Installing NetworkManager power save override..."
mkdir -p /etc/NetworkManager/conf.d
cp "$SCRIPT_DIR"/etc/NetworkManager/conf.d/*.conf /etc/NetworkManager/conf.d/

echo "==> Installing systemd sleep hook..."
mkdir -p /etc/systemd/system-sleep
cp "$SCRIPT_DIR"/etc/systemd/system-sleep/rtw89-suspend-resume.sh /etc/systemd/system-sleep/
chmod +x /etc/systemd/system-sleep/rtw89-suspend-resume.sh

echo "==> Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo "==> Enforcing non-destructive sysfs power rules..."
if [ -f "/sys/bus/pci/devices/0000:00:02.2/power/control" ]; then
    echo on > /sys/bus/pci/devices/0000:00:02.2/power/control 2>/dev/null || true
    echo 0 > /sys/bus/pci/devices/0000:00:02.2/d3cold_allowed 2>/dev/null || true
fi

if [ -f "/sys/bus/pci/devices/0000:03:00.0/power/control" ]; then
    echo on > /sys/bus/pci/devices/0000:03:00.0/power/control 2>/dev/null || true
    echo 0 > /sys/bus/pci/devices/0000:03:00.0/d3cold_allowed 2>/dev/null || true
fi

rfkill unblock wifi 2>/dev/null || true
rfkill unblock bluetooth 2>/dev/null || true

echo "=========================================================================="
echo "  Success! Realtek RTL8852BE Wi-Fi & Bluetooth fixes installed."
echo "=========================================================================="
