# SQL-анализ

После создания базы данных и проверки бизнес-правил посмотрим, какую информацию можно получить из данных фитнес-клуба с помощью SQL

## 1. Сколько клиентов имеют активные абонементы?

```sql
SELECT COUNT(*) AS active_memberships
FROM membership
WHERE status = 'активен';
```

---

## 2. Какие типы абонементов наиболее востребованы?


```sql
SELECT
    type,
    COUNT(*) AS membership_count
FROM membership
WHERE status = 'активен'
GROUP BY type
ORDER BY membership_count DESC;
```

---

## 3. Какие занятия пользуются наибольшим спросом?

```sql
SELECT
    s.type,
    COUNT(b.booking_id) AS bookings_count
FROM session s
LEFT JOIN booking b
    ON b.session_id = s.session_id
    AND b.status = 'подтверждена'
GROUP BY s.type
ORDER BY bookings_count DESC;
```

---

## 4. Насколько заполнены занятия?

```sql
SELECT
    s.session_id,
    s.type,
    s.start_time,
    s.max_participants,
    COUNT(b.booking_id) AS confirmed_bookings,
    ROUND(
        COUNT(b.booking_id) * 100.0 / s.max_participants,
        2
    ) AS occupancy_percent
FROM session s
LEFT JOIN booking b
    ON b.session_id = s.session_id
    AND b.status = 'подтверждена'
GROUP BY
    s.session_id,
    s.type,
    s.start_time,
    s.max_participants
ORDER BY occupancy_percent DESC;
```

---

## 5. Какие занятия заполнены менее чем наполовину?

```sql
SELECT
    s.session_id,
    s.type,
    s.start_time,
    s.max_participants,
    COUNT(b.booking_id) AS confirmed_bookings,
    ROUND(
        COUNT(b.booking_id) * 100.0 / s.max_participants,
        2
    ) AS occupancy_percent
FROM session s
LEFT JOIN booking b
    ON b.session_id = s.session_id
    AND b.status = 'подтверждена'
GROUP BY
    s.session_id,
    s.type,
    s.start_time,
    s.max_participants
HAVING COUNT(b.booking_id) * 100.0 / s.max_participants < 50
ORDER BY occupancy_percent;
```

---

## 6. Как распределена нагрузка между тренерами?

```sql
SELECT
    t.name AS trainer_name,
    COUNT(s.session_id) AS sessions_count,
    COALESCE(SUM(s.duration_minutes), 0) AS total_duration_minutes
FROM trainer t
LEFT JOIN session s
    ON s.trainer_id = t.trainer_id
GROUP BY
    t.trainer_id,
    t.name
ORDER BY sessions_count DESC;
```

---

## 7. Какой процент клиентов посещает занятия?

```sql
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (
        WHERE attendance_status = 'посетил'
    ) AS attended,
    COUNT(*) FILTER (
        WHERE attendance_status = 'неявка'
    ) AS no_show,
    ROUND(
        COUNT(*) FILTER (
            WHERE attendance_status = 'посетил'
        ) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS attendance_rate_percent
FROM attendance;
```

---

## 8. У каких клиентов скоро заканчивается абонемент?

```sql
SELECT
    c.name AS client_name,
    m.type AS membership_type,
    m.end_date
FROM client c
JOIN membership m
    ON m.client_id = c.client_id
WHERE m.status = 'активен'
  AND m.end_date BETWEEN CURRENT_DATE
                     AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY m.end_date;
```

---

## 9. Какие клиенты чаще всего пропускают занятия?

```sql
SELECT
    c.client_id,
    c.name AS client_name,
    COUNT(*) AS no_show_count
FROM client c
JOIN booking b
    ON b.client_id = c.client_id
JOIN attendance a
    ON a.booking_id = b.booking_id
WHERE a.attendance_status = 'неявка'
GROUP BY
    c.client_id,
    c.name
ORDER BY no_show_count DESC;
```

---

## 10. Какие занятия проводит каждый тренер?

```sql
SELECT
    t.name AS trainer_name,
    s.type AS session_type,
    s.start_time,
    s.duration_minutes
FROM trainer t
JOIN session s
    ON s.trainer_id = t.trainer_id
ORDER BY
    t.name,
    s.start_time;
```
## 11. Какие занятия имеют максимальную и минимальную заполняемость?


```sql
WITH session_occupancy AS (
    SELECT
        s.session_id,
        s.type,
        s.start_time,
        s.max_participants,
        COUNT(b.booking_id) AS confirmed_bookings,
        ROUND(
            COUNT(b.booking_id) * 100.0 / s.max_participants,
            2
        ) AS occupancy_percent
    FROM session s
    LEFT JOIN booking b
        ON b.session_id = s.session_id
        AND b.status = 'подтверждена'
    GROUP BY
        s.session_id,
        s.type,
        s.start_time,
        s.max_participants
)
SELECT
    session_id,
    type,
    start_time,
    confirmed_bookings,
    occupancy_percent,
    RANK() OVER (
        ORDER BY occupancy_percent DESC
    ) AS occupancy_rank
FROM session_occupancy
ORDER BY occupancy_rank;
```

---


## 14. Какие клиенты имеют несколько записей на занятия?


```sql
SELECT
    c.client_id,
    c.name AS client_name,
    COUNT(b.booking_id) AS bookings_count
FROM client c
JOIN booking b
    ON b.client_id = c.client_id
WHERE b.status = 'подтверждена'
GROUP BY
    c.client_id,
    c.name
HAVING COUNT(b.booking_id) > 1
ORDER BY bookings_count DESC;
```

---

## 15. Как распределяются занятия по времени суток?

```sql
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM start_time) < 12
            THEN 'Утро'
        WHEN EXTRACT(HOUR FROM start_time) < 18
            THEN 'День'
        ELSE 'Вечер'
    END AS time_period,
    COUNT(*) AS sessions_count
FROM session
GROUP BY time_period
ORDER BY sessions_count DESC;
```

---

