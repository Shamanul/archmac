#!/bin/bash
# FULL AUTOMATIC LEGACY INSTALL SCRIPT FOR OLDER HARDWARE
# Compatibil cu sisteme BIOS Legacy (non-UEFI) și HDD-uri vechi

# Configurație
disk="/dev/sda"       # Înlocuiește cu discul tău
username="user"
password="password"
hostname="shamanu"

# Setări inițiale
loadkeys us
timedatectl set-ntp true

# Șterge și creează partiții MBR
echo "Creare tabel partiții MBR..."
parted -s $disk mklabel msdos
parted -s $disk mkpart primary ext4 1MiB 512MiB
parted -s $disk set 1 boot on      # Activează boot flag pentru BIOS
parted -s $disk mkpart primary ext4 512MiB 100%

# Formatează partițiile
echo "Formatare partiții..."
mkfs.ext4 ${disk}1    # /boot
mkfs.ext4 ${disk}2    # /

# Montează partițiile
echo "Montare partiții..."
mount ${disk}2 /mnt
mkdir /mnt/boot
mount ${disk}1 /mnt/boot

# Instalare pachete (fără componente UEFI)
echo "Instalare sistem de bază..."
pacstrap /mnt base linux linux-firmware networkmanager grub \
          sudo git xorg xfce4 xfce4-goodies \
          lightdm lightdm-gtk-greeter plank

# Generare fișier fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configurare sistem în chroot
arch-chroot /mnt /bin/bash <<EOF

# Setări de bază
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# Locală
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "$hostname" > /etc/hostname
cat >> /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOL

# Parole
echo "root:$password" | chpasswd

# Bootloader GRUB Legacy
grub-install --target=i386-pc --boot-directory=/boot $disk
grub-mkconfig -o /boot/grub/grub.cfg

# Servicii
systemctl enable NetworkManager
systemctl enable lightdm

# Utilizator
useradd -m -G wheel $username
echo "$username:$password" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# --- Branding SHAMANU ---
wget -O /usr/share/pixmaps/shamanu.png "https://raw.githubusercontent.com/yourrepo/archmac/main/shamanu.png"
wget -O /usr/share/backgrounds/shamanu-wallpaper.png "https://raw.githubusercontent.com/yourrepo/archmac/main/shamanu-wallpaper.png"

# LightDM
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<GREETER_EOF
[greeter]
background=/usr/share/backgrounds/shamanu-wallpaper.png
theme-name=Adwaita-dark
icon-theme-name=Adwaita
GREETER_EOF

# MOTD
echo -e "\n* Welcome to SHAMANU Linux (Legacy Edition) *\n" > /etc/motd

# --- Instalare pachete utilizator ---
sudo -u $username bash -c '
  cd ~ && git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si --noconfirm
  yay -S --noconfirm google-chrome pycharm-community-edition
'
EOF

# Curățare și reboot
umount -R /mnt
echo "Instalare completă! Sistemul se va reporni în 5 secunde..."
sleep 5
reboot
