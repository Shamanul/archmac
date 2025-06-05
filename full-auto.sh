#!/bin/bash
# MACOS-LIKE LEGACY INSTALL SCRIPT WITH GFX CORNER
# BIOS Legacy (non-UEFI) compatible with HDD optimization

# Configurație
disk="/dev/sda"       # Înlocuiește cu discul tău
username="macuser"
password="password"
hostname="macarch"

# Setări inițiale
loadkeys us
timedatectl set-ntp true

# Șterge și creează partiții MBR
echo "Creare tabel partiții MBR..."
parted -s $disk mklabel msdos
parted -s $disk mkpart primary ext4 1MiB 512MiB
parted -s $disk set 1 boot on
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

# Instalare pachete (cu componente pentru macOS-like UI)
echo "Instalare sistem de bază..."
pacstrap /mnt base linux linux-firmware networkmanager grub \
          sudo git xorg xfce4 xfce4-goodies xfce4-whiskermenu-plugin \
          lightdm lightdm-gtk-greeter plank conky \
          compton gnome-icon-theme-full elementary-icon-theme \
          papirus-icon-theme moka-icon-theme numix-icon-theme-git \
          xfwm4-theme-dalen xfwm4-themes xfce4-notifyd \
          ttf-dejavu ttf-liberation ttf-droid ttf-ubuntu-font-family \
          feh imagemagick  # Adăugate pentru manipularea imaginilor

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

# --- Descărcare și procesare logo "S" ---
echo "Pregătim logo-ul GFX..."
wget -O /tmp/letter-s.jpg "https://media.istockphoto.com/id/1225392660/vector/letter-s-logo-template-illustration-design-vector-eps-10.jpg?s=612x612&w=0&k=20&c=zE3Swakmr7jEcEHNt7bvBWVKhQrDqG_r2r823U5VVbQ="

# Crează o versiune mai mică a logo-ului (50x50)
convert /tmp/letter-s.jpg -resize 50x50 /tmp/s-logo-small.png

# Crează imaginea combo (logo + text GFX)
convert -size 200x50 xc:none \
  /tmp/s-logo-small.png -geometry +0+0 -composite \
  -font Helvetica -pointsize 24 -fill white -draw "text 60,35 'GFX'" \
  /usr/share/pixmaps/gfx-corner.png

# --- Configurare macOS-like ---

# Descărcare temă macOS-like
wget -O /tmp/macOS-theme.tar.gz "https://github.com/paullinuxthemer/Mc-OS-themes/archive/refs/heads/master.tar.gz"
tar -xzf /tmp/macOS-theme.tar.gz -C /tmp

# Instalare temă GTK, iconițe și cursor
mkdir -p /usr/share/themes
mkdir -p /usr/share/icons
cp -r /tmp/Mc-OS-themes-master/Mc-OS-CTLina-Gnome-Dark-1.1 /usr/share/themes/
cp -r /tmp/Mc-OS-themes-master/Mc-OS-CTLina-Gnome-Light-1.1 /usr/share/themes/
cp -r /tmp/Mc-OS-themes-master/McOS-MJV-3.1 /usr/share/icons/

# Setare fundal ecran macOS
wget -O /usr/share/backgrounds/macOS-wallpaper.jpg "https://512pixels.net/downloads/macos-wallpapers/11-0-Daylight.jpg"

# Configurare LightDM (ecran de login)
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<GREETER_EOF
[greeter]
background=/usr/share/backgrounds/macOS-wallpaper.jpg
theme-name=Mc-OS-CTLina-Gnome-Dark-1.1
icon-theme-name=McOS-MJV-3.1
font-name=San Francisco
GREETER_EOF

# Configurare Xfce să arate ca macOS
sudo -u $username bash -c '
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<XFWM_EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Mc-OS-CTLina-Gnome-Dark-1.1"/>
    <property name="button_layout" type="string" value="CMH|"/>
    <property name="button_offset" type="int" value="10"/>
    <property name="title_font" type="string" value="Sans Bold 10"/>
  </property>
</channel>
XFWM_EOF

cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<XSETTINGS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Mc-OS-CTLina-Gnome-Dark-1.1"/>
    <property name="IconThemeName" type="string" value="McOS-MJV-3.1"/>
    <property name="DoubleClickTime" type="int" value="250"/>
  </property>
</channel>
XSETTINGS_EOF

# --- Configurare colț GFX cu logo și text ---
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/gfx-corner.desktop <<EOF
[Desktop Entry]
Name=GFX Corner
Exec=sh -c "sleep 5 && feh --bg-center /usr/share/pixmaps/gfx-corner.png --no-xinerama --geometry +20+20"
Type=Application
EOF

# Configurare Plank (Dock)
mkdir -p ~/.config/plank/dock1
cat > ~/.config/plank/dock1/settings <<PLANK_EOF
[dock1]
alignment='center'
auto-pinning=true
current-workspace-only=false
dock-items=['xfce-settings-manager.dockitem', 'thunar.dockitem', 'firefox.dockitem', 'org.gnome.Terminal.dockitem']
hide-delay=200
hide-mode='dodge-maximized'
icon-size=48
items-alignment='center'
lock-items=false
monitor=''
offset=0
pinned-only=false
position='bottom'
pressure-reveal=false
show-dock-item=false
theme='Transparent'
tooltips-enabled=true
unhide-delay=0
zoom-enabled=true
zoom-percent=150
PLANK_EOF

# Configurare animații și efecte (compton)
cat > ~/.config/compton.conf <<COMPTON_EOF
backend = "glx";
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
vsync = "opengl-swc";

shadow = true;
no-dnd-shadow = true;
no-dock-shadow = true;
clear-shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.7;
shadow-red = 0.0;
shadow-green = 0.0;
shadow-blue = 0.0;
shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c"
];

fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-exclude = [];

inactive-opacity = 0.8;
active-opacity = 1.0;
frame-opacity = 0.7;
inactive-opacity-override = false;
focus-exclude = [ "class_g = 'Cairo-clock'" ];

opacity-rule = [
    "80:class_g = 'Xfce4-terminal'",
    "80:class_g = 'Thunar'"
];

blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;
blur-kern = "3x3box";
blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@:c"
];
COMPTON_EOF
'

# --- Instalare aplicații ---
sudo -u $username bash -c '
  # Instalare yay (AUR helper)
  cd ~ && git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si --noconfirm
  
  # Instalare aplicații (inclusiv Chrome)
  yay -S --noconfirm google-chrome pycharm-community-edition \
      firefox-developer-edition alacritty \
      plank-theme-macos mojave-gtk-theme-git \
      gnome-dock-like-macos-dock \
      apple-fonts ttf-san-francisco \
      latte-dock-git feh
  
  # Configurare Chrome ca browser implicit
  xdg-settings set default-web-browser google-chrome.desktop
  
  # Descărcare profil Chrome pre-configurat
  mkdir -p ~/.config/google-chrome/Default
  wget -O ~/.config/google-chrome/Default/Preferences "https://gist.githubusercontent.com/macOS-User/example/raw/chrome-preferences.json"
'

# MOTD personalizat
echo -e "\n* Welcome to MacArch - macOS-like experience on Arch Linux *\n" > /etc/motd

EOF

# Curățare și reboot
umount -R /mnt
echo "Instalare completă! Sistemul se va reporni în 5 secunde..."
sleep 5
reboot
