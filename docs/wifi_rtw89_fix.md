# Realtek RTL8852BE Wi-Fi Configuration Fixes on Arch Linux

This document details the troubleshooting, root cause analysis, and configuration fixes applied to resolve the stability and power management issues with the **Realtek RTL8852BE 802.11ax Wireless Network Controller** (`rtw89_8852be` driver).

---

## 1. Description of the Problem

The Wi-Fi interface (`wlp3s0`) experienced two distinct failure modes:

1. **Low Power State (LPS) Wake-up Crashes:**
   - **Symptoms:** Under active use or waking from sleep, Wi-Fi would stop working entirely. The interface would disappear or stay `unavailable` in NetworkManager.
   - **Underlying Errors (from `journalctl` / `dmesg`):**
     - `rtw89_8852be 0000:03:00.0: rtw89: failed to leave lps state`
     - `rtw89_8852be 0000:03:00.0: failed to pre-release fwcmd`
     - `rtw89_8852be 0000:03:00.0: write rf busy swsi`

2. **Battery-Power Connection Drops & Oscillator Timeouts:**
   - **Symptoms:** When unplugged from AC power, the card would fail to scan or connect, triggering a soft-block cycle.
   - **Underlying Errors (from `journalctl` / `dmesg`):**
     - `wlp3s0: CTRL-EVENT-SCAN-FAILED ret=-110` (ETIMEDOUT)
     - `rtw89_8852be 0000:03:00.0: xtal si not ready(W): offset=90 val=10 mask=10`
     - `rtw89_8852be 0000:03:00.0: mac preinit fail, ret: -110`

### Root Cause Analysis
Realtek RTL8852BE chipsets suffer from severe power-saving state incompatibilities with modern Linux PCIe power management. 
- When the host system dynamically cuts reference clocks or voltages to the PCIe slot (either through ASPM/CLKREQ or during battery runtime autosuspend), the card's firmware hangs and fails to re-initialize the crystal oscillator (`xtal`), throwing timeouts (`-110`).
- NetworkManager's built-in Wi-Fi power-save mechanism further aggravates the problem by requesting the driver to toggle power states dynamically.

---

## 2. Config Paths & Modifications Applied

To achieve stable connectivity, power-saving features have been disabled at three layers: the kernel driver module parameters, the network daemon settings, and the PCIe hardware runtime rules.

### A. Kernel Command Line (`/etc/default/grub`)
- **Path:** `/etc/default/grub`
- **Modifications:** Added `pci=no_d3cold` to `GRUB_CMDLINE_LINUX_DEFAULT` to prevent kernel ACPI power management from cutting slot link power (`Unable to change power state from D3cold to D0, device inaccessible`).
- **Configuration Content:**
  ```text
  GRUB_CMDLINE_LINUX_DEFAULT="... pcie_aspm=off pci=noaer pci=no_d3cold"
  ```

### B. Kernel Driver Module Parameters
- **Path:** `/etc/modprobe.d/70-rtw89.conf`
- **Modifications:** Added options to disable PCIe ASPM (Active State Power Management) L1/L1SS states, driver low-power state (LPS) mode, and dynamic clock requests (CLKREQ).
- **Configuration Content:**
  ```text
  options rtw89_pci disable_aspm_l1=y
  options rtw89_pci disable_aspm_l1ss=y
  options rtw89_core disable_ps_mode=y
  options rtw89_pci disable_clkreq=y
  ```

### B. NetworkManager Power Management
- **Paths:** `/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf` and `/etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf`
- **Modifications:** Explicitly disabled the 802.11 wireless power-saving layer managed by NetworkManager (`wifi.powersave = 2`).
- **Configuration Content:**
  ```ini
  [connection]
  wifi.powersave = 2
  ```

### C. PCIe Slot State & Runtime Rules (udev)
- **Path:** `/etc/udev/rules.d/99-rtw89-d3cold.rules`
- **Modifications:** Restricted the Realtek card (`10ec:b852`) from entering the deepest PCIe sleep state (`D3cold`) and forced runtime power control `on`. Additionally disabled runtime autosuspend on the parent AMD PCIe GPP Bridge (`1022:14ba` / `0000:00:02.2`) to prevent slot power drops during crystal oscillator (`xtal`) initialization.
- **Configuration Content:**
  ```udev
  # Disable D3cold and enforce power control ON for Realtek RTL8852BE Wi-Fi (10ec:b852)
  ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0xb852", ATTR{d3cold_allowed}="0", ATTR{power/control}="on"

  # Disable runtime power management for AMD PCIe GPP Bridge (1022:14ba)
  ACTION=="add|change", SUBSYSTEM=="pci", ATTRS{vendor}=="0x1022", ATTRS{device}=="0x14ba", ATTR{power/control}="on"
  ```

---

## 3. Verification Commands

Run the following commands to check if the fixes are loaded and active:

1. **Verify udev/PCI runtime state:**
   ```bash
   cat /sys/bus/pci/devices/0000:03:00.0/d3cold_allowed  # Expected output: 0
   cat /sys/bus/pci/devices/0000:03:00.0/power/control   # Expected output: on
   ```

2. **Verify active driver module parameters:**
   ```bash
   cat /sys/module/rtw89_core/parameters/disable_ps_mode  # Expected output: Y
   cat /sys/module/rtw89_pci/parameters/disable_clkreq    # Expected output: Y
   ```

3. **Verify NetworkManager wifi power-save setting:**
   ```bash
   iw dev wlp3s0 get power_save                           # Expected output: Power save: off
   ```

---

## 4. Automated Sleep & Resume Hook (Systemd)

To automatically prevent low-power state crystal oscillator (`xtal`) freezes and driver stalls when entering/exiting sleep, a systemd sleep hook is installed at `/etc/systemd/system-sleep/rtw89-suspend-resume.sh`:

- **Pre-suspend (`pre`):** Unloads `rtw89` kernel modules before sleep to ensure firmware power states close cleanly.
- **Post-resume (`post`):** Forces PCIe bridge power `on`, triggers a PCI bus rescan, reloads `rtw89_8852be`, and unblocks `rfkill`.

---

## 5. Automated Wi-Fi Radio Toggle-On Hook (udev & FLR)

Whenever Wi-Fi is toggled ON in KDE, NetworkManager, or via Fn hotkeys (`rfkill unblock wifi` / `nmcli radio wifi on`), udev rule `/etc/udev/rules.d/99-rtw89-rfkill-hook.rules` automatically runs `/usr/local/bin/rtw89-toggle-on-hook.sh`.

- **Detection:** Triggers on `ACTION=="change", SUBSYSTEM=="rfkill", ATTR{type}=="wlan", ATTR{soft}=="0"`.
- **Auto-Recovery:** Checks if `wlp3s0` hardware is stuck or unresponsive. If so, it performs an inline hardware Function Level Reset (FLR) via `/sys/bus/pci/devices/0000:03:00.0/reset` and reloads `rtw89_8852be` seamlessly in <1 second.

---

## 6. Emergency Recovery (Manual Fallback)

If needed, `/home/meoclavezz/apply_fix.sh` can also be run manually:

```bash
sudo /home/meoclavezz/apply_fix.sh
```
