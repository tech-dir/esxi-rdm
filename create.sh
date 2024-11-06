#!/bin/sh

RDM_DIR_NAME=HDD_RDM
DATASTORE_DIR=/vmfs/volumes

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

# Описание сценария
echo
echo "Скрипт создания RDM (Raw Device Mapping) для физических дисков на VMware."
echo "Вы сможете выбрать datastore и диски, которые вы хотите использовать."
echo "Пожалуйста, следуйте инструкциям на экране."
echo

# Получение списка доступных datastore
print_warning "Доступные datastore:"
DATASTORE_LIST=$(ls $DATASTORE_DIR)

# Проверка наличия доступных datastore
if [ -z "$DATASTORE_LIST" ]; then
    print_error "Ошибка: Не найдено доступных datastore." >&2
    exit 1
fi

# Вывод списка и запрос выбора
i=1
for DS in $DATASTORE_LIST; do
    echo "$i) $DS"
    i=$((i + 1))
done

echo
# Чтение выбора от пользователя
read -p "Введите номер выбранного datastore: " CHOICE

# Получение выбранного datastore
DATASTORE_NAME=$(echo $DATASTORE_LIST | cut -d' ' -f$CHOICE)
# Проверка на корректность выбора
if [ -z "$DATASTORE_NAME" ]; then
    print_error "Некорректный выбор." >&2
    exit 1
fi

# Формируем полный путь до выбранного datastore
DATASTORE_PATH="$DATASTORE_DIR/$DATASTORE_NAME"

echo
# Создание папки hdd_passthrough в выбранном datastore
HDD_PASSTHROUGH_PATH="$DATASTORE_PATH/$RDM_DIR_NAME"
mkdir -p "$HDD_PASSTHROUGH_PATH"
print_info "Все '.vmdk' файлы дисков будут в директории: $HDD_PASSTHROUGH_PATH"
echo

# Получение списка доступных физических дисков
DISK_LIST=$(esxcli storage core device list | grep 'Devfs Path')

# Извлечение имен дисков
DEVICE_NAMES=$(echo "$DISK_LIST" | awk -F ": " '{print $2}' | awk -F '/' '{print $NF}')

# Проверка наличия доступных дисков
if [ -z "$DEVICE_NAMES" ]; then
    print_error "Ошибка: Не найдено доступных физических дисков." >&2
    exit 1
fi

# Выводим список дисков и запрашиваем выбор
i=1
print_warning "Доступные диски для создания RDM:"
for DEVICE in $DEVICE_NAMES; do
    echo "$i) $DEVICE"
    i=$((i + 1))
done

# Чтение выбора от пользователя (ввод нескольких номеров)
echo
read -p "Введите номера выбранных дисков (через пробел): " DEVICE_CHOICES

# Обработка выбранных устройств
for DEVICE_CHOICE in $DEVICE_CHOICES; do
    # Получение выбранного устройства
    DEVICE_NAME=$(echo $DEVICE_NAMES | cut -d' ' -f$DEVICE_CHOICE)

    # Проверка на корректность выбора
    if [ -z "$DEVICE_NAME" ]; then
        print_error "Некорректный выбор: $DEVICE_CHOICE." >&2
        continue
    fi

    # Формирование имени для VMDK файла с заменой _ на - и удалением лишних -
    VMDK_FILENAME=$(echo "$DEVICE_NAME" | sed 's/_/-/g; s/-\+/-/g; s/^-//; s/-$//')
    VMDK_PATH="$HDD_PASSTHROUGH_PATH/${VMDK_FILENAME}.vmdk"

    # Проверка, существует ли VMDK
    if [ -f "$VMDK_PATH" ]; then
        print_error "Ошибка: Файл $VMDK_PATH уже существует." >&2
        continue
    fi

    # Выполнение команды vmkfstools для создания RDM
    if vmkfstools -z /vmfs/devices/disks/$DEVICE_NAME "$VMDK_PATH"; then
        print_success "RDM успешно создан: $VMDK_PATH"
    else
        print_error "Ошибка при создании RDM для $DEVICE_NAME." >&2
    fi
done

echo
exit 0
