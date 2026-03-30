# Интеграция с системами мониторинга

Этот документ описывает способы интеграции CI/CD процесса с различными системами мониторинга для отслеживания статуса конфигурации Wazuh.

## Prometheus и Grafana

### Настройка экспортера метрик

Для мониторинга состояния Wazuh и CI/CD процесса можно использовать Prometheus и Grafana. Ниже приведен пример настройки экспортера метрик для Wazuh.

1. Добавьте в `docker-compose.yml` сервис с экспортером Wazuh:

```yaml
services:
  # ... существующие сервисы ...
  
  wazuh-exporter:
    image: vulliem/wazuh-exporter:latest
    restart: always
    networks:
      - wazuh
    ports:
      - "9090:9090"
    environment:
      - WAZUH_API_URL=https://wazuh.manager:55000
      - WAZUH_API_USER=wazuh
      - WAZUH_API_PASSWORD=wazuh
      - WAZUH_VERIFY_SSL=false
```

2. Создайте конфигурацию Prometheus для сбора метрик:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'wazuh'
    static_configs:
      - targets: ['wazuh-exporter:9090']
```

3. Настройте дашборд в Grafana для визуализации метрик Wazuh.

## Мониторинг статуса CI/CD с помощью GitHub API

Можно создать отдельный скрипт, который будет проверять статус CI/CD процессов через GitHub API и отправлять метрики в вашу систему мониторинга.

Пример скрипта на Python:

```python
#!/usr/bin/env python3
import requests
import time
import os

# Конфигурация
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
REPO_OWNER = "your-username"
REPO_NAME = "wazuh"
WORKFLOW_NAME = "Wazuh CI/CD"

# Адрес API
API_URL = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/actions/workflows"

headers = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

def get_workflow_runs():
    response = requests.get(f"{API_URL}", headers=headers)
    workflows = response.json()["workflows"]
    
    for workflow in workflows:
        if workflow["name"] == WORKFLOW_NAME:
            workflow_id = workflow["id"]
            runs_url = f"{API_URL}/{workflow_id}/runs"
            runs_response = requests.get(runs_url, headers=headers)
            return runs_response.json()["workflow_runs"]
    
    return []

def monitor_ci_status():
    runs = get_workflow_runs()
    if not runs:
        print("No workflow runs found")
        return
    
    latest_run = runs[0]
    status = latest_run["status"]
    conclusion = latest_run["conclusion"]
    
    print(f"Latest run: {latest_run['id']}")
    print(f"Status: {status}")
    print(f"Conclusion: {conclusion}")
    
    # Здесь можно добавить отправку метрик в вашу систему мониторинга
    # Например, в Prometheus Pushgateway

if __name__ == "__main__":
    while True:
        monitor_ci_status()
        time.sleep(300)  # Проверка каждые 5 минут
```

## Telegram бот для уведомлений

Если вы предпочитаете получать уведомления в Telegram, можно добавить соответствующий шаг в CI/CD workflow:

```yaml
- name: Send Telegram notification
  uses: appleboy/telegram-action@master
  with:
    to: ${{ secrets.TELEGRAM_TO }}
    token: ${{ secrets.TELEGRAM_TOKEN }}
    message: |
      🔔 CI/CD для Wazuh завершён!
      Статус: ${{ job.status }}
      Коммит: ${{ github.event.head_commit.message }}
      Репозиторий: ${{ github.repository }}
      Автор: ${{ github.actor }}
      Ссылка: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

## Интеграция с системами автоматизации

### Webhooks для автоматизации

GitHub Actions поддерживает отправку событий окончания workflow через webhook. Это можно использовать для автоматического обновления статуса в других системах.

Пример добавления webhook в конец workflow:

```yaml
- name: Webhook
  uses: distributhor/workflow-webhook@v2
  env:
    webhook_url: ${{ secrets.WEBHOOK_URL }}
    webhook_secret: ${{ secrets.WEBHOOK_SECRET }}
    data: '{"status": "${{ job.status }}", "repository": "${{ github.repository }}", "run_id": "${{ github.run_id }}"}'
```

## Мониторинг с помощью Teams

Для организаций, использующих Microsoft Teams, можно добавить уведомления через карточки адаптивных сообщений:

```yaml
- name: Microsoft Teams notification
  uses: skitionek/notify-microsoft-teams@master
  if: always()
  with:
    webhook_url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    needs: ${{ toJson(needs) }}
    job: ${{ toJson(job) }}
    steps: ${{ toJson(steps) }}
``` 