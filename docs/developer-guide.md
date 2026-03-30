# Руководство разработчика по добавлению правил и декодеров

Этот документ содержит рекомендации по добавлению новых правил и декодеров для Wazuh, с учетом настроенного CI/CD процесса.

## Структура правил и декодеров

Все правила и декодеры хранятся в соответствующих директориях репозитория:
- `rules/` - директория с файлами правил
- `decoders/` - директория с файлами декодеров

## Процесс добавления новых правил и декодеров

### 1. Подготовка рабочей среды

1. Клонируйте репозиторий:
   ```bash
   git clone <URL репозитория>
   cd wazuh
   ```

2. Создайте отдельную ветку для работы:
   ```bash
   git checkout -b feature/new-rules-decoders
   ```

3. Запустите скрипт генерации тестовых логов:
   ```bash
   chmod +x scripts/generate_test_logs.sh
   ./scripts/generate_test_logs.sh
   ```

### 2. Добавление нового декодера

1. Откройте файл `decoders/local_decoder.xml` и добавьте новый декодер в формате:
   ```xml
   <decoder name="название-декодера">
     <prematch>уникальная-строка-для-идентификации-лога</prematch>
   </decoder>

   <decoder name="название-декодера-дочерний">
     <parent>название-декодера</parent>
     <regex offset="after_prematch">регулярное-выражение-для-извлечения-полей</regex>
     <order>имя-поля1, имя-поля2, ...</order>
   </decoder>
   ```

2. Примеры декодеров:
   ```xml
   <!-- Декодер для логина в MikroTik -->
   <decoder name="mikrotik-login">
     <parent>mikrotik</parent>
     <prematch>login success</prematch>
     <regex offset="after_prematch">for user (\S+) from (\S+) via (\S+)</regex>
     <order>user, srcip, protocol</order>
   </decoder>
   ```

### 3. Добавление нового правила

1. Откройте файл `rules/local_rules.xml` и добавьте новое правило в формате:
   ```xml
   <rule id="номер-правила" level="уровень-важности">
     <decoded_as>название-декодера</decoded_as>
     <description>Описание правила</description>
   </rule>
   ```

2. Примеры правил:
   ```xml
   <!-- Правило для успешного входа в MikroTik -->
   <rule id="100201" level="3">
     <decoded_as>mikrotik-login-success</decoded_as>
     <description>MikroTik: Пользователь $(user) успешно вошел в систему с $(srcip) по протоколу $(protocol)</description>
   </rule>

   <!-- Правило для обнаружения брутфорс атаки -->
   <rule id="111002" level="12" frequency="5" timeframe="240">
     <if_matched_sid>100200</if_matched_sid>
     <same_source_ip />
     <description>MikroTik: Обнаружена брутфорс атака с $(srcip)</description>
   </rule>
   ```

### 4. Локальное тестирование

1. Проверьте синтаксис XML-файлов:
   ```bash
   xmllint --noout rules/local_rules.xml decoders/local_decoder.xml
   ```

2. Запустите Wazuh для тестирования:
   ```bash
   docker-compose up -d
   ```

3. Скопируйте правила и декодеры в контейнер:
   ```bash
   docker cp rules/local_rules.xml $(docker-compose ps -q wazuh.manager):/var/ossec/etc/rules/
   docker cp decoders/local_decoder.xml $(docker-compose ps -q wazuh.manager):/var/ossec/etc/decoders/
   ```

4. Перезапустите Wazuh:
   ```bash
   docker-compose exec wazuh.manager /var/ossec/bin/wazuh-control restart
   ```

5. Проверьте логи на ошибки:
   ```bash
   docker-compose exec wazuh.manager grep -i "error\|critical" /var/ossec/logs/ossec.log
   ```

6. Протестируйте правила с примерами логов:
   ```bash
   # Пример тестирования декодера и правила
   docker-compose exec wazuh.manager bash -c 'echo "Mikrotik login success for user admin from 192.168.1.100 via ssh" | /var/ossec/bin/wazuh-logtest'
   ```

### 5. Валидация с помощью pre-commit хука

1. Убедитесь, что pre-commit хук установлен:
   ```bash
   chmod +x .git/hooks/pre-commit
   ```

2. Перед коммитом хук автоматически запустит проверку:
   ```bash
   git add .
   git commit -m "Добавлены новые правила и декодеры"
   ```

### 6. Отправка изменений и создание Pull Request

1. Отправьте изменения в удаленный репозиторий:
   ```bash
   git push origin feature/new-rules-decoders
   ```

2. Создайте Pull Request через интерфейс GitHub.

3. CI/CD процесс автоматически запустится и проверит вашу конфигурацию. Отслеживайте результаты проверки на вкладке Actions в GitHub.

## Советы и рекомендации

### Нумерация правил

- Используйте уникальные ID для правил в диапазоне 100000-119999
- 100xxx - для основных правил
- 111xxx - для правил обнаружения атак (брутфорс и пр.)

### Уровни важности правил

Рекомендуемые уровни важности:
- 0: Не вызывает алерт, используется для группировки
- 3: Информационный (успешный вход, выход из системы и т.д.)
- 5: Системное предупреждение (перезагрузка, запуск сервисов)
- 7: Безопасность (неудачная попытка входа)
- 10: Первый уровень критичности (нарушение важных правил безопасности)
- 12: Второй уровень критичности (брутфорс атаки, множественные нарушения)
- 15: Критическая угроза (успешная атака, эксплуатация уязвимости)

### Поддерживаемые поля в правилах

При создании правил вы можете ссылаться на поля, определенные в декодерах:
- `srcip` - IP-адрес источника
- `user` или `dstuser` - имя пользователя
- `protocol` - протокол доступа
- и другие поля, определенные в декодерах через тег `<order>`

### Группировка правил

Рекомендуется группировать правила по типу устройства или системы:
- `<group name="local,windows,">` - для Windows правил
- `<group name="local,mikrotik,">` - для MikroTik правил

### Специальные поля правил

- `if_sid` - ID родительского правила для связывания
- `if_matched_sid` - ID правила для создания корреляции
- `frequency, timeframe` - для правил, срабатывающих на повторяющиеся события
- `same_source_ip` - для отслеживания событий с одного IP-адреса

## Отладка и устранение проблем

### Проблемы с синтаксисом XML

Если тесты CI/CD падают с ошибкой валидации XML, проверьте:
- Закрытие всех открытых тегов
- Уникальность ID правил
- Корректные ссылки на parent-декодеры

### Проблемы с декодерами

Если декодер не работает, проверьте:
- Правильно ли заданы регулярные выражения в тегах `<regex>`
- Соответствуют ли порядок полей в `<order>` группам в регулярном выражении
- Правильно ли указаны родительские декодеры (`<parent>`)

### Проблемы с правилами

Если правило не срабатывает:
- Проверьте, что декодер правильно разбирает лог
- Убедитесь в корректности ссылок на поля в описании
- Проверьте условия правила (`if_sid`, `if_matched_sid`, `frequency` и т.д.)

### Просмотр отладочной информации

Для просмотра подробной информации о разборе логов используйте:
```bash
docker-compose exec wazuh.manager bash -c 'echo "тестовый лог" | /var/ossec/bin/wazuh-logtest -v'
``` 