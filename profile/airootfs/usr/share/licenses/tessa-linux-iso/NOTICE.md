# Licensing and third-party notices

TessaISO build tooling is licensed under the **GNU General Public License,
version 3 or later** (`GPL-3.0-or-later`). The full text is in `LICENSE`.

This repository builds an ISO image and also contains files adapted from
Archiso. Archiso is licensed under `GPL-3.0-or-later`; those files keep that
license and are included here under the same terms.

## Components

| Component | License | Source |
| --- | --- | --- |
| TessaISO build scripts and ISO profile | GPL-3.0-or-later | this repository |
| Tessa compositor, panel, launcher, tools | MIT | https://github.com/Keychrom/Tessa |
| Archiso-derived profile and boot menu files | GPL-3.0-or-later | https://gitlab.archlinux.org/archlinux/archiso |
| Calamares (built from the AUR) | GPL-3.0-or-later | https://github.com/calamares/calamares |
| Arch Linux packages in the live ISO | each package's own license | https://archlinux.org/packages/ |

The Tessa source itself remains MIT-licensed. The `tessa-iso` package in
`package/PKGBUILD` therefore declares `license=('MIT')` for the packaged
desktop. The ISO build tooling around it is GPL-3.0-or-later.

Arch packages usually install their license texts under
`/usr/share/licenses/<package>/`. Tessa's MIT license is installed by the
`tessa-iso` package. A copy of this notice and the GPL text is placed at
`/usr/share/licenses/tessa-linux-iso/` in the live system and in every system
installed from the ISO. The installer downloads the remaining target packages
directly from the Arch Linux mirrors.

## Source code offer

The ISO image contains GPL and LGPL binaries. For at least three years after
an ISO is published, the Tessa contributors offer to any third party a
complete machine-readable copy of the corresponding source code for those
components, on physical media or by download, for no more than the cost of
physically performing the distribution.

Request source through https://github.com/Keychrom/TessaISO/issues (state the
ISO version and the component). The preferred source locations are:

- Tessa: https://github.com/Keychrom/Tessa
- TessaISO: https://github.com/Keychrom/TessaISO
- Archiso: https://gitlab.archlinux.org/archlinux/archiso
- Calamares: https://github.com/calamares/calamares
- Arch package recipes: https://gitlab.archlinux.org/archlinux/packaging/packages
- Arch package sources: `asp export <package>` on Arch Linux

The ISO is a general-purpose live/installer image, not a locked-down hardware
product; no installation information beyond the source above is required for
the GPL components.
