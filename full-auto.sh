#!/bin/bash
# FULL AUTOMATIC INSTALL SCRIPT WITH CUSTOM BRANDING (Logo + "SHAMANU")
# WARNING: This script will ERASE the entire disk (/dev/sda) and install Arch Linux.
# Customize the following variables as needed.
disk="/dev/sda"
username="user"
password="password"
hostname="shamanu"

# Set keyboard layout and enable network time
loadkeys us
timedatectl set-ntp true

# Wipe and partition the disk (MBR is destroyed; GPT is created)
sgdisk -Z $disk
# Create a 512MB EFI System Partition and use the rest as Linux root
sgdisk -n 1::+512M -t 1:ef00 -c 1:"EFI" $disk
sgdisk -n 2:: -t 2:8300 -c 2:"Linux" $disk

# Format partitions
mkfs.fat -F32 ${disk}1
mkfs.ext4 ${disk}2

# Mount partitions
mount ${disk}2 /mnt
mkdir /mnt/boot
mount ${disk}1 /mnt/boot

# Install the base system and additional packages
pacstrap /mnt base linux linux-firmware networkmanager grub efibootmgr sudo git xorg \
         xfce4 xfce4-goodies lightdm lightdm-gtk-greeter plank

# Generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the new system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Generate locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname and hosts file
echo "$hostname" > /etc/hostname
cat <<EOL >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOL

# Set root password
echo "root:$password" | chpasswd

# Install bootloader (GRUB)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable necessary services
systemctl enable NetworkManager
systemctl enable lightdm

# Create a new user and give sudo rights
useradd -m -G wheel $username
echo "$username:$password" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# --- Begin Custom Branding Section ---

# Download and install the custom logo image and wallpaper.
# (Ensure that the URL points to your online hosted image file)
wget -O /usr/share/pixmaps/shamanu.png "https://raw.githubusercontent.com/yourrepo/archmac/main/shamanu.png"

# Create a custom wallpaper by (for example) copying the logo onto a background.
# For simplicity, here we assume you have a pre-made wallpaper available online.
wget -O /usr/share/backgrounds/shamanu-wallpaper.png "https://raw.githubusercontent.com/yourrepo/archmac/main/shamanu-wallpaper.png"

# Configure LightDM to use the custom wallpaper.
# (LightDM GTK+ Greeter uses the "background" option; this sets it to our branded wallpaper.)
if [ -f /etc/lightdm/lightdm-gtk-greeter.conf ]; then
  sed -i 's|^#background=.*|background=/usr/share/backgrounds/shamanu-wallpaper.png|' /etc/lightdm/lightdm-gtk-greeter.conf
else
  cat <<GREETER_EOF > /etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
background=/usr/share/backgrounds/shamanu-wallpaper.png
# You can add additional options here if your greeter supports them.
GREETER_EOF
fi

# Optionally, set a custom welcome message in /etc/motd that includes SHAMANU branding.
echo "" > /etc/motd
echo "*     Welcome to SHAMANU Linux         *" >> /etc/motd
echo "" >> /etc/motd

# --- End Custom Branding Section ---

# Install additional AUR helpers and packages as the new user.
# First, install 'yay' for AUR access.
sudo -u $username bash -c '
  cd ~
  git clone https://aur.archlinux.org/yay.git &&
  cd yay &&
  makepkg -si --noconfirm
'

# Install Google Chrome via yay as the default browser.
sudo -u $username yay -S --noconfirm google-chrome

# Set Google Chrome as default (run as the new user)
sudo -u $username xdg-settings set default-web-browser google-chrome.desktop

# Install PyCharm Community Edition via yay.
sudo -u $username yay -S --noconfirm pycharm-community-edition

# Optional: Customize XFCE desktop background to use the custom wallpaper.
# This sets the XFCE desktop background for the logged-in user.
sudo -u $username xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s /usr/share/backgrounds/shamanu-wallpaper.png || true

# You can also add additional XFCE panel configuration modifications here if needed.

EOF

# Unmount and reboot.
umount -R /mnt
echo "Installation complete. Rebooting now..."
reboot