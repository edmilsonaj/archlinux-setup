#!/usr/bin/env bash
# Usage: bash post-install <root device>

# Set locale for installation
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "LANG=\"en_US.UTF-8\"" > /etc/locale.conf
export LANG="en_US.UTF-8"
export LC_COLLATE="C"
locale-gen

# Packages for base install
pacman -S --noconfirm \
    ansible\
    base-devel \
    bash-completion \
    git \
    linux-zen-headers\
    networkmanager

# mkinitpcpio
echo "KEYMAP=us-acentos" > /etc/vconsole.conf
sed -i 's/^HOOKS.*/HOOKS=(base systemd autodetect modconf block sd-vconsole sd-encrypt filesystems keyboard fsck)/' /etc/mkinitcpio.conf
sed -i 's/^MODULES.*/MODULES=(btrfs)/' /etc/mkinitcpio.conf

mkinitcpio -P

# We revert this with Ansible afterwards
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/sshd_config

# Enable base services
systemctl enable NetworkManager
systemctl enable sshd

# Bootloader

refind-install
rm /boot/refind_linux.conf

UUID=$(blkid "$1" | cut -d " " -f 2 | cut -d \" -f 2)

cat << EOF > /boot/EFI/refind/refind.conf
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
echo root:password | chpasswd