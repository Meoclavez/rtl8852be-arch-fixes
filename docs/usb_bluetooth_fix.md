# USB Bluetooth & Wi-Fi Configuration Fixes (Post-Kernel 7.1 Update)

This document details the root causes and configuration updates applied to fix USB Bluetooth dropouts, Wi-Fi coexistence collisions, link TX timeouts, and PCIe/USB power management on the **Realtek RTL8852BE combo card (13d3:3571 / 10ec:b852)** under modern Linux kernels (6.x / 7.x).

---

## 1. Description of Issues Resolved

### A. Wi-Fi & Bluetooth Coexistence Reset Collision & Controlled Boot Loading
- **Symptom:** After a kernel update or fresh boot, Bluetooth fails to initialize (`Bluetooth: hci0: RTL: RTL: Read reg16 failed (-71)` or `No default controller available`), but immediately succeeds when reloaded manually.
- **Root Cause:**
  1. The Realtek RTL8852BE is a combo M.2 card where Wi-Fi runs over PCIe and Bluetooth runs over USB (`usb 3-3` on AMD XHCI `0000:05:00.4`).
  2. When `rtw89_8852be` initializes and toggles its rfkill state at boot, the combo hardware triggers an internal bus reset on the USB Bluetooth controller.
  3. If `btusb` loads during this transition, the initial firmware download may fail with `error -71`.
  4. Furthermore, checking `/sys/class/bluetooth/hci*/address` in early boot fails because the address file is only populated after userspace Bluetooth services initialize the socket.
- **Fix:**
  1. Blacklisted `btusb` from uncontrolled early boot loading (`/etc/modprobe.d/btusb-blacklist.conf`).
  2. Created a fully controlled loader script (`/usr/local/sbin/btusb-delayed-loader.sh`) managed by `bt-xhci-reset.service`. The script enforces power rails on AMD PCIe bridges, settles combo coexistence, probes `btusb`, verifies active `rfkill` interface creation (`/sys/class/bluetooth/hci*/rfkill*`), and automatically retries if `-71` occurs.
  3. Configured `options btusb enable_autosuspend=n reset=0 force_scofix=y` in `/etc/modprobe.d/btusb.conf`.

### B. Audio Link TX Timeouts & RF Contention (`link tx timeout`)
- **Symptom:** While connected to Bluetooth audio devices (e.g. wireless earbuds / headsets), audio drops, connection is killed with `Bluetooth: hci0: link tx timeout: killing stalled connection`, and subsequent opcodes return `-71`.
- **Root Cause:**
  1. `FastConnectable = true` in `/etc/bluetooth/main.conf` forces a 100% duty cycle page scan, monopolizing RF airtime and starving active A2DP / HFP audio streaming packets.
  2. WirePlumber's `bluetooth.autoswitch-to-headset-profile = true` attempts to switch to HFP/SCO voice profile when applications query microphone inputs, overflowing the Realtek USB TX FIFO buffer during active playback.
- **Fix:**
  1. Disabled `FastConnectable` in `/etc/bluetooth/main.conf` (`#FastConnectable = false`).
  2. Disabled `bluetooth.autoswitch-to-headset-profile` in WirePlumber (`11-bluetooth-policy.conf`).
  3. Enabled `force_scofix=y` in `/etc/modprobe.d/btusb.conf`.

### C. System Sleep / Suspend Stability (S0ix `s2idle` vs Fake S3 `deep`)
- **Symptom:** After waking from sleep mode, Plasma menus disappear (`eglError: 0x3006: EGL_BAD_CONTEXT`), and Bluetooth disconnects (`disabled by hub (EMI?)`).
- **Root Cause:** ASUS TUF FA506NFR ACPI BIOS only supports `(supports S0 S4 S5)`. Forcing `mem_sleep_default=deep` caused the kernel to attempt unsupported ACPI S3 sleep, cutting power rails to NVIDIA VRAM and the AMD USB4/XHCI root hub.
- **Fix:**
  1. Removed `mem_sleep_default=deep` from `/etc/default/grub` and regenerated `/boot/grub/grub.cfg`.
  2. System now uses native `s2idle` (S0ix) which cleanly maintains PCIe and USB power states.
  3. Updated `/etc/systemd/system-sleep/rtw89-suspend-resume.sh` to unload `btusb` on `pre` and trigger the delayed loader on `post`.

---

## 2. Configuration Files Reference

### `/etc/modprobe.d/btusb-blacklist.conf`
```text
blacklist btusb
```

### `/etc/modprobe.d/btusb.conf`
```text
options btusb enable_autosuspend=n reset=0 force_scofix=y
```

### `/usr/local/sbin/btusb-delayed-loader.sh`
```bash
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
```

### `/etc/systemd/system/bt-xhci-reset.service`
```ini
[Unit]
Description=Robust delayed load & self-healing retry of btusb for Realtek RTL8852BE
Documentation=https://wiki.archlinux.org/title/Bluetooth
After=systemd-modules-load.service systemd-udev-settle.service NetworkManager.service
Before=bluetooth.service bluetooth.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/btusb-delayed-loader.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```
