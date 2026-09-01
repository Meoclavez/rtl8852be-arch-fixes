# USB Bluetooth & Wi-Fi Configuration Fixes (Linux 7.1 / 7.2+)

This document details the root causes and permanent configuration updates applied to fix USB Bluetooth dropouts, Wi-Fi coexistence collisions, audio playback link hangs (`devcoredump (3)`), and PCIe/USB power management on the **Realtek RTL8852BE combo card (13d3:3571 / 10ec:b852)** under modern Linux kernels (6.x / 7.x).

---

## 1. Description of Issues Resolved

### A. Wi-Fi Boot Calibration & Coexistence Contention
- **Root Cause:** During early boot, `rtw89_8852be` initializes the Wi-Fi interface and triggers an internal hardware reset on the shared 2.4GHz RF transceiver. If `btusb` tries to probe and download firmware at the exact same moment, the USB D+/D- pins return `error -71` (device not responding).
- **Fix:** Installed `/usr/local/sbin/btusb-delayed-loader.sh` and `/etc/systemd/system/bt-xhci-reset.service` (running after `NetworkManager.service`) to power-cycle USB Port 3 and safely load `btusb` after Wi-Fi calibration has settled.

### B. Audio Playback Crashes & `devcoredump (3)`
- **Root Causes:**
  1. **USB Root Hub Power Management:** The Linux kernel's runtime power management periodically suspended the AMD XHCI USB 2.0 Root Hub (`usb3`), causing micro-framing errors and EMI disconnects on USB Port 3.
  2. **Full-Speed USB Endpoint Buffer Overflows:** The Realtek RTL8852BE Bluetooth transceiver operates on a **Full-Speed (12Mbps) USB endpoint**. Variable-bitrate AAC packets and unbuffered A2DP bursts cause packet queue congestion (`Missing completion reports for packet`), triggering internal firmware watchdog timeouts (`RTL: hw err, trigger devcoredump (3)`).
  3. **Hands-Free (HFP/HSP) Collision:** When applications query for audio input (e.g. Flatpak VAD or browser permissions), BlueZ attempts to negotiate bidirectional SCO voice gateway channels while A2DP streaming is active.
- **Fix:**
  - Added udev rules disabling autosuspend across Linux USB Root Hubs (`1d6b:0002` / `1d6b:0003`).
  - Added `pci=no_d3cold btusb.enable_autosuspend=n usbcore.autosuspend=-1` to GRUB kernel command line.
  - Configured WirePlumber `10-bluetooth.conf` with:
    - **SBC-XQ (48kHz / 453kbps)** fixed-rate high fidelity audio.
    - **A2DP Sink Pinning (`bluez5.roles = [ a2dp_sink a2dp_source ]`)** to block HFP renegotiations.
    - **Optimal Quantum Buffer (`node.latency = "1024/48000"`)** providing an exact ~21.3ms buffer to prevent USB completion packet drops.

---

## 2. Updated Configuration Files

### `/etc/udev/rules.d/99-bluetooth-power.rules`
```udev
# Disable autosuspend for Realtek Bluetooth USB device (13d3:3571)
ACTION=="add|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="13d3", ATTRS{idProduct}=="3571", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"

# Disable autosuspend for Linux USB Root Hubs (1d6b:0002 / 1d6b:0003) to prevent bus EMI sleep glitches
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{power/control}="on", ATTR{power/autosuspend_delay_ms}="-1"

# Disable runtime power management and D3cold for AMD XHCI USB4 controller #4 (0000:05:00.4 - hosts Bluetooth)
ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x161e", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

# Disable D3cold for AMD XHCI USB4 controller #3 sibling (0000:05:00.3)
ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x161d", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

# Disable D3cold for the parent PCIe bridge (0000:00:08.1)
ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x14b9", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"
```

### `/etc/modprobe.d/70-rtw89.conf`
```text
options rtw89_pci disable_aspm_l1=y
options rtw89_pci disable_aspm_l1ss=y
options rtw89_core disable_ps_mode=y
options rtw89_pci disable_clkreq=y

softdep rtw89_8852be pre: btusb
softdep rtw89_pci pre: btusb
```

### `/etc/modprobe.d/btusb.conf`
```text
options btusb enable_autosuspend=n
```

### `/etc/wireplumber/wireplumber.conf.d/10-bluetooth.conf`
```json
monitor.bluez.properties = {
  bluez5.enable-sbc-xq = true
  bluez5.enable-msbc = true
  bluez5.enable-hw-volume = true
  bluez5.hfphsp-backend = "native"
  bluez5.codecs = [ sbc_xq sbc ldac aptx ]
  bluez5.default.rate = 48000
  bluez5.roles = [ a2dp_sink a2dp_source ]
}

monitor.bluez.rules = [
  {
    matches = [
      {
        device.name = "~bluez_card.*"
      }
    ]
    actions = {
      update-props = {
        bluez5.auto-connect = [ a2dp_sink ]
        bluez5.hw-volume = [ a2dp_sink ]
        device.profile = "a2dp-sink-sbc_xq"
      }
    }
  },
  {
    matches = [
      {
        node.name = "~bluez_output.*"
      }
    ]
    actions = {
      update-props = {
        node.latency = 1024/48000
        node.pause-on-idle = false
      }
    }
  }
]
```

---

## 3. Automated Installation

Run `install.sh` from the repository root:

```bash
cd /home/meoclavezz/rtl8852be-arch-fixes
sudo ./install.sh
```
