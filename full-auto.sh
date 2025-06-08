#!/bin/bash
set -e

echo "===> Arch Linux + KDE Plasma 6 Auto Installer (with numbered disk select)"

# -------- DISK SELECTION --------
echo "===> Scanning for available disks..."

DISK_LIST=()
while IFS= read -r line; do
    DISK_LIST+=("$line")
done < <(lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr" | tail -n +2)

if [ ${#DISK_LIST[@]} -eq 0 ]; then
    echo "❌ No physical disks detected!"
    exit 1
fi

echo "Available disks:"
for i in "${!DISK_LIST[@]}"; do
    disk_info="${DISK_LIST[$i]}"
    disk_name=$(echo "$disk_info" | awk '{print $1}')
    disk_size=$(echo "$disk_info" | awk '{print $2}')
    disk_model=$(echo "$disk_info" | cut -d' ' -f3-)
    echo "  [$i] /dev/$disk_name - $disk_size - $disk_model"
done

read -p "Enter the number of the disk to use: " DISK_NUM

if ! [[ "$DISK_NUM" =~ ^[0-9]+$ ]] || [ "$DISK_NUM" -ge "${#DISK_LIST[@]}" ]; then
    echo "❌ Invalid selection."
    exit 1
fi

DISK="/dev/$(echo "${DISK_LIST[$DISK_NUM]}" | awk '{print $1}')"
echo "✅ Selected disk: $DISK"

# -------- USER INPUT --------
read -p "Enter hostname: " HOSTNAME
read -p "Enter username: " USERNAME
read -s -p "Enter password for root and $USERNAME: " PASSWORD
echo

# -------- INTERNET CHECK --------
ping -c 1 archlinux.org &>/dev/null || {
    echo "⚠  No internet detected. Run 'iwctl' for Wi-Fi or plug in Ethernet."
    read -p "Press Enter to continue when connected..."
}

# -------- SETUP --------
loadkeys us
timedatectl set-ntp true

echo "===> Partitioning disk (MBR mode)..."
sleep 3

(
echo o      # new MBR
echo n      # partition 1
echo p
echo 1
echo
echo +512M
echo n      # partition 2
echo p
echo 2
echo
echo
echo a      # bootable flag
echo 1
echo w
) | fdisk "$DISK"

PART_BOOT="${DISK}1"
PART_ROOT="${DISK}2"

echo "===> Formatting partitions..."
mkfs.ext4 "$PART_ROOT"
mkfs.ext4 "$PART_BOOT"

echo "===> Mounting..."
mount "$PART_ROOT" /mnt
mkdir /mnt/boot
mount "$PART_BOOT" /mnt/boot

# -------- INSTALL BASE SYSTEM --------
pacstrap /mnt base linux linux-firmware vim nano networkmanager sudo

genfstab -U /mnt >> /mnt/etc/fstab

# -------- CHROOT CONFIGURATION --------
arch-chroot /mnt /bin/bash <<EOF

# Time & Locale
ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname
cat <<EOT >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

# User and Root
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Bootloader
pacman -Sy --noconfirm grub
grub-install --target=i386-pc $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# Swap file
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab

# Enable NetworkManager
systemctl enable NetworkManager

# KDE Plasma 6
pacman -Sy --noconfirm xorg plasma-desktop dolphin konsole sddm

systemctl enable sddm

# Utilities
pacman -Sy --noconfirm firefox neofetch htop tlp
systemctl enable tlp

# Enable multilib
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
pacman -Sy

EOF

# -------- FINISH --------
echo "===> Done. Unmounting and rebooting..."
umount -R /mnt
reboot
