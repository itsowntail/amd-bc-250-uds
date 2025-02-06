#!/bin/sh
# Устанавливаем строгую проверку ошибок
set -e

# Функция для определения дистрибутива
detect_distro() {
    if command -v pacman > /dev/null 2>&1; then
        echo "arch"
    elif command -v dnf > /dev/null 2>&1; then
        echo "fedora"
    elif command -v apt > /dev/null 2>&1; then
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

# Проверка, что скрипт запущен от имени root
if [ "$(id -u)" != "0" ]; then
    echo 'Скрипт должен быть запущен от имени root или с sudo!'
    exit 1
fi

# Меню для выбора действий пользователя
echo "Выберите действие:"
echo "1) Установить драйверы AMDGPU"
echo "2) Установить заплатированные драйверы Mesa"
echo "3) Удалить существующие драйверы и установить новые"
echo "4) Настроить NCT6686 SuperIO"
echo "5) Настроить параметры ядра для Cyan Skillfish"
echo "6) Выйти"
read -p "Введите ваш выбор: " ACTION_CHOICE

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
        echo "Выход..."
        exit 0
        ;;
    *)
        echo "Неверный выбор. Выход..."
        exit 1
        ;;
esac

# Удаление существующих драйверов, если выбрано
if [ "$REMOVE_AND_INSTALL" = "1" ]; then
    echo "Удаление существующих драйверов AMDGPU..."
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
    echo "Существующие драйверы удалены. Переходим к установке новых..."
fi

# Установка драйверов в зависимости от выбора пользователя
if [ "$INSTALL_AMDGPU" = "1" ] || [ "$INSTALL_MESA" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
    case $DISTRO in
        arch)
            pacman -Syu --noconfirm base-devel git cmake make gcc libdrm lm_sensors
            if [ "$INSTALL_AMDGPU" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                yay -S amdgpu-dkms --noconfirm
            elif [ "$INSTALL_MESA" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                yay -S mesa-bc250 --noconfirm
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
        fedora|centos)
            dnf install -y kernel-devel gcc make dkms libdrm-devel lm_sensors
            if [ "$INSTALL_AMDGPU" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                dnf copr enable @exotic-soc/amd-graphics -y
                dnf install -y amdgpu-dkms
            elif [ "$INSTALL_MESA" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                dnf copr enable @exotic-soc/bc250-mesa -y
                dnf upgrade -y
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
        ubuntu|debian)
            apt update && apt upgrade -y
            apt install -y dialog  # Добавляем dialog для обеспечения зависимостей
            apt install -y lm-sensors
            
            if [ "$INSTALL_AMDGPU" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                # Устанавливаем зависимости
                apt install -y wget software-properties-common
                
                # Загружаем и устанавливаем amdgpu-install
                wget https://repo.radeon.com/amdgpu-install/21.50/ubuntu/focal/amdgpu-install_21.50.50000-1_all.deb
                dpkg -i amdgpu-install_21.50.50000-1_all.deb || true  # Используем || true чтобы игнорировать ошибки dpkg
                
                # Фиксим проблемы зависимостей
                apt --fix-broken install -y
                
                # Продолжаем с основной установкой
                amdgpu-install --usecase=graphics,opencl,openclsdk --no-dkms --no-32 --accept-eula
                apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
                usermod -a -G render,video $LOGNAME
                apt install -y amdgpu-dkms
            elif [ "$INSTALL_MESA" = "1" ] || [ "$REMOVE_AND_INSTALL" = "1" ]; then
                add-apt-repository ppa:oibaf/graphics-drivers -y
                apt update
                apt install -y mesa-vulkan-drivers
                echo 'RADV_DEBUG=nocompute' > /etc/environment
            fi
            ;;
    esac
fi

# Настройка NCT6686 SuperIO
if [ "$CONFIGURE_NCT6686" = "1" ]; then
    echo "Настройка NCT6686 SuperIO..."
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
if [ "$CONFIGURE_KERNEL" = "1" ]; then
    echo "Настройка параметров ядра для Cyan Skillfish..."
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
echo "Готово! Перезагрузка системы через 15 секунд, нажмите Ctrl+C сейчас, чтобы отменить..."
sleep 15 && reboot
