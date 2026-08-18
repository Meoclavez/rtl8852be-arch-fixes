# Realtek RTL8852BE Wi-Fi & Bluetooth Power & Coexistence Fixes for Arch Linux (ASUS TUF / AMD)

Automated power management fixes, udev rules, delayed-load systemd service, and sleep hooks for the **Realtek RTL8852BE 802.11ax Wi-Fi & Bluetooth combo module** (`rtw89_8852be` / `btusb`) on Arch Linux running Linux kernels 6.x / 7.x.

---

## 🛠️ Root Causes & Solutions

### 1. Wi-Fi Power Management & D3cold Crashes
On AMD mobile platforms, dynamic PCIe power management cuts clock and voltage to the PCIe slot (`D3cold`), causing firmware lockups (`xtal si not ready`, `failed to leave lps state`, `device inaccessible`).
- **Solution:** Disabled PCIe ASPM (L1/L1ss), clkreq, and driver low-power states in `70-rtw89.conf`. Enforced `d3cold_allowed=0` on the PCIe card (`10ec:b852`) and PCIe root bridge (`1022:14ba`).

### 2. Bluetooth Coexistence Collisions (Post-Kernel 7.1)
The combo card shares an internal radio. During boot, `rtw89_8852be` rfkill initialization triggers an internal reset on the USB Bluetooth bus, causing `btusb` to double-initialize and crash after ~4 minutes of active use.
- **Solution:** Blacklisted `btusb` autoloading (`btusb-blacklist.conf`) and created a systemd service (`bt-xhci-reset.service`) that waits 30s after boot for Wi-Fi coexistence to settle before loading `btusb`.

### 3. XHCI USB Controller D3cold Lockups
Kernel 7.1 deprecated `pci=no_d3cold`. When the parent AMD XHCI controller (`1022:161e`) and bridge (`1022:14b9`) enter D3cold, the USB Bluetooth device drops with `error -71`.
- **Solution:** Enforced per-device sysfs rules (`d3cold_allowed=0` and `power/control=on`) in `99-bluetooth-power.rules`.

---

## 📦 Repository Structure

```text
├── install.sh                                # 1-Click installer script
├── uninstall.sh                              # Uninstaller script
├── etc/
│   ├── modprobe.d/
│   │   ├── 70-rtw89.conf                     # Driver module parameters (disables ASPM, LPS, clkreq)
│   │   ├── btusb.conf                        # Disables btusb autosuspend and reset cascade
│   │   └── btusb-blacklist.conf              # Blacklists btusb from premature boot autoload
│   ├── NetworkManager/conf.d/
│   │   └── 99-disable-wifi-powersave.conf    # NetworkManager powersave=2 override
│   ├── systemd/
│   │   ├── system/
│   │   │   └── bt-xhci-reset.service         # Delayed btusb loader service (30s coexistence delay)
│   │   └── system-sleep/
│   │       └── rtw89-suspend-resume.sh       # Systemd sleep/resume driver reset hook
│   └── udev/rules.d/
│       ├── 99-bluetooth-power.rules          # USB Bluetooth & AMD XHCI D3cold power control
│       └── 99-rtw89-d3cold.rules             # PCIe Wi-Fi & AMD GPP Root Bridge power control
└── docs/
    ├── wifi_rtw89_fix.md                     # Wi-Fi technical documentation
    └── usb_bluetooth_fix.md                  # Bluetooth & udev technical documentation
```

---

## 🚀 Quick Installation

Clone the repository and run `install.sh` as root:

```bash
git clone https://github.com/Meoclavez/rtl8852be-arch-fixes.git
cd rtl8852be-arch-fixes
sudo ./install.sh
```

---

## 📄 License
MIT License. Free to use, modify, and distribute.
