# Realtek RTL8852BE Wi-Fi & Bluetooth Power Fixes for Arch Linux (ASUS TUF / AMD)

Automated power management fixes, udev rules, and systemd sleep hooks for the **Realtek RTL8852BE 802.11ax Wi-Fi & Bluetooth combo module** (`rtw89_8852be` / `btusb`) on Arch Linux running Linux kernel 6.x / 7.x.

---

## 🛠️ Root Cause & Solution

On AMD mobile platforms, ACPI power management puts the M.2 slot into `D3cold` (power cut) during idle or radio off states. When turning Wi-Fi back ON, ACPI power-on fails with `Unable to change power state from D3cold to D0, device inaccessible`, causing `xtal si not ready` firmware lockups.

**Solution:**
1. Added **`pci=no_d3cold`** to kernel parameters in `/etc/default/grub`.
2. Disabled PCIe D3cold and forced runtime power control `on` for both the Realtek card (`10ec:b852`) and AMD PCIe Root Bridge (`1022:14ba`).
3. Added systemd sleep hook (`/etc/systemd/system-sleep/rtw89-suspend-resume.sh`) for clean suspend/resume.

---

## 📦 Repository Structure

```text
├── install.sh                                # 1-Click installer script
├── uninstall.sh                              # Uninstaller script
├── etc/
│   ├── modprobe.d/
│   │   ├── 70-rtw89.conf                     # Driver module parameters (disables ASPM, LPS, clkreq)
│   │   └── btusb.conf                        # Disables btusb module autosuspend
│   ├── NetworkManager/conf.d/
│   │   └── 99-disable-wifi-powersave.conf    # NetworkManager powersave=2 override
│   ├── systemd/system-sleep/
│   │   └── rtw89-suspend-resume.sh           # Systemd sleep/resume driver reset hook
│   └── udev/rules.d/
│       ├── 99-bluetooth-power.rules          # USB Bluetooth device level power control
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
