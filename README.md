# A101 Architecture — Architecture as Git

Архитектурная модель ИТ-ландшафта А101 в формате ArchiMate, версионируемая через Git.

## Подход

**Architecture as Git** — архитектура версионируется как код:

| Git-операция | Архитектурный смысл |
|---|---|
| `commit` | Зафиксировали архитектурное решение |
| `diff` | Что именно изменилось между версиями |
| `log` | История архитектурных решений |
| `blame` | Кто и когда добавил этот элемент |
| `branch` | Target architecture / «а что если?» |
| `merge` | Объединение изменений от разных аналитиков |

## Инструменты

- **[Archi](https://www.archimatetool.com/)** — моделирование ArchiMate (open-source)
- **[coArchi](https://github.com/archi-contribs/coArchi)** — плагин совместной работы через Git
- **[jArchi](https://www.archimatetool.com/plugins/)** — скриптинг (импорт DDL, автоматизация)

## Структура репозитория

```
├── model/                          # ArchiMate-модель (coArchi формат)
│   ├── folder.xml
│   ├── elements/
│   │   ├── ApplicationComponent_*.xml
│   │   ├── BusinessService_*.xml
│   │   ├── DataObject_*.xml
│   │   └── ...
│   ├── relations/
│   └── views/
├── database/
│   └── ckd-database.sql            # DDL схемы БД ЦКД (PostgreSQL)
├── scripts/
│   ├── import-ddl-to-archimate.ajs  # Импорт DDL → Data Objects
│   └── open-swagger.ajs            # Открытие Swagger по клику
├── docs/
│   └── workshop-plan.md            # План воркшопа
└── README.md
```

## Быстрый старт

### 1. Установка Archi + плагины

1. Скачать [Archi](https://www.archimatetool.com/download/) (Windows / macOS / Linux)
2. Help → Manage Plug-ins → установить **coArchi** и **jArchi**
3. Перезапустить Archi

### 2. Подключение к репозиторию

```
Archi → Collaboration → Import Remote Model
URL:      https://github.com/<username>/a101-architecture.git
Username: <github-username>
Password: <personal-access-token>
```

### 3. Развёртывание тестовой БД

```bash
psql -U postgres -c "CREATE DATABASE ckd"
psql -U postgres -d ckd -f database/ckd-database.sql
```

БД содержит: 6 схем, 16 таблиц, 5 справочников, 2 view, тестовые данные.

Схемы соответствуют хранилищам ArchiMate-модели:
- `cadastre` → D1 (объекты ОН), D2 (версии КИ), D3 (регистры)
- `statements` → D9 (регистр заявлений)
- `integration` → D6 (история обмена ERP/CRM)
- `rosreestr` → D8 (запросы к Росреестру)
- `storage` → D7 (файловое хранилище)
- `ref` → справочники

### 4. Импорт DDL в модель

```
Archi → Scripts → Run Script → scripts/import-ddl-to-archimate.ajs
→ выбрать database/ckd-database.sql
```

Результат: Data Objects с Properties (колонки, типы, PK), FK → Associations, Schema → Grouping.

### 5. Swagger по клику

Добавьте property `swagger_url` на Application Interface:

| Property | Пример значения |
|---|---|
| `swagger_url` | `https://api.a101.ru/ckd/v1/swagger-ui.html` |
| `api_version` | `v1` |
| `auth_type` | `Basic Auth` |

Затем: выделить элемент → `Scripts → Run Script → scripts/open-swagger.ajs`

## Связка с CMDB

Каждый элемент модели содержит property `cmdb_id` для маппинга на CI в CMDB:

| ArchiMate | CMDB CI | Пример |
|---|---|---|
| Application Component | Информационная система | AC «ERP» ↔ CI «1С:ERP 2.5» |
| Application Interface | Интеграция | IF «REST API» ↔ CI «Инт-001» |
| Technology Node | Сервер / ВМ | Node ↔ CI «srv-erp-01» |

## Правила работы

1. **Один элемент — одно место.** Не дублируем. Используем на нескольких диаграммах.
2. **Осмысленные коммиты.** Не «обновил модель», а «добавил интеграцию ЦКД → CRM: ObjectWithRoomsRequest».
3. **cmdb_id заполняем.** Каждый Application Component, Node, Interface должен иметь ссылку на CMDB.
4. **Ревью.** Перед Publish — проверяем что модель валидна (no orphan elements).
