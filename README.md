# YouTube Channel Analytics Pipeline

Этот проект реализует конвейер для сбора статистики YouTube-канала "Виктор Елисеев БИЗНЕС НАПРОЛОМ" и подготовки аналитических отчётов. Решение может сохранять результаты локально или публиковать их в сервисы Google (например, Google Sheets), откуда данные можно подключить к BI-инструментам.

## Возможности

- Получение сводной статистики канала (подписчики, просмотры, количество видео).
- Загрузка метаданных и статистики отдельных роликов с учётом пагинации.
- Вычисление агрегированных метрик (топ-ролики, динамика публикаций, усреднённые показатели).
- Экспорт данных в CSV/JSON файлы или Google Sheets для последующей визуализации в Google Looker Studio / BI.

## Быстрый старт

1. Создайте API-ключ YouTube Data API v3 в [Google Cloud Console](https://console.cloud.google.com/).
2. Сохраните ключ в переменную окружения:
   ```bash
   export YOUTUBE_API_KEY="ваш_ключ"
   ```
3. (Опционально) Создайте сервисный аккаунт и JSON-ключ для доступа к Google Sheets. Поделитесь целевой таблицей с адресом сервисного аккаунта.
4. Установите зависимости и запустите конвейер:
   ```bash
   pip install -e .
   python -m youtube_parser.cli \
     --channel-id UCdwN2l9VmZpK5x6tEN84ImA \
     --max-videos 200 \
     --export csv \
     --output-path analytics.csv
   ```

## Экспорт в Google Sheets

Передайте путь к JSON-ключу сервисного аккаунта и идентификатор таблицы:

```bash
python -m youtube_parser.cli \
  --channel-id UCdwN2l9VmZpK5x6tEN84ImA \
  --export google-sheets \
  --service-account-key path/to/key.json \
  --spreadsheet-id 1AbCdEf...
```

Конвейер создаст или обновит лист `Channel Overview` и `Videos` в указанной таблице.

## Структура проекта

- `src/youtube_parser/client.py` — низкоуровневый клиент YouTube Data API.
- `src/youtube_parser/analytics.py` — расчёт агрегатов и KPI.
- `src/youtube_parser/exporters.py` — механизмы выгрузки.
- `src/youtube_parser/pipeline.py` — основной конвейер.
- `src/youtube_parser/cli.py` — интерфейс командной строки.

## Развитие

- Добавление исторического слежения с хранением в базе данных.
- Интеграция с Google BigQuery или другими BI-платформами.
- Построение автоматизированных дашбордов на основе Looker Studio.

## Лицензия

MIT
