-- Создание таблицы хронистов
CREATE TABLE chroniclers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    rank VARCHAR(50) NOT NULL,
    years_of_service INTEGER NOT NULL CHECK (years_of_service >= 0)
);

-- Создание таблицы экспедиций
CREATE TABLE expeditions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(100) NOT NULL,
    danger_level INTEGER NOT NULL CHECK (danger_level BETWEEN 1 AND 5)
);

-- Создание таблицы участия
CREATE TABLE expedition_participation (
    id SERIAL PRIMARY KEY,
    chronicler_id INTEGER NOT NULL,
    expedition_id INTEGER NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('разведчик', 'писец', 'защитник')),
    gold_reward INTEGER NOT NULL CHECK (gold_reward >= 0),
    FOREIGN KEY (chronicler_id) REFERENCES chroniclers(id) ON DELETE CASCADE,
    FOREIGN KEY (expedition_id) REFERENCES expeditions(id) ON DELETE CASCADE,
    UNIQUE(chronicler_id, expedition_id) -- предотвращаем дублирование участия
);
