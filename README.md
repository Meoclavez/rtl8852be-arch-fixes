# Realtek RTL8852BE Wi-Fi & Bluetooth Fixes for Arch Linux (ASUS TUF / AMD)

Automated power management fixes, udev rules, GRUB kernel parameters, WirePlumber audio policies, and sleep hooks for the **Realtek RTL8852BE 802.11ax Wi-Fi & Bluetooth combo module** (`rtw89_8852be` / `btusb`) on Arch Linux under Linux kernels 6.x / 7.x.

---

## 🛠️ Root Causes & Solutions

### 1. Wi-Fi Power Management & D3cold Crashes
On AMD mobile platforms, dynamic PCIe power management cuts clock and voltage to the PCIe slot (`D3cold`), causing firmware lockups (`xtal si not ready`, `failed to leave lps state`, `device inaccessible`).
- **Solution:** Disabled PCIe ASPM (L1/L1ss), clkreq, and driver low-power states in `70-rtw89.conf`. Enforced `d3cold_allowed=0` on the PCIe card (`10ec:b852`) and PCIe root bridge (`1022:14ba`). Added `pci=no_d3cold` to GRUB kernel command line.

### 2. Bluetooth Coexistence & Load Ordering
The combo card shares an internal 2.4GHz RF frontend. Parallel driver initialization causes coexistence arbitration collisions if `rtw89` starts before `btusb` uploads firmware (`rtl8852bu_fw.bin`).
- **Solution:** Configured `softdep rtw89_8852be pre: btusb` and `softdep rtw89_pci pre: btusb` in `70-rtw89.conf`.

### 3. Bluetooth Audio Playback Stability & Buffer Underruns
High-bitrate variable AAC packets and auto-switching to HSP/HFP (SCO) profile during active audio playback cause buffer underruns and link hangs on the Realtek Full-Speed USB endpoint.
- **Solution:**
  - Configured WirePlumber to prioritize **SBC-XQ (SBC Dual Channel High Quality)** (`10-bluetooth.conf`).
  - Disabled `bluetooth.autoswitch-to-headset-profile` in WirePlumber (`11-bluetooth-policy.conf`).
  - Disabled `FastConnectable` in `/etc/bluetooth/main.conf`.

### 4. AMD XHCI USB Root Hub Autosuspend
Kernel runtime power management selectively suspends the AMD XHCI USB 2.0 Root Hub (`usb3`), causing EMI signal drops and device descriptor errors (`error -71`).
- **Solution:** Disabled USB autosuspend for Linux USB root hubs (`1d6b:0002` / `1d6b:0003`) and AMD XHCI controllers in `99-bluetooth-power.rules`, and passed `usbcore.autosuspend=-1` via GRUB.

---

## 📦 Repository Structure

```text
├── install.sh                                # Clean 1-Click installer script
├── uninstall.sh                              # Uninstaller script
├── etc/
│   ├── modprobe.d/
│   │   ├── 70-rtw89.conf                     # Driver module parameters (ASPM, PS mode, softdep)
│   │   └── btusb.conf                        # Disables btusb autosuspend
│   ├── NetworkManager/conf.d/
│   │   └── 99-disable-wifi-powersave.conf    # NetworkManager powersave=2 override
│   ├── wireplumber/wireplumber.conf.d/
│   │   ├── 10-bluetooth.conf                 # WirePlumber SBC-XQ priority & stability
│   │   └── 11-bluetooth-policy.conf          # Disables autoswitch to HFP
│   ├── systemd/system-sleep/
│   │   └── rtw89-suspend-resume.sh           # Systemd sleep/resume driver reset hook
│   └── udev/rules.d/
│       ├── 99-bluetooth-power.rules          # USB Bluetooth & AMD XHCI power control
│       └── 99-rtw89-d3cold.rules             # PCIe Wi-Fi & AMD GPP Root Bridge power control
└── docs/
    ├── wifi_rtw89_fix.md                     # Wi-Fi technical documentation
    └── usb_bluetooth_fix.md                  # Bluetooth technical documentation
```

---

## 🚀 Installation

Run `install.sh` as root:

```bash
cd /home/meoclavezz/rtl8852be-arch-fixes
sudo ./install.sh
```

Then reboot once (`sudo reboot`) to boot with the active kernel parameters.
