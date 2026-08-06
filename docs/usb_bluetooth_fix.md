# USB Bluetooth & Wi-Fi Configuration Fixes (Post-Update 2026-08-04)

This document details the root causes and configuration updates applied to fix the udev errors and USB Bluetooth dropouts following the kernel 7.1 update.

---

## 1. Description of Issues Resolved

### A. udev Rule Errors (`99-bluetooth-power.rules`)
- **Symptom:** `journalctl` logged errors:
  ```text
  (udev-worker): 3-3:1.0: /etc/udev/rules.d/99-bluetooth-power.rules:2 ATTR{power/control}="on": Could not chase sysfs attribute "/sys/devices/.../usb3/3-3/3-3:1.0/power/control", ignoring: No such file or directory
  ```
- **Root Cause:** Line 2 used `SUBSYSTEM=="usb"` without filtering for `ENV{DEVTYPE}=="usb_device"`. It matched USB child interfaces (`3-3:1.0`, `3-3:1.1`), which do not possess a `power/control` attribute in sysfs.
- **Fix:** Added `ENV{DEVTYPE}=="usb_device"` and `ATTR{power/autosuspend_delay_ms}="-1"` to target only top-level USB device nodes.

### B. USB Bluetooth Radio Enumeration Collapse
- **Symptom:** The Bluetooth card disconnected with:
  ```text
  kernel: usb usb3-port3: disabled by hub (EMI?), re-enabling...
  kernel: usb 3-3: device descriptor read/64, error -71
  kernel: usb usb3-port3: unable to enumerate USB device
  ```
- **Fix:** Executed PCI rescan on AMD USB4 XHCI controller (`0000:05:00.4`) and updated USB power rules.

### C. NetworkManager Wi-Fi Power Save Override
- **Symptom:** `iw dev wlp3s0 get power_save` returned `Power save: on`.
- **Fix:** Created `/etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf` with `wifi.powersave = 2`.

---

## 2. Updated Configuration Files

### `/etc/udev/rules.d/99-bluetooth-power.rules`
```udev
# Disable autosuspend for the Realtek Bluetooth USB device (13d3:3571)
ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="13d3", ATTRS{idProduct}=="3571", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"

# Disable runtime power management for the parent AMD XHCI USB controller (0000:05:00.4)
ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x161e", ATTR{power/control}="on"
```

### `/etc/udev/rules.d/99-rtw89-d3cold.rules`
```udev
# Disable D3cold and enforce power control ON for Realtek RTL8852BE Wi-Fi (10ec:b852)
ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb852", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

# Disable runtime power management for AMD PCIe GPP Bridge (1022:14ba)
ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x14ba", ATTR{power/control}="on"
```

### `/etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf`
```ini
[connection]
wifi.powersave = 2
```

---

## 3. Automated Fix Script

An automated script is saved at `/home/meoclavezz/apply_fix.sh`. You can re-run it at any time:

```bash
sudo /home/meoclavezz/apply_fix.sh
```
