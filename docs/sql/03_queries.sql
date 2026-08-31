-- Запрос 1. Клиенты с активными абонементами
SELECT
    k.client_id,
    k.name AS "Имя клиента",
    k.phone AS "Телефон",
    a.type AS "Тип абонемента",
    a.start_date AS "Начало действия",
    a.end_date AS "Окончание действия",
    a.status AS "Статус"
FROM КЛИЕНТ k
JOIN АБОНЕМЕНТ a ON k.client_id = a.client_id
WHERE a.status = 'активен'
    AND a.start_date <= '2024-12-31'
    AND (a.end_date IS NULL OR a.end_date >= '2024-02-20')
ORDER BY a.end_date;

-- Запрос 2. Расписание занятий на ближайшие 3 дня
SELECT
    z.session_id AS "ID занятия",
    z.type AS "Тип занятия",
    t.name AS "Тренер",
    z.start_time AS "Время начала",
    z.duration_minutes AS "Длительность (мин)",
    z.max_participants AS "Макс. участников",
    COUNT(b.booking_id) AS "Уже записано",
    (z.max_participants - COUNT(b.booking_id)) AS "Свободных мест"
FROM ЗАНЯТИЕ z
JOIN ТРЕНЕР t ON z.trainer_id = t.trainer_id
LEFT JOIN ЗАПИСЬ b ON z.session_id = b.session_id AND b.status = 'подтверждена'
WHERE z.start_time BETWEEN '2024-02-20' AND '2024-02-24'
GROUP BY z.session_id, t.name, z.type, z.start_time, z.duration_minutes, z.max_participants
ORDER BY z.start_time;

-- Запрос 3. Клиенты, записанные на сегодняшние занятия
SELECT
    k.name AS "Клиент",
    k.phone AS "Телефон",
    z.type AS "Занятие",
    t.name AS "Тренер",
    z.start_time AS "Время",
    b.booking_date AS "Дата записи",
    b.status AS "Статус записи"
FROM ЗАПИСЬ b
JOIN КЛИЕНТ k ON b.client_id = k.client_id
JOIN ЗАНЯТИЕ z ON b.session_id = z.session_id
JOIN ТРЕНЕР t ON z.trainer_id = t.trainer_id
WHERE DATE(z.start_time) = '2024-02-20'
    AND b.status = 'подтверждена'
ORDER BY z.start_time;

-- Запрос 4. Самые популярные типы занятий
SELECT
    z.type AS "Тип занятия",
    COUNT(b.booking_id) AS "Количество записей",
    COUNT(DISTINCT b.client_id) AS "Уникальных клиентов",
    ROUND(AVG(z.duration_minutes), 0) AS "Средняя длительность",
    MIN(z.start_time) AS "Первое занятие",
    MAX(z.start_time) AS "Последнее занятие"
FROM ЗАНЯТИЕ z
LEFT JOIN ЗАПИСЬ b ON z.session_id = b.session_id AND b.status = 'подтверждена'
GROUP BY z.type
ORDER BY COUNT(b.booking_id) DESC;

-- Запрос 5. Нагрузка на тренеров
SELECT
    t.name AS "Тренер",
    t.specialization AS "Специализация",
    t.experience_years AS "Стаж (лет)",
    COUNT(z.session_id) AS "Всего занятий",
    COUNT(DISTINCT z.type) AS "Разных типов занятий",
    SUM(CASE WHEN z.start_time < '2024-12-31' THEN 1 ELSE 0 END) AS "Проведено",
    SUM(CASE WHEN z.start_time >= '2024-12-31' THEN 1 ELSE 0 END) AS "Запланировано"
FROM ТРЕНЕР t
LEFT JOIN ЗАНЯТИЕ z ON t.trainer_id = z.trainer_id
GROUP BY t.trainer_id, t.name, t.specialization, t.experience_years
ORDER BY COUNT(z.session_id) DESC;
