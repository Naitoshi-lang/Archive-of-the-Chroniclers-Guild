-- =============================================
-- СИСТЕМА УПРАВЛЕНИЯ АРХИВОМ ГИЛЬДИИ ХРОНИСТОВ
-- =============================================

-- Создание основных таблиц
CREATE TABLE IF NOT EXISTS chroniclers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    rank TEXT NOT NULL,
    years_of_service INTEGER NOT NULL CHECK (years_of_service >= 0),
    join_date DATE DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'активен' CHECK (status IN ('активен', 'в отпуске', 'на задании', 'выбыл'))
);

CREATE TABLE IF NOT EXISTS expeditions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    region TEXT NOT NULL,
    danger_level INTEGER NOT NULL CHECK (danger_level BETWEEN 1 AND 5),
    start_date DATE,
    end_date DATE,
    description TEXT,
    status TEXT DEFAULT 'планируется' CHECK (status IN ('планируется', 'в процессе', 'завершена', 'отменена'))
);

CREATE TABLE IF NOT EXISTS expedition_participation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chronicler_id INTEGER NOT NULL,
    expedition_id INTEGER NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('разведчик', 'писец', 'защитник', 'картограф', 'исследователь')),
    gold_reward REAL NOT NULL CHECK (gold_reward >= 0),
    notes TEXT,
    UNIQUE(chronicler_id, expedition_id),
    FOREIGN KEY (chronicler_id) REFERENCES chroniclers(id) ON DELETE CASCADE,
    FOREIGN KEY (expedition_id) REFERENCES expeditions(id) ON DELETE CASCADE
);

-- =============================================
-- ТАБЛИЦЫ ДЛЯ РАСШИРЕННОЙ ФУНКЦИОНАЛЬНОСТИ
-- =============================================

-- Таблица артефактов
CREATE TABLE IF NOT EXISTS artifacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expedition_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    type TEXT CHECK (type IN ('документ', 'реликвия', 'археологический', 'магический', 'иной')),
    found_by INTEGER,
    current_location TEXT DEFAULT 'архив гильдии',
    value REAL,
    description TEXT,
    FOREIGN KEY (expedition_id) REFERENCES expeditions(id),
    FOREIGN KEY (found_by) REFERENCES chroniclers(id)
);

-- Таблица навыков хронистов
CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chronicler_id INTEGER NOT NULL,
    skill_name TEXT NOT NULL,
    proficiency_level INTEGER DEFAULT 1 CHECK (proficiency_level BETWEEN 1 AND 5),
    FOREIGN KEY (chronicler_id) REFERENCES chroniclers(id) ON DELETE CASCADE
);

-- Таблица регионов
CREATE TABLE IF NOT EXISTS regions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    danger_level INTEGER CHECK (danger_level BETWEEN 1 AND 5),
    description TEXT
);

-- Журнал событий
CREATE TABLE IF NOT EXISTS event_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_type TEXT NOT NULL,
    description TEXT NOT NULL,
    chronicler_id INTEGER,
    expedition_id INTEGER,
    FOREIGN KEY (chronicler_id) REFERENCES chroniclers(id),
    FOREIGN KEY (expedition_id) REFERENCES expeditions(id)
);

-- =============================================
-- ИНДЕКСЫ ДЛЯ ОПТИМИЗАЦИИ
-- =============================================

CREATE INDEX IF NOT EXISTS idx_chroniclers_name ON chroniclers(name);
CREATE INDEX IF NOT EXISTS idx_chroniclers_rank ON chroniclers(rank);
CREATE INDEX IF NOT EXISTS idx_chroniclers_service ON chroniclers(years_of_service);

CREATE INDEX IF NOT EXISTS idx_expeditions_name ON expeditions(name);
CREATE INDEX IF NOT EXISTS idx_expeditions_region ON expeditions(region);
CREATE INDEX IF NOT EXISTS idx_expeditions_danger ON expeditions(danger_level);
CREATE INDEX IF NOT EXISTS idx_expeditions_dates ON expeditions(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_participation_chronicler ON expedition_participation(chronicler_id);
CREATE INDEX IF NOT EXISTS idx_participation_expedition ON expedition_participation(expedition_id);
CREATE INDEX IF NOT EXISTS idx_participation_role ON expedition_participation(role);

CREATE INDEX IF NOT EXISTS idx_event_log_dates ON event_log(event_date);
CREATE INDEX IF NOT EXISTS idx_event_log_type ON event_log(event_type);

-- =============================================
-- ТРИГГЕРЫ ДЛЯ АВТОМАТИЗАЦИИ
-- =============================================

-- Триггер для автоматического увеличения стажа
CREATE TRIGGER IF NOT EXISTS update_service_years
AFTER UPDATE OF join_date ON chroniclers
FOR EACH ROW
BEGIN
    UPDATE chroniclers 
    SET years_of_service = CAST((julianday('now') - julianday(NEW.join_date)) / 365.25 AS INTEGER)
    WHERE id = NEW.id;
END;

-- Триггер для логирования изменений в таблице хронистов
CREATE TRIGGER IF NOT EXISTS log_chronicler_changes
AFTER INSERT ON chroniclers
FOR EACH ROW
BEGIN
    INSERT INTO event_log (event_type, description, chronicler_id)
    VALUES ('новый_хронист', 'Добавлен новый хронист: ' || NEW.name, NEW.id);
END;

-- Триггер для проверки уровня опасности экспедиции
CREATE TRIGGER IF NOT EXISTS check_danger_level
BEFORE INSERT ON expeditions
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NEW.danger_level < 1 THEN
            RAISE(ABORT, 'Уровень опасности не может быть меньше 1')
        WHEN NEW.danger_level > 5 THEN
            RAISE(ABORT, 'Уровень опасности не может быть больше 5')
    END;
END;

-- Триггер для автоматического обновления статуса экспедиции
CREATE TRIGGER IF NOT EXISTS update_expedition_status
AFTER UPDATE OF end_date ON expeditions
FOR EACH ROW
BEGIN
    UPDATE expeditions 
    SET status = CASE 
        WHEN NEW.end_date IS NULL THEN 'в процессе'
        WHEN NEW.end_date <= date('now') THEN 'завершена'
        ELSE 'планируется'
    END
    WHERE id = NEW.id;
END;

-- =============================================
-- ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ АНАЛИТИКИ
-- =============================================

-- Представление для отчета по хронистам
CREATE VIEW IF NOT EXISTS v_chroniclers_report AS
SELECT 
    c.id,
    c.name,
    c.rank,
    c.years_of_service,
    c.join_date,
    c.status,
    COUNT(ep.expedition_id) as total_expeditions,
    COALESCE(SUM(ep.gold_reward), 0) as total_gold_earned,
    GROUP_CONCAT(DISTINCT ep.role) as roles_held
FROM chroniclers c
LEFT JOIN expedition_participation ep ON c.id = ep.chronicler_id
GROUP BY c.id, c.name, c.rank, c.years_of_service, c.join_date, c.status;

-- Представление для отчета по экспедициям
CREATE VIEW IF NOT EXISTS v_expeditions_report AS
SELECT 
    e.id,
    e.name,
    e.region,
    e.danger_level,
    e.start_date,
    e.end_date,
    e.status,
    COUNT(DISTINCT ep.chronicler_id) as participants_count,
    COALESCE(SUM(ep.gold_reward), 0) as total_gold_paid,
    GROUP_CONCAT(DISTINCT c.name, ': ', ep.role) as participants_info
FROM expeditions e
LEFT JOIN expedition_participation ep ON e.id = ep.expedition_id
LEFT JOIN chroniclers c ON ep.chronicler_id = c.id
GROUP BY e.id, e.name, e.region, e.danger_level, e.start_date, e.end_date, e.status;

-- Представление для финансового отчета
CREATE VIEW IF NOT EXISTS v_financial_report AS
SELECT 
    strftime('%Y-%m', e.start_date) as month,
    e.region,
    COUNT(DISTINCT e.id) as expeditions_count,
    COUNT(DISTINCT ep.chronicler_id) as chroniclers_count,
    SUM(ep.gold_reward) as total_gold_spent,
    AVG(ep.gold_reward) as avg_reward_per_chronicler
FROM expeditions e
JOIN expedition_participation ep ON e.id = ep.expedition_id
WHERE e.status = 'завершена'
GROUP BY strftime('%Y-%m', e.start_date), e.region;

-- Представление для статистики по ролям
CREATE VIEW IF NOT EXISTS v_role_statistics AS
SELECT 
    role,
    COUNT(*) as assignments_count,
    COUNT(DISTINCT chronicler_id) as unique_chroniclers,
    AVG(gold_reward) as average_gold_reward,
    SUM(gold_reward) as total_gold_reward
FROM expedition_participation
GROUP BY role
ORDER BY assignments_count DESC;
