# USB Bluetooth & Wi-Fi Configuration Fixes (Linux 7.1+)

This document details the root causes and configuration updates applied to fix USB Bluetooth dropouts, Wi-Fi coexistence collisions, link TX timeouts, and PCIe/USB power management on the **Realtek RTL8852BE combo card (13d3:3571 / 10ec:b852)** under modern Linux kernels (6.x / 7.x).

---

## 1. Description of Issues Resolved

### A. Audio Streaming Disconnects & TX Queue Stalls (`force_scofix` conflict)
- **Symptom:** Bluetooth suddenly disconnects while playing music/audio through wireless earbuds (`Realtek Real-Buds` / A2DP headsets), and the adapter drops offline.
- **Root Cause:**
  - `force_scofix=y` in `/etc/modprobe.d/btusb.conf` is an obsolete quirk that overrides USB isochronous endpoint packet framing.
  - On the RTL8852BE Full-Speed USB controller, `force_scofix` caused buffer underruns and packet stalls during high-bitrate A2DP audio playback, dropping the connection mid-song.
- **Fix:** Removed `force_scofix=y` from `/etc/modprobe.d/btusb.conf`.

### B. Firmware Download Opcode `0xfc20` Timeout (`reset=0` conflict)
- **Symptom:** `dmesg` reports:
  ```text
  Bluetooth: hci0: unexpected event for opcode 0xfc20
  Bluetooth: hci0: command 0xfc20 tx timeout
  Bluetooth: hci0: RTL: download fw command failed (-110)
  ```
- **Root Cause:**
  - Setting `reset=0` in `/etc/modprobe.d/btusb.conf` instructed the kernel to skip `HCI_OP_RESET` on driver initialization.
  - When the adapter initialized from an unreset state, `btrtl` sent firmware download chunks (`0xfc20`) to an unready controller, triggering timeout `-110` and crashing the USB interface into error `-71`.
- **Fix:** Removed `reset=0` from `/etc/modprobe.d/btusb.conf` to restore kernel standard `HCI_OP_RESET` initialization.

### C. "No Adapter Found" When Idle (`blacklist btusb` conflict)
- **Symptom:** When idle, the system reported "No default controller available" until a manual command was executed.
- **Root Cause:** `blacklist btusb` prevented the kernel's native udev subsystem from automatically hotplugging and binding the `btusb` driver when the USB device re-enumerated.
- **Fix:** Removed `btusb-blacklist.conf` so Linux udev natively manages device binding.

### D. AMD XHCI USB Root-Hub Port 3 Recovery on Sleep/Wake
- **Symptom:** After laptop sleep / suspend or low-power state transitions, the kernel reported `usb usb3-port3: disabled by hub (EMI?), unable to enumerate USB device`.
- **Root Cause:** The AMD XHCI controller locked Port 3 into a hardware-disabled state.
- **Fix:** Added a sysfs port-cycle (`echo 1 > /sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable && echo 0 > ...`) to `/etc/systemd/system-sleep/rtw89-suspend-resume.sh` on `post` (wake), instantly clearing the controller error state and re-enumerating the Bluetooth radio cleanly.

---

## 2. Active Configuration Reference

### `/etc/modprobe.d/btusb.conf`
```text
options btusb enable_autosuspend=n
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

### `/etc/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf`
```json
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}
```

### `/etc/bluetooth/main.conf`
```ini
[General]
# FastConnectable = false
```
