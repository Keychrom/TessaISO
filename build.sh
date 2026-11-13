#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Build a Tessa Linux ISO: Arch base + Tessa session + Japanese input,
# installed online by Calamares with pacstrap from the Arch mirrors.
#
# Run as a normal Arch user on an up-to-date Arch system. The script uses sudo
# for package installation, pacstrap, chroot setup, and mkarchiso.
#
#   ./build.sh                              # full build
#   ./build.sh --no-calamares               # reuse an existing Calamares package
#   TESSA_SRC=/path/to/Tessa ./build.sh      # build from a local Tessa checkout
#   TESSA_ISO_BUILD=/var/tmp/build ./build.sh
#
# Without TESSA_SRC the script clones Keychrom/Tessa into
# ~/.cache/tessa-iso/tessa-src and builds from its main branch.
#
# Output: dist/iso/tessa-linux-<date>-x86_64.iso
set -euo pipefail

ISO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR=${TESSA_ISO_BUILD:-/var/tmp/tessa-iso}
CACHE_DIR=${TESSA_ISO_CACHE:-/var/cache/tessa-iso}
REPO_DIR=$BUILD_DIR/repo
PKG_DIR=$CACHE_DIR/packages
PROFILE_DIR=$BUILD_DIR/profile
WORK_DIR=$BUILD_DIR/work
OUT_DIR=${TESSA_ISO_OUT:-$ISO_DIR/dist/iso}
PROFILE_SRC=$ISO_DIR/profile
JOBS=${JOBS:-$(nproc)}
SKIP_CALAMARES=0

for arg in "$@"; do
    case "$arg" in
        --no-calamares) SKIP_CALAMARES=1 ;;
        -h|--help)
            sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# BUILD_DIR is removed recursively below; refuse paths that would wipe the
# system or a home directory if the caller sets TESSA_ISO_BUILD badly.
case "$BUILD_DIR" in
    /|/home|/root|"$HOME"|"") die "unsafe TESSA_ISO_BUILD: $BUILD_DIR" ;;
esac

[ "$(id -u)" -ne 0 ] || die "run as a normal user; the script invokes sudo itself"
command -v pacman >/dev/null || die "this script must run on Arch Linux"
command -v makepkg >/dev/null || die "install base-devel first"

log "package build dependencies"
sudo -v
sudo pacman -S --needed --noconfirm \
    archiso squashfs-tools libisoburn mtools dosfstools syslinux grub efibootmgr \
    base-devel git rsync zstd librsvg imagemagick python

if [ -z "${TESSA_SRC:-}" ]; then
    TESSA_SRC=${TESSA_SRC_CACHE:-$HOME/.cache/tessa-iso/tessa-src}
    if [ -d "$TESSA_SRC/.git" ]; then
        log "updating Tessa source in $TESSA_SRC"
        git -C "$TESSA_SRC" fetch --depth=1 origin main
        git -C "$TESSA_SRC" reset --hard FETCH_HEAD
    else
        log "cloning Keychrom/Tessa into $TESSA_SRC"
        mkdir -p "$(dirname -- "$TESSA_SRC")"
        git clone --depth=1 https://github.com/Keychrom/Tessa.git "$TESSA_SRC"
    fi
fi
[ -f "$TESSA_SRC/src/main.zig" ] || die "TESSA_SRC is not a Tessa checkout: $TESSA_SRC"

sudo rm -rf "$BUILD_DIR"
sudo install -d -o "$(id -u)" -g "$(id -g)" "$CACHE_DIR" "$PKG_DIR"
mkdir -p "$BUILD_DIR" "$REPO_DIR" "$OUT_DIR" "$BUILD_DIR/pacman-cache"

log "building tessa-iso package"
TESSA_PKG=$BUILD_DIR/pkg-tessa
mkdir -p "$TESSA_PKG"
tar --exclude=.git --exclude=.zig-cache --exclude=zig-out --exclude=dist \
    --exclude='*.iso' \
    --transform 's|^\./|tessa/|' \
    -czf "$TESSA_PKG/tessa.tar.gz" -C "$TESSA_SRC" .
cp "$ISO_DIR/package/PKGBUILD" "$TESSA_PKG/PKGBUILD"
(
    cd "$TESSA_PKG"
    makepkg -f --noconfirm -s
)
cp "$TESSA_PKG"/*.pkg.tar.zst "$PKG_DIR/"

if [ "$SKIP_CALAMARES" -eq 0 ]; then
    log "building calamares from the AUR"
    CALAMARES_SRC=$BUILD_DIR/aur-calamares
    git clone --depth=1 https://aur.archlinux.org/calamares.git "$CALAMARES_SRC"
    (
        cd "$CALAMARES_SRC"
        makepkg -f --noconfirm -s
    )
    cp "$CALAMARES_SRC"/*.pkg.tar.zst "$PKG_DIR/"
else
    log "reusing calamares package from $PKG_DIR"
    compgen -G "$PKG_DIR/calamares-*.pkg.tar.zst" >/dev/null ||
        die "--no-calamares given but no calamares package is in $PKG_DIR"
fi

log "local package repository"
cp "$PKG_DIR"/*.pkg.tar.zst "$REPO_DIR/"
repo-add "$REPO_DIR/tessa-iso.db.tar.gz" "$REPO_DIR"/*.pkg.tar.zst

write_pacman_conf() {
    local dest=$1
    cat > "$dest" <<EOF
[options]
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Never
CacheDir = $BUILD_DIR/pacman-cache

[core]
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch

[extra]
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch

[multilib]
Server = https://geo.mirror.pkgbuild.com/\$repo/os/\$arch

[tessa-iso]
Server = file://$REPO_DIR
EOF
}
write_pacman_conf "$BUILD_DIR/pacman-build.conf"
write_pacman_conf "$BUILD_DIR/pacman-profile.conf"

log "preparing the live ISO profile"
rm -rf "$PROFILE_DIR"
cp -a "$PROFILE_SRC" "$PROFILE_DIR"
cp "$BUILD_DIR/pacman-profile.conf" "$PROFILE_DIR/pacman.conf"

# mkarchiso installs live packages with signature checks disabled, so the
# live keyring can be empty. pacstrap copies this keyring into the target;
# populate it here so the online install can verify the downloaded packages.
install -d "$PROFILE_DIR/airootfs/etc/pacman.d/gnupg"
sudo pacman-key --gpgdir "$PROFILE_DIR/airootfs/etc/pacman.d/gnupg" --init
sudo pacman-key --gpgdir "$PROFILE_DIR/airootfs/etc/pacman.d/gnupg" --populate archlinux
install -d "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /etc/systemd/system/tessa-live-home.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/multi-user.target.wants/tessa-live-home.service"
ln -sf /usr/lib/systemd/system/sddm.service \
    "$PROFILE_DIR/airootfs/etc/systemd/system/display-manager.service"
ln -sf /usr/lib/systemd/system/graphical.target \
    "$PROFILE_DIR/airootfs/etc/systemd/system/default.target"
ln -sf /usr/share/zoneinfo/Asia/Tokyo \
    "$PROFILE_DIR/airootfs/etc/localtime"
ln -sf /dev/null \
    "$PROFILE_DIR/airootfs/etc/systemd/system/systemd-firstboot.service"

# Calamares' Python job modules import libcalamares from /usr/lib/calamares.
# The AUR package does not add that directory to the embedded interpreter's
# search path, so expose it explicitly for the live session.
pyver=$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
pyroot="$PROFILE_DIR/airootfs/usr/lib/python${pyver}"
install -d "$pyroot/site-packages"
printf '/usr/lib/calamares\n' > "$pyroot/site-packages/calamares.pth"
ln -sfn /usr/lib/libcalamares.so "$pyroot/libcalamares.so"
convert "$TESSA_SRC/docs/images/mosaic.png" -resize 640x480^ -gravity center \
    -extent 640x480 -fill '#0a0f1a' -colorize 35% "$PROFILE_DIR/syslinux/splash.png"
log "preparing the installer payload"
INSTALLER_DIR="$PROFILE_DIR/airootfs/usr/share/tessa-installer"
install -d "$INSTALLER_DIR/repo" "$INSTALLER_DIR/overlay/etc/skel" \
    "$INSTALLER_DIR/overlay/etc/profile.d" \
    "$INSTALLER_DIR/overlay/etc/xdg/autostart" \
    "$INSTALLER_DIR/overlay/usr/share/licenses/tessa-linux-iso" \
    "$INSTALLER_DIR/overlay/usr/share/tessa/themes/vermilion-ink" \
    "$PROFILE_DIR/airootfs/etc/pacman.d"
grep -vE '^[[:space:]]*(#|$)' "$ISO_DIR/rootfs/packages.x86_64" \
    > "$INSTALLER_DIR/packages"
cp "$ISO_DIR/rootfs/setup.sh" "$INSTALLER_DIR/setup.sh"
cp -a "$ISO_DIR/profile/airootfs/etc/skel/." "$INSTALLER_DIR/overlay/etc/skel/"
install -m644 "$ISO_DIR/profile/airootfs/etc/environment" \
    "$INSTALLER_DIR/overlay/etc/environment"
install -m644 "$ISO_DIR/profile/airootfs/etc/profile.d/tessa-ime.sh" \
    "$INSTALLER_DIR/overlay/etc/profile.d/tessa-ime.sh"
install -m644 "$ISO_DIR/profile/airootfs/etc/xdg/autostart/fcitx5-tessa.desktop" \
    "$INSTALLER_DIR/overlay/etc/xdg/autostart/fcitx5-tessa.desktop"
install -m644 "$ISO_DIR/LICENSE" \
    "$INSTALLER_DIR/overlay/usr/share/licenses/tessa-linux-iso/LICENSE"
install -m644 "$ISO_DIR/NOTICE.md" \
    "$INSTALLER_DIR/overlay/usr/share/licenses/tessa-linux-iso/NOTICE.md"
cp -a "$TESSA_SRC/examples/themes/vermilion-ink/." \
    "$INSTALLER_DIR/overlay/usr/share/tessa/themes/vermilion-ink/"
for pkg in "$PKG_DIR"/tessa-iso-*.pkg.tar.zst; do
    case "$pkg" in *-debug*) continue ;; esac
    cp "$pkg" "$INSTALLER_DIR/repo/"
done
repo-add "$INSTALLER_DIR/repo/tessa-iso.db.tar.gz" \
    "$INSTALLER_DIR"/repo/tessa-iso-*.pkg.tar.zst

# Pacman configuration used by the installer's pacstrap step. The target gets
# a normal pacman.conf from the pacman package; this file only feeds the
# offline-accessible Tessa package to the online install.
cat > "$PROFILE_DIR/airootfs/etc/pacman.d/tessa-install.conf" <<'EOF'
[options]
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Required DatabaseOptional
CacheDir = /var/cache/pacman/pkg

[core]
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch

[extra]
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch

[multilib]
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch

[tessa-local]
SigLevel = Optional TrustAll
Server = file:///usr/share/tessa-installer/repo
EOF
cp "$ISO_DIR/branding/logo.svg" "$PROFILE_DIR/airootfs/etc/calamares/branding/tessa/logo.svg"
rsvg-convert -w 160 -h 160 "$ISO_DIR/branding/logo.svg" \
    -o "$PROFILE_DIR/airootfs/etc/calamares/branding/tessa/logo.png"
for image in mosaic launcher ime; do
    convert "$TESSA_SRC/docs/images/$image.png" -resize 1280x720^ \
        -gravity center -extent 1280x720 \
        "$PROFILE_DIR/airootfs/etc/calamares/branding/tessa/$image.png"
done

log "building the ISO"
sudo mkarchiso -v -r -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

iso=$(find "$OUT_DIR" -maxdepth 1 -name 'tessa-linux-*.iso' -printf '%T@ %p\n' |
    sort -n | tail -1 | cut -d' ' -f2-)
[ -n "$iso" ] || die "mkarchiso did not produce an ISO"
log "done: $iso"
