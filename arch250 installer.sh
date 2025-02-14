#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) != "0" ]]; then
    echo 'Script must be run as root or with sudo!'
    exit 1
fi

# Установка необходимых пакетов
echo "Installing required packages..."
pacman -Syu --noconfirm base-devel git cmake make gcc

# Проверка установки paru (AUR-менеджера)
if ! command -v paru &> /dev/null; then
    echo "paru not found, installing..."
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin && makepkg -si --noconfirm
    cd .. && rm -rf paru-bin
fi

# Установка патченного Mesa из AUR
echo "Installing patched Mesa (mesa-git) from AUR..."
paru -S --noconfirm mesa-git

# Установка переменной окружения для RADV_DEBUG
echo "Setting RADV_DEBUG option..."
echo 'export RADV_DEBUG=nocompute' > /etc/profile.d/radv_debug.sh
chmod +x /etc/profile.d/radv_debug.sh

# Установка GPU governor (Oberon Governor)
echo "Installing GPU governor..."
git clone https://gitlab.com/mothenjoyer69/oberon-governor.git
cd oberon-governor
cmake . && make && make install
systemctl enable oberon-governor.service
cd .. && rm -rf oberon-governor

# Настройка модуля amdgpu и сенсора nct6683
echo "Setting amdgpu and sensors module options..."
echo 'options amdgpu sg_display=0' > /etc/modprobe.d/amdgpu.conf
echo 'nct6683' > /etc/modules-load.d/nct6683.conf
echo 'options nct6683 force=true' > /etc/modprobe.d/nct6683.conf

# Обновление образа initramfs (в Arch используется mkinitcpio)
echo "Regenerating initramfs..."
mkinitcpio -P

# Удаление nomodeset из параметров загрузки
echo "Fixing up GRUB config..."
if grep -q "nomodeset" /etc/default/grub; then
    sed -i 's/nomodeset//g' /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

# Завершение установки
echo "Done! Rebooting system in 15 seconds, ctrl-C now to cancel..."
sleep 15 && reboot
