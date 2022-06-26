#!/usr/bin/env bash
# Usage: pre-install.sh <efi device> <root device>

EFIPART="$1"
SYSTEMPART="$2"

mount "$SYSTEMPART" /mnt

cd /mnt || exit 1

btrfs subvolume create @
btrfs subvolume create @home
btrfs subvolume create @log
btrfs subvolume create @pkg
btrfs subvolume create @.snapshots

cd /root || exit 1

umount /mnt

mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@ "$SYSTEMPART" /mnt
mkdir -p /mnt/{boot,home,var/{cache/pacman/pkg,log},.snapshots}
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@home "$SYSTEMPART" /mnt/home
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@log "$SYSTEMPART" /mnt/var/log
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@pkg "$SYSTEMPART" /mnt/var/cache/pacman/pkg
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@.snapshots "$SYSTEMPART" /mnt/.snapshots
mount "$EFIPART" /mnt/boot

echo "Server = http://192.168.100.204:5200/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

pacstrap /mnt base linux-firmware linux-zen neovim refind openssh btrfs-progs

genfstab -U /mnt > /mnt/etc/fstab

