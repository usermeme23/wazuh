#!/bin/bash

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для печати сообщений с префиксом
print_message() {
    echo -e "${BLUE}[ТЕСТ]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[УСПЕХ]${NC} $1"
}

print_error() {
    echo -e "${RED}[ОШИБКА]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} $1"
}

# Функция для проверки наличия команды
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 не установлен. Установите с помощью команды: $2"
        exit 1
    fi
}

# Проверяем наличие необходимых инструментов
check_command "docker" "sudo apt-get install -y docker.io"
check_command "docker-compose" "sudo apt-get install -y docker-compose"
check_command "xmllint" "sudo apt-get install -y libxml2-utils"

# Проверка синтаксиса XML файлов
print_message "Проверка синтаксиса XML файлов..."
if [[ -d "rules" ]]; then
    if ! xmllint --noout rules/*.xml 2>/dev/null; then
        print_error "Ошибки в синтаксисе файлов правил"
        exit 1
    else
        print_success "Синтаксис файлов правил корректен"
    fi
else
    print_warning "Директория rules не найдена"
fi

if [[ -d "decoders" ]]; then
    if ! xmllint --noout decoders/*.xml 2>/dev/null; then
        print_error "Ошибки в синтаксисе файлов декодеров"
        exit 1
    else
        print_success "Синтаксис файлов декодеров корректен"
    fi
else
    print_warning "Директория decoders не найдена"
fi

# Генерация тестовых логов, если скрипт доступен
if [[ -f "scripts/generate_test_logs.sh" ]]; then
    print_message "Генерация тестовых логов..."
    chmod +x scripts/generate_test_logs.sh
    ./scripts/generate_test_logs.sh
    if [[ $? -ne 0 ]]; then
        print_error "Ошибка при генерации тестовых логов"
        exit 1
    fi
else
    print_warning "Скрипт для генерации тестовых логов не найден. Создайте директорию tests/logs вручную."
    mkdir -p tests/logs
fi

# Проверка и создание docker-compose.yml, если он отсутствует
if [[ ! -f "docker-compose.yml" ]]; then
    print_message "Создание файла docker-compose.yml для Wazuh..."
    cat > docker-compose.yml << 'EOF'
version: '3.7'

services:
  wazuh.manager:
    image: wazuh/wazuh-manager:4.4.0
    hostname: wazuh.manager
    restart: always
    ports:
      - "1514:1514"
      - "1515:1515"
      - "514:514/udp"
      - "55000:55000"
    environment:
      - INDEXER_URL=https://wazuh.indexer:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecretPassword
      - FILEBEAT_SSL_VERIFICATION_MODE=none
    volumes:
      - wazuh_api_configuration:/var/ossec/api/configuration
      - wazuh_etc:/var/ossec/etc
      - wazuh_logs:/var/ossec/logs
      - wazuh_queue:/var/ossec/queue
      - wazuh_var_multigroups:/var/ossec/var/multigroups
      - wazuh_integrations:/var/ossec/integrations
      - wazuh_active_response:/var/ossec/active-response/bin
      - wazuh_agentless:/var/ossec/agentless
      - wazuh_wodles:/var/ossec/wodles
      - ./rules:/test-rules
      - ./decoders:/test-decoders
      - ./tests/logs:/test-logs

volumes:
  wazuh_api_configuration:
  wazuh_etc:
  wazuh_logs:
  wazuh_queue:
  wazuh_var_multigroups:
  wazuh_integrations:
  wazuh_active_response:
  wazuh_agentless:
  wazuh_wodles:
EOF
    print_success "Файл docker-compose.yml создан"
fi

# Задаем параметры ядра для Wazuh
print_message "Установка параметров ядра для Wazuh..."
sudo sysctl -w vm.max_map_count=262144

# Запуск Wazuh
print_message "Запуск Wazuh..."
docker-compose up -d wazuh.manager

# Ожидание 60 секунд для инициализации Wazuh
print_message "Ожидание инициализации Wazuh (60 секунд)..."
sleep 60

# Копирование правил и декодеров
print_message "Копирование правил и декодеров в контейнер..."
if [[ -d "rules" ]]; then
    docker-compose exec wazuh.manager cp -f /test-rules/*.xml /var/ossec/etc/rules/ 2>/dev/null
    if [[ $? -ne 0 ]]; then
        print_warning "Не удалось скопировать файлы правил. Возможно нет файлов .xml"
    else
        print_success "Правила успешно скопированы"
    fi
fi

if [[ -d "decoders" ]]; then
    docker-compose exec wazuh.manager cp -f /test-decoders/*.xml /var/ossec/etc/decoders/ 2>/dev/null
    if [[ $? -ne 0 ]]; then
        print_warning "Не удалось скопировать файлы декодеров. Возможно нет файлов .xml"
    else
        print_success "Декодеры успешно скопированы"
    fi
fi

# Перезапуск Wazuh для применения правил
print_message "Перезапуск Wazuh для применения новых правил и декодеров..."
docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control restart

# Ожидание 30 секунд для перезапуска Wazuh
print_message "Ожидание перезапуска Wazuh (30 секунд)..."
sleep 30

# Проверка статуса Wazuh
print_message "Проверка статуса Wazuh..."
docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control status

# Проверка логов на ошибки
print_message "Проверка логов Wazuh на наличие ошибок..."
ERRORS=$(docker-compose exec wazuh.manager grep -i "error\|critical\|warning" /var/ossec/logs/ossec.log | grep -v "INFO\|DEBUG" | tail -n 20)
if [[ ! -z "$ERRORS" ]]; then
    print_warning "Найдены предупреждения или ошибки в логах:"
    echo "$ERRORS"
else
    print_success "Критических ошибок не обнаружено в логах"
fi

# Функция для тестирования логов
test_log() {
    LOG_TYPE=$1
    LOG_FILE=$2
    LOG_EXAMPLE=$3
    
    print_message "Тестирование логов типа $LOG_TYPE..."
    
    if [[ -f "$LOG_FILE" ]]; then
        # Копируем лог-файл в контейнер, если он существует
        docker cp "$LOG_FILE" $(docker-compose ps -q wazuh.manager):/tmp/test_log
        print_success "Лог-файл скопирован в контейнер"
        
        # Тестирование всего файла логов
        print_message "Тестирование файла логов $LOG_FILE..."
        docker-compose exec wazuh.manager bash -c "cat /tmp/test_log | /var/ossec/bin/wazuh-logtest -q"
        if [[ $? -ne 0 ]]; then
            print_warning "Некоторые записи лога не были обработаны правильно"
        else
            print_success "Все записи лога обработаны правильно"
        fi
    else
        print_warning "Файл $LOG_FILE не найден"
    fi
    
    # Тестирование примера лога
    if [[ ! -z "$LOG_EXAMPLE" ]]; then
        print_message "Тестирование примера лога $LOG_TYPE..."
        docker-compose exec wazuh.manager bash -c "echo '$LOG_EXAMPLE' | /var/ossec/bin/wazuh-logtest -v"
        if [[ $? -ne 0 ]]; then
            print_warning "Пример лога не обработан правильно"
        else
            print_success "Пример лога обработан правильно"
        fi
    fi
}

# Тестирование различных типов логов
if [[ -d "tests/logs" ]]; then
    test_log "MikroTik" "tests/logs/test_mikrotik.log" "Mikrotik login success for user admin from 192.168.1.100 via ssh"
    test_log "Windows" "tests/logs/test_windows.log" "Successful logon: User Name: JOHN Computer: WORKSTATION1"
    test_log "Ubuntu" "tests/logs/test_ubuntu.log" "pam_unix(sshd:auth): authentication success; logname= uid=0 euid=0 tty=ssh ruser= rhost=192.168.1.200 user=admin"
else
    print_warning "Директория tests/logs не найдена"
fi

# Вывести справку по командам для дальнейшего тестирования
echo ""
print_message "Тестирование завершено. Дополнительные команды для отладки:"
echo "  docker-compose exec wazuh.manager /var/ossec/bin/wazuh-logtest -v    # Запуск интерактивного тестирования логов"
echo "  docker-compose exec wazuh.manager cat /var/ossec/logs/ossec.log      # Просмотр логов Wazuh"
echo "  docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control restart # Перезапуск Wazuh"
echo "  docker-compose down                                                  # Остановка Wazuh"
echo ""
print_success "Для остановки Wazuh выполните: docker-compose down" 