#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run uninstall.sh as root (sudo ./uninstall.sh)"
  exit 1
fi

echo "==> 1. Removing udev rules..."
rm -f /etc/udev/rules.d/99-bluetooth-power.rules
rm -f /etc/udev/rules.d/99-rtw89-d3cold.rules

echo "==> 2. Removing modprobe options..."
rm -f /etc/modprobe.d/70-rtw89.conf
rm -f /etc/modprobe.d/btusb.conf

echo "==> 3. Removing NetworkManager power save override..."
rm -f /etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf

echo "==> 4. Removing WirePlumber audio policies..."
rm -f /etc/wireplumber/wireplumber.conf.d/10-bluetooth.conf
rm -f /etc/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf

echo "==> 5. Removing systemd sleep hooks..."
rm -f /etc/systemd/system-sleep/rtw89-suspend-resume.sh

echo "==> 6. Cleaning up legacy services..."
systemctl disable --now bt-xhci-reset.service 2>/dev/null || true
rm -f /etc/systemd/system/bt-xhci-reset.service
rm -f /usr/local/sbin/btusb-delayed-loader.sh
rm -f /usr/local/sbin/reset-bt-xhci.sh
systemctl daemon-reload

echo "==> 7. Reloading udev..."
udevadm control --reload-rules
udevadm trigger

echo "Uninstallation complete."
