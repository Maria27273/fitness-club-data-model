
--  Таблица клиентов

CREATE TABLE client (
client_id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
phone VARCHAR(20) UNIQUE,
email VARCHAR(100) UNIQUE,
birth_date DATE NOT NULL,
registration_date DATE NOT NULL DEFAULT CURRENT_DATE
);

--  Таблица тренеров

CREATE TABLE trainer (
trainer_id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
specialization VARCHAR(50) NOT NULL,
experience_years INTEGER NOT NULL CHECK (experience_years >= 0)
);

-- Таблица занятий

CREATE TABLE session (
session_id SERIAL PRIMARY KEY,
trainer_id INTEGER NOT NULL,
type VARCHAR(50) NOT NULL,
start_time TIMESTAMP NOT NULL,
duration_minutes INTEGER NOT NULL
CHECK (duration_minutes BETWEEN 30 AND 180),
max_participants INTEGER NOT NULL
CHECK (max_participants BETWEEN 1 AND 50),

```
CONSTRAINT fk_session_trainer
    FOREIGN KEY (trainer_id)
    REFERENCES trainer(trainer_id)
    ON DELETE RESTRICT
```

);

-- Таблица абонементов

CREATE TABLE membership (
membership_id SERIAL PRIMARY KEY,
client_id INTEGER NOT NULL,
type VARCHAR(20) NOT NULL
CHECK (type IN ('разовый', 'месячный', 'годовой')),
start_date DATE NOT NULL,
end_date DATE NOT NULL,
status VARCHAR(20) NOT NULL
CHECK (status IN ('активен', 'закончен', 'заблокирован')),
visits_remaining INTEGER,

```
CONSTRAINT fk_membership_client
    FOREIGN KEY (client_id)
    REFERENCES client(client_id)
    ON DELETE RESTRICT,

CONSTRAINT chk_membership_dates
    CHECK (end_date >= start_date),

CONSTRAINT chk_membership_visits
    CHECK (
        (type = 'разовый' AND visits_remaining IN (0, 1))
        OR
        (type IN ('месячный', 'годовой') AND visits_remaining IS NULL)
    )
```

);

-- Таблица записей на занятия


CREATE TABLE booking (
booking_id SERIAL PRIMARY KEY,
client_id INTEGER NOT NULL,
session_id INTEGER NOT NULL,
booking_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
status VARCHAR(20) NOT NULL
CHECK (status IN ('подтверждена', 'отменена')),

```
CONSTRAINT fk_booking_client
    FOREIGN KEY (client_id)
    REFERENCES client(client_id)
    ON DELETE RESTRICT,

CONSTRAINT fk_booking_session
    FOREIGN KEY (session_id)
    REFERENCES session(session_id)
    ON DELETE RESTRICT
```

);


-- Таблица посещений

CREATE TABLE attendance (
attendance_id SERIAL PRIMARY KEY,
booking_id INTEGER NOT NULL UNIQUE,
attendance_status VARCHAR(20) NOT NULL
CHECK (attendance_status IN ('посетил', 'неявка')),
attendance_time TIMESTAMP,

```
CONSTRAINT fk_attendance_booking
    FOREIGN KEY (booking_id)
    REFERENCES booking(booking_id)
    ON DELETE RESTRICT
```

);


-- Таблица тренажёров

CREATE TABLE equipment (
equipment_id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
type VARCHAR(20) NOT NULL
CHECK (type IN ('кардио', 'силовое')),
status VARCHAR(20) NOT NULL
CHECK (status IN ('доступен', 'занят', 'обслуживание')),
last_maintenance DATE NOT NULL DEFAULT CURRENT_DATE
);


-- 8. Индексы

-- У клиента может быть только один активный абонемент
CREATE UNIQUE INDEX ux_membership_one_active
ON membership(client_id)
WHERE status = 'активен';

-- У клиента может быть только одна активная запись на конкретное занятие
CREATE UNIQUE INDEX ux_booking_one_active
ON booking(client_id, session_id)
WHERE status = 'подтверждена';

-- Индекс для ускорения поиска записей клиента
CREATE INDEX idx_booking_client
ON booking(client_id);

-- Индекс для ускорения поиска участников занятия
CREATE INDEX idx_booking_session
ON booking(session_id);

-- Индекс для поиска занятий тренера
CREATE INDEX idx_session_trainer
ON session(trainer_id);

-- Индекс для поиска абонементов клиента
CREATE INDEX idx_membership_client
ON membership(client_id);

-- Индекс для работы с датами занятий
CREATE INDEX idx_session_start_time
ON session(start_time);

