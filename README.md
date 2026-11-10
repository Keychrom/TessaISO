# TessaISO

Build an Arch Linux based, Japanese-ready **Tessa Linux** live/installer ISO.

The ISO boots into the Tessa Wayland desktop, includes Calamares with a
Japanese UI, and installs offline from a bundled rootfs. The installed system
uses GRUB on both UEFI and BIOS, SDDM, `ja_JP.UTF-8`, Noto CJK fonts, and
fcitx5 + Mozc.

## Build

Requirements: an up-to-date Arch Linux system, a normal user with sudo,
network access, and roughly 10 GB of free disk.

```sh
git clone https://github.com/Keychrom/TessaISO.git
cd TessaISO
./build.sh
```

By default the script clones `Keychrom/Tessa` into
`~/.cache/tessa-iso/tessa-src` and builds against its `main` branch. To build
from a local checkout:

```sh
TESSA_SRC=/path/to/Tessa ./build.sh
```

The first build compiles Calamares from the AUR. Later builds can reuse the
cached package:

```sh
./build.sh --no-calamares
```

Output: `dist/iso/tessa-linux-<date>-x86_64.iso`.

## What is included

- Tessa compositor, panel, launcher, notifications, portals
- Split Tessa config (`config` + `panel.conf`) with Japanese panel defaults
- Calamares offline installer (bundled rootfs, `unpackfsc`)
- Japanese locale, timezone, keyboard, Noto CJK, fcitx5 + Mozc
- Firefox, Thunar, imv, mousepad, file-roller, pavucontrol, kitty
- PipeWire, NetworkManager, Bluetooth
- Optional online update during install when the network is available

## Notes

- The ISO is about 3.4 GB.
- It is **not Secure Boot signed**; disable Secure Boot or enroll your own keys.
- Verified in VirtualBox on UEFI and BIOS, including live desktop, install,
  GRUB boot, SDDM login, locale, and input method.
- Test builds are intentionally not committed; publish the ISO as a release
  artifact through your own storage if needed.
