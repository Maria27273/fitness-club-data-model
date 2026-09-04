
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


# Реализация бизнес-правил


## Автоматическое завершение абонемента

```sql
CREATE OR REPLACE FUNCTION update_expired_memberships()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE membership
    SET status = 'закончен'
    WHERE status = 'активен'
      AND end_date < CURRENT_DATE;

    GET DIAGNOSTICS updated_count = ROW_COUNT;

    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;
```

Функция переводит в статус `закончен` все активные абонементы, срок действия которых уже истек

Функция должна запускаться регулярно

---

## Завершение разового абонемента после посещения

```sql
CREATE OR REPLACE FUNCTION process_attendance()
RETURNS TRIGGER AS $$
DECLARE
    membership_id_value INTEGER;
BEGIN
    IF NEW.attendance_status = 'посетил' THEN

        SELECT m.membership_id
        INTO membership_id_value
        FROM membership m
        JOIN booking b
            ON b.client_id = m.client_id
        WHERE b.booking_id = NEW.booking_id
          AND m.type = 'разовый'
          AND m.status = 'активен'
          AND m.visits_remaining = 1
          AND b.status = 'подтверждена'
        LIMIT 1;

        IF membership_id_value IS NOT NULL THEN

            UPDATE membership
            SET visits_remaining = 0,
                status = 'закончен'
            WHERE membership_id = membership_id_value;

        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_process_attendance
AFTER INSERT OR UPDATE ON attendance
FOR EACH ROW
EXECUTE FUNCTION process_attendance();
```

При добавлении посещения со статусом `посетил` система:

1. находит запись клиента на занятие
2. проверяет наличие активного разового абонемента
3. проверяет, что у абонемента осталось одно посещение
4. уменьшает количество оставшихся посещений до `0`
5. переводит абонемент в статус `закончен`

---

## Запись на занятие только при наличии действующего абонемента

```sql
CREATE OR REPLACE FUNCTION check_active_membership()
RETURNS TRIGGER AS $$
DECLARE
    session_date DATE;
    membership_exists BOOLEAN;
BEGIN
    IF NEW.status = 'подтверждена' THEN

        SELECT start_time::DATE
        INTO session_date
        FROM session
        WHERE session_id = NEW.session_id;

        SELECT EXISTS (
            SELECT 1
            FROM membership
            WHERE client_id = NEW.client_id
              AND status = 'активен'
              AND start_date <= session_date
              AND end_date >= session_date
              AND (
                  type IN ('месячный', 'годовой')
                  OR
                  (type = 'разовый' AND visits_remaining > 0)
              )
        )
        INTO membership_exists;

        IF NOT membership_exists THEN
            RAISE EXCEPTION
                'Невозможно создать запись: у клиента нет действующего абонемента';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_active_membership
BEFORE INSERT OR UPDATE ON booking
FOR EACH ROW
EXECUTE FUNCTION check_active_membership();
```

Если подходящего абонемента нет, операция создания подтвержденной записи завершается ошибкой.

---

## Количество подтвержденных записей не может превышать вместимость занятия

```sql
CREATE OR REPLACE FUNCTION check_session_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_count INTEGER;
    session_capacity INTEGER;
BEGIN
    IF NEW.status = 'подтверждена' THEN

        SELECT max_participants
        INTO session_capacity
        FROM session
        WHERE session_id = NEW.session_id;

        SELECT COUNT(*)
        INTO current_count
        FROM booking
        WHERE session_id = NEW.session_id
          AND status = 'подтверждена';

        IF current_count >= session_capacity THEN
            RAISE EXCEPTION
                'Невозможно записать клиента: достигнута максимальная вместимость занятия';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_session_capacity
BEFORE INSERT OR UPDATE ON booking
FOR EACH ROW
EXECUTE FUNCTION check_session_capacity();
```

Перед созданием подтвержденной записи система получает максимальную вместимость занятия и подсчитывает количество уже подтвержденных записей.

Если лимит достигнут, новая запись не создается

---

## Клиент не может быть записан на пересекающиеся занятия

```sql
CREATE OR REPLACE FUNCTION check_client_session_overlap()
RETURNS TRIGGER AS $$
DECLARE
    new_start TIMESTAMP;
    new_end TIMESTAMP;
    overlap_exists BOOLEAN;
BEGIN
    IF NEW.status = 'подтверждена' THEN

        SELECT
            start_time,
            start_time + duration_minutes * INTERVAL '1 minute'
        INTO new_start, new_end
        FROM session
        WHERE session_id = NEW.session_id;

        SELECT EXISTS (
            SELECT 1
            FROM booking b
            JOIN session s
                ON s.session_id = b.session_id
            WHERE b.client_id = NEW.client_id
              AND b.status = 'подтверждена'
              AND b.booking_id <> NEW.booking_id
              AND s.start_time < new_end
              AND s.start_time + s.duration_minutes * INTERVAL '1 minute'
                    > new_start
        )
        INTO overlap_exists;

        IF overlap_exists THEN
            RAISE EXCEPTION
                'Невозможно записать клиента: время занятия пересекается с другой записью клиента';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_client_session_overlap
BEFORE INSERT OR UPDATE ON booking
FOR EACH ROW
EXECUTE FUNCTION check_client_session_overlap();
```

Перед подтверждением записи система проверяет все остальные активные записи клиента.

Если временные интервалы пересекаются, операция отклоняется.

---


##  Ограничение возраста клиента

```sql
CREATE OR REPLACE FUNCTION check_client_age()
RETURNS TRIGGER AS $$
DECLARE
    client_birth_date DATE;
    client_age INTEGER;
BEGIN
    IF NEW.status = 'подтверждена' THEN

        SELECT birth_date
        INTO client_birth_date
        FROM client
        WHERE client_id = NEW.client_id;

        client_age :=
            EXTRACT(YEAR FROM AGE(CURRENT_DATE, client_birth_date));

        IF client_age <= 14 THEN
            RAISE EXCEPTION
                'Невозможно создать запись: клиент должен быть старше 14 лет';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_check_client_age
BEFORE INSERT OR UPDATE ON booking
FOR EACH ROW
EXECUTE FUNCTION check_client_age();
```

При создании подтвержденной записи возраст клиента рассчитывается по дате рождения

Если клиенту 14 лет или меньше, запись отклоняется

---

## Нельзя удалить клиента при наличии будущих записей

```sql
CREATE OR REPLACE FUNCTION prevent_client_deletion()
RETURNS TRIGGER AS $$
DECLARE
    future_bookings INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO future_bookings
    FROM booking b
    JOIN session s
        ON s.session_id = b.session_id
    WHERE b.client_id = OLD.client_id
      AND b.status = 'подтверждена'
      AND s.start_time > CURRENT_TIMESTAMP;

    IF future_bookings > 0 THEN
        RAISE EXCEPTION
            'Невозможно удалить клиента: существуют будущие подтвержденные записи';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_prevent_client_deletion
BEFORE DELETE ON client
FOR EACH ROW
EXECUTE FUNCTION prevent_client_deletion();
```

Если у клиента есть будущие подтвержденные занятия, удаление запрещается

При этом история завершенных занятий не используется как причина для запрета

---

## Нельзя удалить тренера при наличии запланированных занятий

```sql
CREATE OR REPLACE FUNCTION prevent_trainer_deletion()
RETURNS TRIGGER AS $$
DECLARE
    future_sessions INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO future_sessions
    FROM session
    WHERE trainer_id = OLD.trainer_id
      AND start_time > CURRENT_TIMESTAMP;

    IF future_sessions > 0 THEN
        RAISE EXCEPTION
            'Невозможно удалить тренера: существуют запланированные занятия';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_prevent_trainer_deletion
BEFORE DELETE ON trainer
FOR EACH ROW
EXECUTE FUNCTION prevent_trainer_deletion();
```

Удаление тренера блокируется, если за ним закреплены будущие занятия.

Завершенные занятия при этом сохраняются в истории.

---

```sql
CREATE OR REPLACE FUNCTION prevent_session_deletion()
RETURNS TRIGGER AS $$
DECLARE
    confirmed_bookings INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO confirmed_bookings
    FROM booking
    WHERE session_id = OLD.session_id
      AND status = 'подтверждена';

    IF confirmed_bookings > 0 THEN
        RAISE EXCEPTION
            'Невозможно удалить занятие: существуют подтвержденные записи';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_prevent_session_deletion
BEFORE DELETE ON session
FOR EACH ROW
EXECUTE FUNCTION prevent_session_deletion();
```


