#!/usr/bin/env bash
# Usage: pre-install.sh <efi device> <root device>

EFIPART=/dev/vda1
CRYPTPART=/dev/vda2
MAPPERNAME=Linux

# Creates the encrypted volume
cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --verify-passphrase luksFormat "$CRYPTPART"
cryptsetup luksOpen "$CRYPTPART" "$MAPPERNAME"

# Format the partitions
mkfs.vfat -F32 -n "EFI" "$EFIPART"
mkfs.btrfs -L ARCH /dev/mapper/"$MAPPERNAME"

# Mount the BTRFS volume and create subvolumes
mount /dev/mapper/"$MAPPERNAME" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@.snapshots

umount /mnt

mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@ /dev/mapper/"$MAPPERNAME" /mnt
mkdir -p /mnt/{boot,home,var/{cache/pacman/pkg,log},.snapshots}
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@home /dev/mapper/"$MAPPERNAME" /mnt/home
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@log /dev/mapper/"$MAPPERNAME" /mnt/var/log
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@pkg /dev/mapper/"$MAPPERNAME" /mnt/var/cache/pacman/pkg
mount -o relatime,compress=zstd:3,ssd,space_cache=v2,discard=async,subvol=@.snapshots /dev/mapper/"$MAPPERNAME" /mnt/.snapshots
mount "$EFIPART" /mnt/boot

# Change to my pessoal pacman cache server
echo "Server = http://192.168.100.204:5200/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

# Packages for base install
pacstrap /mnt ansible base base-devel bash-completion btrfs-progs git iptables-nft linux-firmware linux-zen linux-zen-headers neovim networkmanager openssh refind

# Create the fstab on the new system
genfstab -U /mnt > /mnt/etc/fstab

# Set locales for installation
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=\"en_US.UTF-8\"" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# Configure mkinitcpio
echo "KEYMAP=us-acentos" > /mnt/etc/vconsole.conf
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect modconf block sd-vconsole sd-encrypt filesystems keyboard fsck)/' /mnt/etc/mkinitcpio.conf
sed -i 's/^MODULES.*/MODULES=(btrfs)/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

# We revert this with Ansible afterwards
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /mnt/etc/ssh/sshd_config

# Enable base services
arch-chroot /mnt systemctl enable --now NetworkManager
arch-chroot /mnt systemctl enable --now sshd

# Bootloader
arch-chroot /mnt refind-install
rm /mnt/boot/refind_linux.conf

UUID=$(blkid "$CRYPTPART" | cut -d " " -f 2 | cut -d \" -f 2)

cat << EOF > /mnt/boot/EFI/refind/refind.conf
scanfor manual,external
use_graphics_for linux
use_nvram false
timeout 20

menuentry "Arch Linux Zen" {

    icon    /EFI/refind/icons/os_arch.png
    volume  "EFI"
    loader  /vmlinuz-linux-zen
    initrd  /initramfs-linux-zen.img
    options "rd.luks.name=$UUID=Linux root=/dev/mapper/Linux rootflags=subvol=@ rw quiet"

    submenuentry "Boot using fallback initramfs" {
        initrd /initramfs-linux-zen-fallback.img
    }
}

EOF

# Set root password

echo -e '#!/bin/bash\necho root:password | chpasswd' > /mnt/root/passwd.sh

arch-chroot /mnt bash /root/passwd.sh

rm /mnt/root/passwd.sh