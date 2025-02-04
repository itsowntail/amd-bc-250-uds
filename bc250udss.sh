#!/usr/bin/env bash
set -euo pipefail

# Функция для обнаружения дистрибутива
detect_distro() {
    if command -v pacman &> /dev/null; then
        echo "arch"
    elif command -v dnf &> /dev/null; then
        echo "fedora"
    elif command -v apt &> /dev/null; then
        echo "ubuntu"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ] && grep -q "CentOS" /etc/redhat-release; then
        echo "centos"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)

if [[ $(id -u) != "0" ]]; then
    echo 'Script must be run as root or with sudo!'
    exit 1
fi

# Меню выбора действий
echo "Choose an action:"
echo "1) Install AMDGPU drivers"
echo "2) Install Patched Mesa drivers"
echo "3) Remove existing drivers and install new ones"
echo "4) Configure NCT6686 SuperIO"
echo "5) Configure Kernel parameters for Cyan Skillfish"
echo "6) Exit"
read -p "Enter your choice: " ACTION_CHOICE

case $ACTION_CHOICE in
    1)
        INSTALL_AMDGPU=1
        ;;
    2)
        INSTALL_MESA=1
        ;;
    3)
        REMOVE_AND_INSTALL=1
        ;;
    4)
        CONFIGURE_NCT6686=1
        ;;
    5)
        CONFIGURE_KERNEL=1
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

# Удаление существующих драйверов (если выбрано)
if [[ $REMOVE_AND_INSTALL -eq 1 ]]; then
    echo "Removing existing AMDGPU drivers..."
    case $DISTRO in
        arch)
            pacman -Rns --noconfirm amdgpu-dkms mesa
            ;;
        fedora|centos)
            dnf remove -y amdgpu-dkms mesa
            ;;
        ubuntu|debian)
            apt purge -y amdgpu-dkms mesa-vulkan-drivers
            ;;
    esac
    echo "Existing drivers removed. Proceeding to install new ones..."
fi

# Установка драйверов в зависимости от выбора
if [[ $INSTALL_AMDGPU -eq 1 || $INSTALL_MESA -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
    case $DISTRO in
        arch)
            pacman -Syu --noconfirm base-devel git cmake make gcc libdrm lm_sensors
            if [[ $INSTALL_AMDGPU -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                yay -S amdgpu-dkms --noconfirm
            elif [[ $INSTALL_MESA -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                yay -S mesa-bc250 --noconfirm
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
        fedora|centos)
            dnf install -y kernel-devel gcc make dkms libdrm-devel lm_sensors
            if [[ $INSTALL_AMDGPU -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                dnf copr enable @exotic-soc/amd-graphics -y
                dnf install -y amdgpu-dkms
            elif [[ $INSTALL_MESA -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                dnf copr enable @exotic-soc/bc250-mesa -y
                dnf upgrade -y
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
        ubuntu|debian)
            apt update && apt upgrade -y
            apt install -y lm-sensors
            if [[ $INSTALL_AMDGPU -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                wget https://repo.radeon.com/amdgpu-install/21.50/ubuntu/focal/amdgpu-install_21.50.50000-1_all.deb
                dpkg -i amdgpu-install_21.50.50000-1_all.deb
                amdgpu-install --usecase=graphics,opencl,openclsdk --no-dkms --no-32 --accept-eula
                apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
                usermod -a -G render,video $LOGNAME
                apt install -y amdgpu-dkms
            elif [[ $INSTALL_MESA -eq 1 || $REMOVE_AND_INSTALL -eq 1 ]]; then
                add-apt-repository ppa:oibaf/graphics-drivers -y
                apt update
                apt install -y mesa-vulkan-drivers
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
    esac
fi

# Настройка NCT6686 SuperIO
if [[ $CONFIGURE_NCT6686 -eq 1 ]]; then
    echo "Configuring NCT6686 SuperIO..."
    echo 'options nct6775 force=1' > /etc/modprobe.d/sensors.conf
    echo 'nct6775' > /etc/modules-load.d/99-sensors.conf
    case $DISTRO in
        arch)
            mkinitcpio -P
            ;;
        fedora|centos)
            dracut --regenerate-all --force
            ;;
        ubuntu|debian)
            update-initramfs -u
            ;;
    esac
fi

# Настройка параметров ядра для Cyan Skillfish
if [[ $CONFIGURE_KERNEL -eq 1 ]]; then
    echo "Configuring Kernel parameters for Cyan Skillfish..."
    if ! grep -q "amdgpu.sg_display=0" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&amdgpu.sg_display=0 /' /etc/default/grub
        case $DISTRO in
            fedora|centos)
                grub2-mkconfig -o /boot/grub2/grub.cfg
                ;;
            ubuntu|debian)
                update-grub
                ;;
        esac
    fi
fi

# Сообщение о завершении
echo "Done! Rebooting system in 15 seconds, ctrl-C now to cancel..."
sleep 15 && reboot