#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run install.sh as root (sudo ./install.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1. Updating GRUB Kernel Parameters (Preserving All Existing Settings)..."
if [ -f "/etc/default/grub" ]; then
  cp /etc/default/grub /etc/default/grub.bak.$(date +%F_%H%M%S)

  python3 - << 'EOF'
import re

with open("/etc/default/grub", "r") as f:
    content = f.read()

match = re.search(r'^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"', content, re.M)
if match:
    current_params = match.group(1).split()
    to_add = ["pci=no_d3cold", "btusb.enable_autosuspend=n", "usbcore.autosuspend=-1"]
    for p in to_add:
        if p not in current_params:
            current_params.append(p)
    new_line = f'GRUB_CMDLINE_LINUX_DEFAULT="{" ".join(current_params)}"'
    content = re.sub(r'^GRUB_CMDLINE_LINUX_DEFAULT=".*"', new_line, content, flags=re.M)
    with open("/etc/default/grub", "w") as f:
        f.write(content)
    print("Updated GRUB_CMDLINE_LINUX_DEFAULT:", new_line)
EOF

  echo "==> Regenerating /boot/grub/grub.cfg..."
  grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "==> 2. Installing udev rules..."
mkdir -p /etc/udev/rules.d
cp -f "$SCRIPT_DIR"/etc/udev/rules.d/*.rules /etc/udev/rules.d/

echo "==> 3. Installing modprobe options..."
mkdir -p /etc/modprobe.d
cp -f "$SCRIPT_DIR"/etc/modprobe.d/*.conf /etc/modprobe.d/

echo "==> 4. Installing NetworkManager power save override..."
mkdir -p /etc/NetworkManager/conf.d
cp -f "$SCRIPT_DIR"/etc/NetworkManager/conf.d/*.conf /etc/NetworkManager/conf.d/

echo "==> 5. Installing WirePlumber Bluetooth audio stability policy..."
mkdir -p /etc/wireplumber/wireplumber.conf.d
cp -f "$SCRIPT_DIR"/etc/wireplumber/wireplumber.conf.d/*.conf /etc/wireplumber/wireplumber.conf.d/

echo "==> 6. Installing systemd sleep hook..."
mkdir -p /etc/systemd/system-sleep
cp -f "$SCRIPT_DIR"/etc/systemd/system-sleep/rtw89-suspend-resume.sh /etc/systemd/system-sleep/
chmod +x /etc/systemd/system-sleep/rtw89-suspend-resume.sh

echo "==> 7. Installing Bluetooth controlled delayed loader & service..."
mkdir -p /usr/local/sbin
cp -f "$SCRIPT_DIR"/usr/local/sbin/btusb-delayed-loader.sh /usr/local/sbin/
chmod +x /usr/local/sbin/btusb-delayed-loader.sh

mkdir -p /etc/systemd/system
cp -f "$SCRIPT_DIR"/etc/systemd/system/bt-xhci-reset.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable bt-xhci-reset.service

echo "==> 8. Configuring BlueZ main.conf..."
if [ -f "/etc/bluetooth/main.conf" ]; then
    sed -i 's/^#*AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf 2>/dev/null || true
    sed -i 's/^FastConnectable = true/#FastConnectable = false/' /etc/bluetooth/main.conf 2>/dev/null || true
fi

echo "==> 9. Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo "==> 10. Enforcing live sysfs power states..."
# Global USB autosuspend
[ -f "/sys/module/usbcore/parameters/autosuspend" ] && echo -1 > /sys/module/usbcore/parameters/autosuspend 2>/dev/null || true

# USB Root Hubs
for p in /sys/bus/usb/devices/usb*/power/control; do
  [ -f "$p" ] && echo on > "$p" 2>/dev/null || true
done
for p in /sys/bus/usb/devices/usb*/power/autosuspend_delay_ms; do
  [ -f "$p" ] && echo -1 > "$p" 2>/dev/null || true
done

# PCIe power controls
for dev in "0000:00:08.1" "0000:00:02.2" "0000:05:00.4" "0000:05:00.3" "0000:03:00.0"; do
  if [ -d "/sys/bus/pci/devices/$dev" ]; then
    echo on > "/sys/bus/pci/devices/$dev/power/control" 2>/dev/null || true
    echo 0 > "/sys/bus/pci/devices/$dev/d3cold_allowed" 2>/dev/null || true
  fi
done

echo "==> 11. Running delayed loader to bring Bluetooth chip online now..."
/usr/local/sbin/btusb-delayed-loader.sh || true

systemctl restart bluetooth 2>/dev/null || true

echo "=========================================================================="
echo "  Success! Realtek RTL8852BE Wi-Fi & Bluetooth fixes installed."
echo "=========================================================================="
