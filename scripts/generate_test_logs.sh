#!/bin/bash

# Скрипт для генерации тестовых логов для проверки правил и декодеров Wazuh

# Цвета для вывода сообщений
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для печати сообщений с префиксом
print_message() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверяем и создаем директорию для логов
mkdir -p tests/logs
print_message "Директория для тестовых логов создана: tests/logs"

# Генерируем тестовые логи для MikroTik
cat > tests/logs/test_mikrotik.log << EOF
Mikrotik login success for user admin from 192.168.1.100 via ssh
Mikrotik login failure for user admin from 192.168.1.200 via ssh
Mikrotik login failure for user admin from 192.168.1.200 via ssh
Mikrotik login failure for user admin from 192.168.1.200 via ssh
Mikrotik login failure for user admin from 192.168.1.200 via ssh
Mikrotik login failure for user admin from 192.168.1.200 via ssh
Mikrotik login success for user user1 from 192.168.1.101 via web
Mikrotik login failure for user root from 10.0.0.100 via ssh
EOF
print_success "Созданы тестовые логи для MikroTik"

# Генерируем тестовые логи для Windows
cat > tests/logs/test_windows.log << EOF
Windows login success for user Administrator from 192.168.1.150
Windows login failure for user Administrator from 192.168.1.250
Windows login failure for user Administrator from 192.168.1.250
Windows login failure for user Administrator from 192.168.1.250
Windows login failure for user Administrator from 192.168.1.250
Windows login failure for user Administrator from 192.168.1.250
Windows login success for user User1 from 192.168.1.151
Windows login failure for user Root from 10.0.0.150
EOF
print_success "Созданы тестовые логи для Windows"

# Генерируем тестовые логи для Ubuntu Server
cat > tests/logs/test_ubuntu_server.log << EOF
Ubuntu login success for user admin from 10.0.0.200
Ubuntu login failure for user admin from 10.0.0.250
Ubuntu login failure for user admin from 10.0.0.250
Ubuntu login failure for user admin from 10.0.0.250
Ubuntu login failure for user admin from 10.0.0.250
Ubuntu login failure for user admin from 10.0.0.250
Ubuntu login success for user user1 from 10.0.0.201
Ubuntu login failure for user root from 192.168.1.50
EOF
print_success "Созданы тестовые логи для Ubuntu"

# Генерируем тестовые логи для Ubuntu Desktop
cat > tests/logs/test_ubuntu_desktop.log << EOF
Ubuntu login success for user desktop_user from 10.0.0.210
Ubuntu login failure for user desktop_user from 10.0.0.251
Ubuntu login failure for user desktop_user from 10.0.0.251
Ubuntu login failure for user desktop_user from 10.0.0.251
Ubuntu login failure for user desktop_user from 10.0.0.251
Ubuntu login failure for user desktop_user from 10.0.0.251
Ubuntu login success for user user2 from 10.0.0.211
Ubuntu login failure for user root from 192.168.1.55
EOF
print_success "Созданы тестовые логи для Ubuntu Desktop"

# Генерируем тестовые логи для YARA сканирования
cat > tests/logs/test_yara.log << EOF
wazuh-yara: INFO - Scan result: malware_rule /path/to/malicious/file.exe
wazuh-yara: INFO - Scan result: ransomware_rule /path/to/suspicious/document.doc
wazuh-yara: WARNING - No matches found for file /path/to/clean/file.txt
EOF
print_success "Созданы тестовые логи для YARA сканирования"

# Генерируем тестовые логи для ping
cat > tests/logs/test_ping.log << EOF
Ping test to 8.8.8.8 is up
Ping test to 192.168.1.1 is up
Ping test to 10.0.0.1 is down
EOF
print_success "Созданы тестовые логи для ping"

print_message "Все тестовые логи успешно созданы в директории tests/logs"
print_message "Для тестирования используйте скрипт scripts/run_local_tests.sh"

exit 0 