#!/bin/bash

# Определяем директорию со скриптом
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Константы
CONFIG_FILE="$SCRIPT_DIR/config/ssh.esxi.config"
LOCAL_SCRIPT="$SCRIPT_DIR/create.sh"
REMOTE_DIR="/usr/tools"
REMOTE_SCRIPT="$REMOTE_DIR/rdm_create.sh"

# Цвета
YELLOW='\033[0;33m'     # Желтый
RED='\033[0;31m'        # Красный
GREEN='\033[0;32m'      # Зеленый
BLUE='\033[0;34m'       # Синий
NC='\033[0m'            # Без цвета (сброс)

# Функция для вывода сообщений
function print_info {
    echo -e "${BLUE}$1${NC}"
}

function print_warning {
    echo -e "${YELLOW}$1${NC}"
}

function print_success {
    echo -e "${GREEN}$1${NC}"
}

function print_error {
    echo -e "${RED}$1${NC}"
}

# Функция для установки sshpass
function install_sshpass {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Для Ubuntu
        if [[ -x "$(command -v apt)" ]]; then
            print_info "Устанавливаем sshpass с помощью apt..."
            sudo apt update
            sudo apt install -y sshpass
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Для macOS
        if [[ -x "$(command -v brew)" ]]; then
            print_info "Устанавливаем sshpass с помощью Homebrew..."
            brew install esolitos/ipa/sshpass
        else
            print_error "Homebrew не установлен. Пожалуйста, установите Homebrew и попробуйте снова."
            exit 1
        fi
    else
        print_error "Операционная система не поддерживается для автоматической установки sshpass."
        exit 1
    fi
}

# Проверка наличия sshpass
if ! command -v sshpass &> /dev/null; then
    print_info "sshpass не найден. Попробуем установить..."
    install_sshpass
fi

# Проверяем наличие конфигурационного файла
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Ошибка: файл конфигурации $CONFIG_FILE не найден!"
    exit 1
fi

# Загружаем настройки из конфигурационного файла
source "$CONFIG_FILE"

# Проверка и ввод значений, если они не заданы
if [[ -z "$ESXI_IP" ]]; then
    read -p "Введите IP-адрес ESXi: " ESXI_IP
fi

if [[ -z "$ESXI_USER" ]]; then
    read -p "Введите имя пользователя для SSH: " ESXI_USER
fi

if [[ -z "$ESXI_PASSWORD" ]]; then
    read -sp "Введите пароль для SSH: " ESXI_PASSWORD
    echo
fi

# Проверка подключения по ssh к ESXi
sshpass -p "$ESXI_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$ESXI_USER@$ESXI_IP" exit
if [[ $? -ne 0 ]]; then
    print_error "Ошибка: не удалось подключиться к серверу ESXi по SSH. Проверьте IP-адрес, имя пользователя и пароль."
    exit 1
else
    print_success "Подключение по ssh успешно установлено!"
fi

# Проверяем, существует ли скрипт
if [[ ! -f "$LOCAL_SCRIPT" ]]; then
    print_error "Ошибка: файл $LOCAL_SCRIPT не найден!"
    exit 1
fi

# Создаем директорию, если она не существует
sshpass -p "$ESXI_PASSWORD" ssh "$ESXI_USER@$ESXI_IP" "mkdir -p $REMOTE_DIR"
if [[ $? -eq 0 ]]; then
    print_success "Создана папка $REMOTE_DIR, куда будет скопирован скрипт."
fi

# Копируем скрипт на удаленный сервер
sshpass -p "$ESXI_PASSWORD" scp "$LOCAL_SCRIPT" "$ESXI_USER@$ESXI_IP:$REMOTE_SCRIPT"
# Если передача прошла успешно, продолжаем
if [[ $? -eq 0 ]]; then
    print_success "Скрипт успешно скопирован в $REMOTE_SCRIPT."

    # Создаем директорию, если она не существует
    sshpass -p "$ESXI_PASSWORD" ssh "$ESXI_USER@$ESXI_IP" "mkdir -p $REMOTE_DIR"

    # Получаем права на выполнение для скрипта
    sshpass -p "$ESXI_PASSWORD" ssh "$ESXI_USER@$ESXI_IP" "chmod +x $REMOTE_SCRIPT"

    # Запускаем скрипт в интерактивном режиме
    sshpass -p "$ESXI_PASSWORD" ssh -t "$ESXI_USER@$ESXI_IP" "$REMOTE_SCRIPT"
else
    print_error "Ошибка при копировании скрипта на сервер ESXi."
    exit 1
fi

exit 0
