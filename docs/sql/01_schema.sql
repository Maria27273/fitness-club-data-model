-- Создание базы данных
CREATE DATABASE fitness_club;

-- Таблица Клиенты
CREATE TABLE КЛИЕНТ (
    client_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(100) UNIQUE,
    birth_date DATE CHECK (birth_date <= CURRENT_DATE - INTERVAL '14 years'),
    registration_date DATE DEFAULT CURRENT_DATE
);

-- Таблица Тренеры
CREATE TABLE ТРЕНЕР (
    trainer_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialization VARCHAR(50),
    experience_years INTEGER DEFAULT 0 CHECK (experience_years >= 0)
);

-- Таблица Абонементы
CREATE TABLE АБОНЕМЕНТ (
    membership_id SERIAL PRIMARY KEY,
    client_id INTEGER UNIQUE REFERENCES КЛИЕНТ(client_id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('разовый', 'месячный', 'годовой')),
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'активен' CHECK (status IN ('активен', 'закончен', 'заблокирован')),
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Таблица Занятия
CREATE TABLE ЗАНЯТИЕ (
    session_id SERIAL PRIMARY KEY,
    trainer_id INTEGER REFERENCES ТРЕНЕР(trainer_id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL CHECK (type IN ('йога', 'кроссфит', 'пилатес', 'бокс', 'танцы', 'кардио')),
    start_time TIMESTAMP NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes BETWEEN 30 AND 180),
    max_participants INTEGER DEFAULT 20 CHECK (max_participants BETWEEN 1 AND 50),
    CHECK (start_time > CURRENT_TIMESTAMP - INTERVAL '1 day')
);

-- Таблица Записи
CREATE TABLE ЗАПИСЬ (
    booking_id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES КЛИЕНТ(client_id) ON DELETE CASCADE,
    session_id INTEGER REFERENCES ЗАНЯТИЕ(session_id) ON DELETE CASCADE,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'подтверждена' CHECK (status IN ('подтверждена', 'отменена', 'состоялась', 'неявка')),
    UNIQUE(client_id, session_id)
);

-- Таблица Тренажеры
CREATE TABLE ТРЕНАЖЕР (
    equipment_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('кардио', 'силовое')),
    status VARCHAR(20) DEFAULT 'доступен' CHECK (status IN ('доступен', 'занят', 'обслуживание')),
    last_maintenance DATE DEFAULT CURRENT_DATE
);
