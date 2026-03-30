#!/bin/bash

# Скрипт для проверки конфигурации перед коммитом

set -e

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Запуск проверки конфигурации Wazuh...${NC}"

# Проверка наличия xmllint
if ! command -v xmllint &> /dev/null; then
    echo -e "${RED}[ОШИБКА] xmllint не найден. Установите libxml2-utils:${NC}"
    echo "sudo apt-get install -y libxml2-utils"
    exit 1
fi

# Проверка XML-файлов на валидность
echo -e "${YELLOW}Проверка XML-файлов...${NC}"
XML_FILES=($(find rules decoders -name "*.xml"))

for file in "${XML_FILES[@]}"; do
    echo -n "Проверка $file ... "
    if xmllint --noout "$file" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}ОШИБКА${NC}"
        xmllint --noout "$file"
        exit 1
    fi
done

# Проверка работы Docker и Docker Compose
if ! docker info &>/dev/null; then
    echo -e "${RED}[ОШИБКА] Docker не запущен или не установлен${NC}"
    exit 1
fi

if ! docker-compose --version &>/dev/null; then
    echo -e "${RED}[ОШИБКА] Docker Compose не установлен${NC}"
    exit 1
fi

# Проверка наличия тестовых логов
if [ ! -d "tests/logs" ] || [ ! -f "tests/logs/test_mikrotik.log" ]; then
    echo -e "${YELLOW}Создание директории для тестовых логов...${NC}"
    mkdir -p tests/logs
    cat > tests/logs/test_mikrotik.log << EOF
Mikrotik login success for user admin from 192.168.1.100 via web
Mikrotik login success for user user1 from 192.168.1.101 via ssh
Mikrotik login failure for user baduser from 10.0.0.5 via ssh
Mikrotik login failure for user baduser from 10.0.0.5 via ssh
Mikrotik login failure for user baduser from 10.0.0.5 via ssh
Mikrotik login failure for user baduser from 10.0.0.5 via ssh
Mikrotik login failure for user baduser from 10.0.0.5 via ssh
Mikrotik system reboot requested by admin from 192.168.1.100
Mikrotik logout for user admin from 192.168.1.100 via web
EOF
    echo -e "${GREEN}Тестовые логи созданы${NC}"
fi

echo -e "${GREEN}Все проверки пройдены успешно!${NC}"
echo -e "${YELLOW}Для полного тестирования можно запустить:${NC}"
echo "docker-compose up -d"
echo "docker cp rules/local_rules.xml \$(docker-compose ps -q wazuh.manager):/var/ossec/etc/rules/"
echo "docker cp decoders/local_decoder.xml \$(docker-compose ps -q wazuh.manager):/var/ossec/etc/decoders/"
echo "docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control restart"
echo "docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control status"
echo "docker-compose exec wazuh.manager grep -i \"error\\|critical\" /var/ossec/logs/ossec.log"

exit 0 