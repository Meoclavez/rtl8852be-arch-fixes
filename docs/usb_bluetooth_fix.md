# USB Bluetooth & Wi-Fi Configuration Fixes (Post-Kernel 7.1 Update)

This document details the root causes and configuration updates applied to fix USB Bluetooth dropouts, Wi-Fi coexistence collisions, link TX timeouts, and PCIe/USB power management on the **Realtek RTL8852BE combo card (13d3:3571 / 10ec:b852)** under modern Linux kernels (6.x / 7.x).

---

## 1. Description of Issues Resolved

### A. Wi-Fi & Bluetooth Coexistence Reset Collision (Double Initialization)
- **Symptom:** Bluetooth initialised at boot, worked briefly, and then crashed with `device descriptor read/64, error -71`, `Opcode 0x1003 failed: -71`, or `No default controller available`.
- **Root Cause:** The Realtek RTL8852BE is a combo M.2 card where Wi-Fi runs over PCIe and Bluetooth runs over USB (`usb 3-3` on AMD XHCI `0000:05:00.4`). When the `rtw89_8852be` Wi-Fi driver initialises and changes its rfkill hardware state during boot, the chip's internal coexistence manager resets the USB Bluetooth interface. This causes `btusb` to double-initialize and firmware loading to collide, leaving the Bluetooth state machine corrupted and prone to hard crashes under active I/O.
- **Fix:**
  1. Blacklisted `btusb` from autoloading at boot (`/etc/modprobe.d/btusb-blacklist.conf`).
  2. Created a systemd service (`/etc/systemd/system/bt-xhci-reset.service`) that waits 30 seconds after boot for `rtw89` and rfkill to settle before cleanly loading `btusb`.
  3. Added `reset=0` and `force_scofix=y` to `/etc/modprobe.d/btusb.conf`.

### B. Audio Link TX Timeouts & RF Contention (`link tx timeout`)
- **Symptom:** While connected to Bluetooth audio devices (e.g. wireless earbuds / headsets), audio drops, connection is killed with `Bluetooth: hci0: link tx timeout: killing stalled connection`, and subsequent opcodes return `-71` until the kernel watchdog resets the USB controller.
- **Root Cause:**
  1. `FastConnectable = true` in `/etc/bluetooth/main.conf` forces a 100% duty cycle page scan. On combo cards with a shared 2.4GHz antenna, this monopolizes RF airtime and starves active A2DP / HFP audio streaming packets.
  2. Realtek chipsets report incorrect SCO buffer sizes when Hands-Free Voice Gateway is registered alongside A2DP, causing TX ring stalls.
- **Fix:**
  1. Disabled `FastConnectable` in `/etc/bluetooth/main.conf` (`#FastConnectable = false`).
  2. Enabled `force_scofix=y` in `/etc/modprobe.d/btusb.conf`.

### C. `pci=no_d3cold` Kernel Parameter Deprecation (Kernel 7.1+)
- **Symptom:** Kernel logs show `PCI: Unknown option 'no_d3cold'`. Without global protection, the AMD XHCI USB controller (`0000:05:00.4`) and its parent PCIe bridge (`0000:00:08.1`) entered D3cold upon shutdown/sleep, causing `error -71` on the subsequent boot.
- **Fix:** Added per-device sysfs udev rules in `/etc/udev/rules.d/99-bluetooth-power.rules` to enforce `ATTR{d3cold_allowed}="0"` and `ATTR{power/control}="on"` for:
  - AMD XHCI Controller #4 (`1022:161e` / `0000:05:00.4`)
  - AMD XHCI Controller #3 (`1022:161d` / `0000:05:00.3`)
  - Parent PCIe Bridge (`1022:14b9` / `0000:00:08.1`)

### D. USB Bluetooth Autosuspend
- **Symptom:** `btusb` attempted runtime power cuts resulting in command timeouts (`-110` / `-71`).
- **Fix:** Configured `options btusb enable_autosuspend=n reset=0 force_scofix=y` and set USB udev rule `ATTR{power/autosuspend_delay_ms}="-1"`.

---

## 2. Updated Configuration Files

### `/etc/modprobe.d/btusb-blacklist.conf`
```text
blacklist btusb
```

### `/etc/modprobe.d/btusb.conf`
```text
options btusb enable_autosuspend=n reset=0 force_scofix=y
```

### `/etc/bluetooth/main.conf`
```ini
[General]
# FastConnectable = false (ensures standard page scan duty cycle to prevent RF contention on combo antenna)
```

### `/etc/systemd/system/bt-xhci-reset.service`
```ini
[Unit]
Description=Delayed load of btusb after Wi-Fi coexistence settles
Documentation=https://wiki.archlinux.org/title/Bluetooth
After=systemd-modules-load.service systemd-udev-settle.service
Before=bluetooth.service bluetooth.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/sbin/modprobe btusb
ExecStartPost=/bin/sleep 5
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### `/etc/udev/rules.d/99-bluetooth-power.rules`
```udev
# Disable autosuspend for the Realtek Bluetooth USB device (13d3:3571)
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="13d3", ATTRS{idProduct}=="3571", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"

# Disable D3cold and runtime power management for AMD XHCI USB4 controller #4 (05:00.4) - hosts Bluetooth
SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x161e", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

# Disable D3cold for AMD XHCI USB4 controller #3 sibling (05:00.3)
SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x161d", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

# Disable D3cold for the parent PCIe bridge (00:08.1) that powers the entire 05:xx bus
SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x14b9", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"
```

---

## 3. Important Recovery Notes

If the RTL8852BU Bluetooth chip enters an internal unrecoverable state (`error -71` on all descriptor reads during boot):
- The chip is powered from the M.2 card's 3.3V power plane, not XHCI VBUS.
- Software restarts or driver reloads cannot cut hardware power to the chip.
- **Fix:** Perform a complete cold power cycle (Shutdown → Unplug AC adapter → Hold power button for 30 seconds → Power on).
