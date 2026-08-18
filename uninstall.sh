#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run uninstall.sh as root (sudo ./uninstall.sh)"
  exit 1
fi

echo "==> Disabling and removing Bluetooth delayed-load service..."
systemctl disable --now bt-xhci-reset.service 2>/dev/null || true
rm -f /etc/systemd/system/bt-xhci-reset.service
systemctl daemon-reload

echo "==> Removing udev rules..."
rm -f /etc/udev/rules.d/99-bluetooth-power.rules
rm -f /etc/udev/rules.d/99-rtw89-d3cold.rules
rm -f /etc/udev/rules.d/99-rtw89-rfkill-hook.rules

echo "==> Removing modprobe options..."
rm -f /etc/modprobe.d/70-rtw89.conf
rm -f /etc/modprobe.d/btusb.conf
rm -f /etc/modprobe.d/btusb-blacklist.conf

echo "==> Removing NetworkManager power save override..."
rm -f /etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf

echo "==> Removing hooks..."
rm -f /etc/systemd/system-sleep/rtw89-suspend-resume.sh
rm -f /usr/local/bin/rtw89-toggle-on-hook.sh

echo "==> Reloading udev & NetworkManager..."
udevadm control --reload-rules
systemctl restart NetworkManager

echo "Uninstallation complete."
