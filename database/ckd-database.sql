-- ============================================================
-- ЦКД (Центр Кадастровых Данных) — PostgreSQL Database Schema
-- А101 · Март 2026
-- ============================================================
-- Соответствие хранилищам ArchiMate-модели:
--   D1: Объекты (справочник ОН)     → schema: cadastre
--   D2: Версии КИ                   → schema: cadastre (version tables)
--   D3: Регистры КИ                 → schema: cadastre (registry tables)
--   D6: ИсторияОбмена (ERP/CRM)     → schema: integration
--   D7: Файловое хранилище          → schema: storage
--   D8: ИсторияЗапросов (Росреестр)  → schema: rosreestr
--   D9: Регистр заявлений           → schema: statements
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- SCHEMAS
-- ──────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS cadastre;
CREATE SCHEMA IF NOT EXISTS statements;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS rosreestr;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS ref;

-- ──────────────────────────────────────────────────────────────
-- СПРАВОЧНИКИ (ref)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE ref.object_type (
    id          SERIAL PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL UNIQUE,
    name        VARCHAR(200) NOT NULL,
    description TEXT
);
COMMENT ON TABLE ref.object_type IS 'Справочник типов объектов недвижимости';

INSERT INTO ref.object_type (code, name) VALUES
    ('LAND_PLOT',    'Земельный участок'),
    ('BUILDING',     'Здание'),
    ('ROOM',         'Помещение'),
    ('CONSTRUCTION', 'Сооружение'),
    ('PARKING',      'Машино-место');

CREATE TABLE ref.right_type (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);
COMMENT ON TABLE ref.right_type IS 'Справочник видов прав';

INSERT INTO ref.right_type (code, name) VALUES
    ('OWNERSHIP',     'Собственность'),
    ('LEASE',         'Аренда'),
    ('PERMANENT_USE', 'Постоянное (бессрочное) пользование'),
    ('EASEMENT',      'Сервитут'),
    ('MORTGAGE',      'Ипотека');

CREATE TABLE ref.encumbrance_type (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);
COMMENT ON TABLE ref.encumbrance_type IS 'Справочник видов обременений';

INSERT INTO ref.encumbrance_type (code, name) VALUES
    ('ARREST',       'Арест'),
    ('PROHIBITION',  'Запрещение'),
    ('LEASE_ENC',    'Аренда (обременение)'),
    ('MORTGAGE_ENC', 'Ипотека (обременение)'),
    ('EASEMENT_ENC', 'Сервитут (обременение)');

CREATE TABLE ref.exchange_status (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);
COMMENT ON TABLE ref.exchange_status IS 'Справочник статусов обмена';

INSERT INTO ref.exchange_status (code, name) VALUES
    ('PENDING', 'Ожидает отправки'),
