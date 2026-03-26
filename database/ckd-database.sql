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
    ('SENT',    'Отправлено'),
    ('SUCCESS', 'Успешно обработано'),
    ('ERROR',   'Ошибка'),
    ('RETRY',   'Повторная отправка');

CREATE TABLE ref.statement_status (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(50)  NOT NULL UNIQUE,
    name VARCHAR(200) NOT NULL
);
COMMENT ON TABLE ref.statement_status IS 'Справочник статусов заявлений';

INSERT INTO ref.statement_status (code, name) VALUES
    ('DRAFT',       'Черновик'),
    ('ON_APPROVAL', 'На согласовании'),
    ('APPROVED',    'Согласовано'),
    ('SIGNED',      'Подписано'),
    ('SENT',        'Отправлено в Росреестр'),
    ('REGISTERED',  'Зарегистрировано'),
    ('REJECTED',    'Отклонено');

-- ──────────────────────────────────────────────────────────────
-- D1: ОБЪЕКТЫ НЕДВИЖИМОСТИ (cadastre)
-- BO: ЗУ, Здание, Помещение
-- ──────────────────────────────────────────────────────────────

CREATE TABLE cadastre.real_estate_object (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cadastral_number VARCHAR(30) NOT NULL,
    object_type_id   INT NOT NULL REFERENCES ref.object_type(id),
    address          TEXT,
    area             NUMERIC(15,2),
    area_unit        VARCHAR(10) DEFAULT 'кв.м',
    parent_id        UUID REFERENCES cadastre.real_estate_object(id),
    status           VARCHAR(30) DEFAULT 'ACTIVE',
    created_at       TIMESTAMPTZ DEFAULT now(),
    updated_at       TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_cadastral_number UNIQUE (cadastral_number)
);
COMMENT ON TABLE cadastre.real_estate_object IS 'D1: Справочник объектов недвижимости (BO: ЗУ, Здание, Помещение)';
COMMENT ON COLUMN cadastre.real_estate_object.parent_id IS 'Иерархия: ЗУ → Здание → Помещение';

CREATE INDEX idx_reo_type   ON cadastre.real_estate_object (object_type_id);
CREATE INDEX idx_reo_parent ON cadastre.real_estate_object (parent_id);

-- ──────────────────────────────────────────────────────────────
-- D2: ВЕРСИИ КАДАСТРОВОЙ ИНФОРМАЦИИ (cadastre)
-- BO: Версия КИ
-- ──────────────────────────────────────────────────────────────

CREATE TABLE cadastre.cadastral_info_version (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id     UUID NOT NULL REFERENCES cadastre.real_estate_object(id),
    version_number INT NOT NULL,
    change_type   VARCHAR(50) NOT NULL CHECK (change_type IN ('ATTRIBUTIVE', 'LEGAL', 'STRUCTURAL')),
    extract_date  DATE,
    source_file   TEXT,
    is_current    BOOLEAN DEFAULT false,
    created_at    TIMESTAMPTZ DEFAULT now(),
    created_by    VARCHAR(200),
    CONSTRAINT uq_object_version UNIQUE (object_id, version_number)
);
COMMENT ON TABLE cadastre.cadastral_info_version IS 'D2: Версии кадастровой информации (BO: Версия КИ)';

CREATE INDEX idx_civ_object  ON cadastre.cadastral_info_version (object_id);
CREATE INDEX idx_civ_current ON cadastre.cadastral_info_version (object_id) WHERE is_current = true;

-- ──────────────────────────────────────────────────────────────
-- D3: РЕГИСТРЫ КИ — Права (cadastre)
-- BO: Право
-- ──────────────────────────────────────────────────────────────

CREATE TABLE cadastre.right_record (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id           UUID NOT NULL REFERENCES cadastre.real_estate_object(id),
    right_type_id       INT  NOT NULL REFERENCES ref.right_type(id),
    registration_number VARCHAR(100),
    registration_date   DATE,
    holder_name         TEXT NOT NULL,
    holder_inn          VARCHAR(12),
    share_numerator     INT,
    share_denominator   INT,
    version_id          UUID REFERENCES cadastre.cadastral_info_version(id),
    is_active           BOOLEAN DEFAULT true,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE cadastre.right_record IS 'D3: Регистр прав на объекты недвижимости (BO: Право)';

CREATE INDEX idx_rr_object ON cadastre.right_record (object_id);

-- ──────────────────────────────────────────────────────────────
-- D3: РЕГИСТРЫ КИ — Обременения (cadastre)
-- BO: Обременение
-- ──────────────────────────────────────────────────────────────

CREATE TABLE cadastre.encumbrance_record (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id           UUID NOT NULL REFERENCES cadastre.real_estate_object(id),
    encumbrance_type_id INT  NOT NULL REFERENCES ref.encumbrance_type(id),
    registration_number VARCHAR(100),
    registration_date   DATE,
    start_date          DATE,
    end_date            DATE,
    holder_name         TEXT,
    description         TEXT,
    version_id          UUID REFERENCES cadastre.cadastral_info_version(id),
    is_active           BOOLEAN DEFAULT true,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE cadastre.encumbrance_record IS 'D3: Регистр обременений объектов недвижимости (BO: Обременение)';

CREATE INDEX idx_er_object ON cadastre.encumbrance_record (object_id);

-- ──────────────────────────────────────────────────────────────
-- D9: РЕГИСТР ЗАЯВЛЕНИЙ (statements)
-- BO: Заявление
-- ──────────────────────────────────────────────────────────────

CREATE TABLE statements.statement (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    number          VARCHAR(50) NOT NULL UNIQUE,
    statement_type  VARCHAR(50) NOT NULL,
    object_id       UUID REFERENCES cadastre.real_estate_object(id),
    status_id       INT  NOT NULL REFERENCES ref.statement_status(id),
    initiator_name  TEXT NOT NULL,
    initiator_email VARCHAR(200),
    signer_name     TEXT,
    signer_position VARCHAR(200),
    signed_at       TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ,
    rosreestr_id    VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE statements.statement IS 'D9: Регистр заявлений (BO: Заявление)';

CREATE INDEX idx_stmt_object ON statements.statement (object_id);
CREATE INDEX idx_stmt_status ON statements.statement (status_id);

CREATE TABLE statements.statement_approval (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    statement_id  UUID NOT NULL REFERENCES statements.statement(id),
    approver_name TEXT NOT NULL,
    approver_role VARCHAR(100),
    decision      VARCHAR(20) NOT NULL CHECK (decision IN ('APPROVED', 'REJECTED', 'RETURNED')),
    comment       TEXT,
    decided_at    TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE statements.statement_approval IS 'D9: Маршрут согласования заявления';

-- ──────────────────────────────────────────────────────────────
-- D6: ИСТОРИЯ ОБМЕНА С ERP/CRM (integration)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE integration.exchange_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    direction       VARCHAR(10) NOT NULL CHECK (direction IN ('OUTBOUND', 'INBOUND')),
    target_system   VARCHAR(30) NOT NULL CHECK (target_system IN ('ERP', 'CRM')),
    operation       VARCHAR(100) NOT NULL,
    endpoint_url    TEXT,
    request_body    JSONB,
    response_body   JSONB,
    http_status     INT,
    status_id       INT NOT NULL REFERENCES ref.exchange_status(id),
    error_message   TEXT,
    object_id       UUID REFERENCES cadastre.real_estate_object(id),
    retry_count     INT DEFAULT 0,
    correlation_id  UUID,
    created_at      TIMESTAMPTZ DEFAULT now(),
    completed_at    TIMESTAMPTZ
);
COMMENT ON TABLE integration.exchange_log IS 'D6: Лог обмена с ERP и CRM (DO: PostLandExportRequest, ObjectWithRoomsRequest)';

CREATE INDEX idx_exl_target ON integration.exchange_log (target_system, created_at DESC);
CREATE INDEX idx_exl_status ON integration.exchange_log (status_id);
CREATE INDEX idx_exl_object ON integration.exchange_log (object_id);

CREATE TABLE integration.export_queue (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id       UUID NOT NULL REFERENCES cadastre.real_estate_object(id),
    target_system   VARCHAR(30) NOT NULL CHECK (target_system IN ('ERP', 'CRM')),
    operation       VARCHAR(100) NOT NULL,
    priority        INT DEFAULT 5,
    payload         JSONB NOT NULL,
    status          VARCHAR(20) DEFAULT 'PENDING',
    scheduled_at    TIMESTAMPTZ DEFAULT now(),
    picked_at       TIMESTAMPTZ,
    exchange_log_id UUID REFERENCES integration.exchange_log(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE integration.export_queue IS 'D6: Очередь отправки данных в ERP/CRM';

CREATE INDEX idx_eq_status ON integration.export_queue (status, priority, scheduled_at);

-- ──────────────────────────────────────────────────────────────
-- D8: ИСТОРИЯ ЗАПРОСОВ К РОСРЕЕСТРУ (rosreestr)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE rosreestr.request_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_type    VARCHAR(50) NOT NULL,
    cadastral_number VARCHAR(30),
    object_id       UUID REFERENCES cadastre.real_estate_object(id),
    statement_id    UUID REFERENCES statements.statement(id),
    status          VARCHAR(30) DEFAULT 'CREATED',
    external_id     VARCHAR(200),
    request_xml     TEXT,
    response_xml    TEXT,
    error_message   TEXT,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE rosreestr.request_log IS 'D8: Лог запросов к Росреестру';

CREATE INDEX idx_rrl_object ON rosreestr.request_log (object_id);
CREATE INDEX idx_rrl_status ON rosreestr.request_log (status);

-- ──────────────────────────────────────────────────────────────
-- D7: ФАЙЛОВОЕ ХРАНИЛИЩЕ (storage)
-- ──────────────────────────────────────────────────────────────

CREATE TABLE storage.file_metadata (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name     VARCHAR(500) NOT NULL,
    file_type     VARCHAR(50)  NOT NULL,
    mime_type     VARCHAR(100),
    file_size     BIGINT,
    sha256_hash   VARCHAR(64),
    s3_bucket     VARCHAR(200),
    s3_key        VARCHAR(500),
    object_id     UUID REFERENCES cadastre.real_estate_object(id),
    version_id    UUID REFERENCES cadastre.cadastral_info_version(id),
    uploaded_by   VARCHAR(200),
    created_at    TIMESTAMPTZ DEFAULT now()
);
COMMENT ON TABLE storage.file_metadata IS 'D7: Метаданные файлов (выписки ЕГРН, XML, подписи)';

CREATE INDEX idx_fm_object ON storage.file_metadata (object_id);

-- ──────────────────────────────────────────────────────────────
-- VIEWS
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW cadastre.v_current_rights AS
SELECT
    reo.cadastral_number,
    reo.address,
    ot.name  AS object_type,
    rt.name  AS right_type,
    rr.holder_name,
    rr.registration_number,
    rr.registration_date
FROM cadastre.right_record rr
JOIN cadastre.real_estate_object reo ON reo.id = rr.object_id
JOIN ref.object_type ot ON ot.id = reo.object_type_id
JOIN ref.right_type  rt ON rt.id = rr.right_type_id
WHERE rr.is_active = true;

COMMENT ON VIEW cadastre.v_current_rights IS 'Витрина: актуальные права на объекты недвижимости';

CREATE OR REPLACE VIEW cadastre.v_active_encumbrances AS
SELECT
    reo.cadastral_number,
    reo.address,
    ot.name  AS object_type,
    et.name  AS encumbrance_type,
    er.holder_name,
    er.start_date,
    er.end_date
FROM cadastre.encumbrance_record er
JOIN cadastre.real_estate_object reo ON reo.id = er.object_id
JOIN ref.object_type ot ON ot.id = reo.object_type_id
JOIN ref.encumbrance_type et ON et.id = er.encumbrance_type_id
WHERE er.is_active = true;

COMMENT ON VIEW cadastre.v_active_encumbrances IS 'Витрина: актуальные обременения объектов';

-- ──────────────────────────────────────────────────────────────
-- ТЕСТОВЫЕ ДАННЫЕ
-- ──────────────────────────────────────────────────────────────

INSERT INTO cadastre.real_estate_object (id, cadastral_number, object_type_id, address, area) VALUES
    ('a1000001-0001-0001-0001-000000000001', '77:17:0120114:1001', 1, 'г. Москва, поселение Сосенское, ул. Лобановский Лес, участок 1', 15000.00),
    ('a1000001-0001-0001-0001-000000000002', '77:17:0120114:2001', 2, 'г. Москва, поселение Сосенское, ул. Лобановский Лес, д. 7', 8500.50),
    ('a1000001-0001-0001-0001-000000000003', '77:17:0120114:3001', 3, 'г. Москва, поселение Сосенское, ул. Лобановский Лес, д. 7, кв. 1', 65.30),
    ('a1000001-0001-0001-0001-000000000004', '77:17:0120114:3002', 3, 'г. Москва, поселение Сосенское, ул. Лобановский Лес, д. 7, кв. 2', 42.10),
    ('a1000001-0001-0001-0001-000000000005', '50:21:0100101:501',  1, 'Московская обл., г.о. Домодедово, участок 5', 25000.00);

-- Иерархия: ЗУ → Здание → Помещения
UPDATE cadastre.real_estate_object SET parent_id = 'a1000001-0001-0001-0001-000000000001' WHERE id = 'a1000001-0001-0001-0001-000000000002';
UPDATE cadastre.real_estate_object SET parent_id = 'a1000001-0001-0001-0001-000000000002' WHERE id IN ('a1000001-0001-0001-0001-000000000003', 'a1000001-0001-0001-0001-000000000004');

INSERT INTO cadastre.cadastral_info_version (object_id, version_number, change_type, extract_date, is_current, created_by) VALUES
    ('a1000001-0001-0001-0001-000000000001', 1, 'ATTRIBUTIVE', '2025-06-15', false, 'system'),
    ('a1000001-0001-0001-0001-000000000001', 2, 'LEGAL',       '2025-12-20', true,  'system'),
    ('a1000001-0001-0001-0001-000000000002', 1, 'ATTRIBUTIVE', '2025-09-10', true,  'system');

INSERT INTO cadastre.right_record (object_id, right_type_id, registration_number, registration_date, holder_name, holder_inn, is_active) VALUES
    ('a1000001-0001-0001-0001-000000000001', 1, '77:17:0120114:1001-77/012/2024-1', '2024-03-15', 'ООО "А101"', '7751234567', true),
    ('a1000001-0001-0001-0001-000000000002', 1, '77:17:0120114:2001-77/012/2024-2', '2024-05-20', 'ООО "А101"', '7751234567', true),
    ('a1000001-0001-0001-0001-000000000003', 1, '77:17:0120114:3001-77/012/2025-1', '2025-01-10', 'Иванов И.И.', NULL, true);

INSERT INTO cadastre.encumbrance_record (object_id, encumbrance_type_id, registration_number, registration_date, start_date, holder_name, is_active) VALUES
    ('a1000001-0001-0001-0001-000000000001', 3, '77:17:0120114:1001-77/012/2024-А1', '2024-06-01', '2024-06-01', 'ПАО "Сбербанк"', true);

INSERT INTO statements.statement (number, statement_type, object_id, status_id, initiator_name, initiator_email) VALUES
    ('STMT-2026-001', 'EXTRACT_REQUEST', 'a1000001-0001-0001-0001-000000000001', 1, 'Петров А.С.', 'petrov@a101.ru'),
    ('STMT-2026-002', 'EXTRACT_REQUEST', 'a1000001-0001-0001-0001-000000000005', 3, 'Сидорова М.В.', 'sidorova@a101.ru');

INSERT INTO integration.exchange_log (direction, target_system, operation, endpoint_url, http_status, status_id, object_id) VALUES
    ('OUTBOUND', 'CRM', 'ObjectWithRoomsRequest', '/hs/ckd/v1/objects', 200, 3, 'a1000001-0001-0001-0001-000000000002'),
    ('OUTBOUND', 'ERP', 'PostLandExportRequest',  '/hs/ckd/v1/land-plots', 200, 3, 'a1000001-0001-0001-0001-000000000001');

-- ============================================================
-- Готово. 6 схем, 16 таблиц, 5 справочников, 2 view, тестовые данные.
-- ============================================================
