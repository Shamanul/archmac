#!/bin/bash
# Instalare completă Arch Linux cu interfață macOS-like pentru utilizatorul "shamanu"
# Șterge complet discul /dev/sda și setează totul automat

disk="/dev/sda"
username="shamanu"
password="30012004"
hostname="shamanu-os"

# Configurare tastatură și timp
loadkeys us
timedatectl set-ntp true

# Partiționare discul
parted -s $disk mklabel msdos
parted -s $disk mkpart primary ext4 1MiB 512MiB
parted -s $disk set 1 boot on
parted -s $disk mkpart primary ext4 512MiB 100%
mkfs.ext4 ${disk}1
mkfs.ext4 ${disk}2

mount ${disk}2 /mnt
mkdir /mnt/boot
mount ${disk}1 /mnt/boot

# Instalare pachete de bază și UI macOS-like
pacstrap /mnt base linux linux-firmware networkmanager grub sudo git xorg   xfce4 xfce4-goodies lightdm lightdm-gtk-greeter plank conky   papirus-icon-theme ttf-dejavu ttf-liberation ttf-droid   feh imagemagick wget curl

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$hostname" > /etc/hostname
cat >> /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOL

echo "root:$password" | chpasswd
useradd -m -G wheel $username
echo "$username:$password" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

grub-install --target=i386-pc --boot-directory=/boot $disk
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable lightdm

# Logo + text SHAMANU
wget -O /usr/share/pixmaps/shamanu-logo.png "https://raw.githubusercontent.com/Shamanul/archnac/main/shamanu-logo.png"
convert -resize 50x50 /usr/share/pixmaps/shamanu-logo.png /usr/share/pixmaps/shamanu-logo-small.png
convert -size 250x50 xc:none   /usr/share/pixmaps/shamanu-logo-small.png -geometry +0+0 -composite   -font Helvetica -pointsize 24 -fill white -draw "text 60,35 'SHAMANU'"   /usr/share/pixmaps/gfx-corner.png

# Wallpaper
wget -O /usr/share/backgrounds/macOS-wallpaper.jpg "https://512pixels.net/downloads/macos-wallpapers/11-0-Daylight.jpg"

# Configurare LightDM cu logo + text
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<GREETER
[greeter]
background=/usr/share/backgrounds/macOS-wallpaper.jpg
theme-name=Adwaita
icon-theme-name=Papirus
font-name=Sans 12
GREETER

# Setare automată interfață pentru utilizator
sudo -u $username bash -c '
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/gfx-corner.desktop <<EOAUTOSTART
[Desktop Entry]
Name=SHAMANU-GFX
Exec=sh -c "sleep 5 && feh --bg-center /usr/share/pixmaps/gfx-corner.png --no-xinerama --geometry +20+20"
Type=Application
EOAUTOSTART
'
# Yay & aplicații din AUR
sudo -u $username bash -c '
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm
yay -S --noconfirm google-chrome pycharm-community-edition
xdg-settings set default-web-browser google-chrome.desktop
'

echo "SHAMANU - Instalare completă terminată."
EOF

umount -R /mnt
echo "Repornește sistemul în 5 secunde..."
sleep 5
reboot
