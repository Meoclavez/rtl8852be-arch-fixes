# Realtek RTL8852BE Wi-Fi & Bluetooth Power Fixes for Arch Linux (ASUS TUF / AMD)

Automated power management fixes, udev rules, systemd sleep hooks, and automatic hardware recovery hooks for the **Realtek RTL8852BE 802.11ax Wi-Fi & Bluetooth combo module** (`rtw89_8852be` / `btusb`) on Arch Linux running Linux kernel 6.x / 7.x.

---

## 🛠️ Issues Addressed

1. **Low Power State (LPS) & PCIe D3cold Crashes**:
   - Prevents `rtw89_8852be` from dropping into unrecoverable PCIe low-power states (`xtal si not ready(W)` / `mac preinit fail, ret: -110`).
2. **Bluetooth USB Bus Disconnections**:
   - Fixes udev syntax errors (`No such file or directory` on `usb_interface`) and disables autosuspend on Realtek Bluetooth (`13d3:3571`) and AMD USB4 XHCI controller (`1022:161e`).
3. **Automated Sleep & Resume Recovery**:
   - Unloads the `rtw89` driver stack cleanly before suspend and reloads + rescans PCIe link on resume (`/etc/systemd/system-sleep/rtw89-suspend-resume.sh`).
4. **Automated Radio Toggle Recovery**:
   - Automatically performs an inline hardware Function Level Reset (FLR) and re-probes `rtw89_8852be` whenever Wi-Fi is toggled back ON in KDE System Tray, NetworkManager, or Fn hotkeys (`/etc/udev/rules.d/99-rtw89-rfkill-hook.rules`).

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
│       ├── 99-rtw89-d3cold.rules             # PCIe Wi-Fi & AMD GPP Root Bridge power control
│       └── 99-rtw89-rfkill-hook.rules        # Radio toggle-on udev trigger
├── usr/local/bin/
│   └── rtw89-toggle-on-hook.sh               # FLR hardware reset & recovery script
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

## 🔍 Verification

Check Wi-Fi and Bluetooth status after installation:

```bash
nmcli device status
lsusb | grep -i bluetooth
rfkill list
```

---

## 📄 License
MIT License. Free to use, modify, and distribute.
