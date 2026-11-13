#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Install the target system from the Arch mirrors. Calamares runs this in the
# live environment after mounting the target, with the mount point as $1.
set -euo pipefail

root=${1:?usage: install-target.sh <target-root>}
mountpoint -q "$root" || {
    echo "install-target: $root is not a mount point" >&2
    exit 1
}

# shellcheck disable=SC2046
pacstrap -C /etc/pacman.d/tessa-install.conf "$root" \
    $(grep -vE '^[[:space:]]*(#|$)' /usr/share/tessa-installer/packages)

cp -a /usr/share/tessa-installer/overlay/. "$root/"
cp /usr/share/tessa-installer/setup.sh "$root/rootfs-setup.sh"
arch-chroot "$root" /rootfs-setup.sh
rm -f "$root/rootfs-setup.sh"
