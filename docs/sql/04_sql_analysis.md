
После создания базы данных и проверки бизнес-правил посмотрим, какую информацию можно получить из данных фитнес-клуба с помощью SQL.

## Сколько клиентов имеют активные абонементы?

```sql
SELECT COUNT(*) AS active_memberships
FROM membership
WHERE status = 'активен';
```

### Результат

| active_memberships |
| -----------------: |
|                  7 |


---

##  Какие типы абонементов наиболее востребованы?

```sql
SELECT
    type,
    COUNT(*) AS membership_count
FROM membership
WHERE status = 'активен'
GROUP BY type
ORDER BY membership_count DESC;
```

### Результат

| type     | membership_count |
| -------- | ---------------: |
| годовой  |                3 |
| месячный |                2 |
| разовый  |                2 |


---

## Какие занятия пользуются наибольшим спросом?

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

### Результат

| type                   | bookings_count |
| ---------------------- | -------------: |
| Функциональный тренинг |              3 |
| Йога                   |              2 |
| Пилатес                |              1 |
| Силовая тренировка     |              1 |



---

## Насколько заполнены занятия?

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

### Результат

| session_id | type                   | max_participants | confirmed_bookings | occupancy_percent |
| ---------: | ---------------------- | ---------------: | -----------------: | ----------------: |
|          1 | Функциональный тренинг |                8 |                  2 |             25.00 |
|          3 | Силовая тренировка     |                6 |                  1 |             16.67 |
|          4 | Пилатес                |                8 |                  1 |             12.50 |
|          5 | Функциональный тренинг |                8 |                  1 |             12.50 |
|          2 | Йога                   |               10 |                  1 |             10.00 |
|          6 | Йога                   |               10 |                  1 |             10.00 |
|          7 | Силовая тренировка     |                6 |                  0 |              0.00 |


---

## Какие занятия заполнены менее чем наполовину?

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

### Результат

Все 7 занятий имеют заполненность менее 50%.


---

##  Как распределена нагрузка между тренерами?

Посчитаем количество занятий и их общую продолжительность для каждого тренера.

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

### Результат

| trainer_name     | sessions_count | total_duration_minutes |
| ---------------- | -------------: | ---------------------: |
| Максим Павлов    |              2 |                    180 |
| Александр Волков |              2 |                    120 |
| Елена Фёдорова   |              2 |                    120 |
| Наталья Белова   |              1 |                     60 |


---

## Какой процент клиентов посещает занятия?

Проанализируем данные о фактическом посещении.

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

### Результат

| total_records | attended | no_show | attendance_rate_percent |
| ------------: | -------: | ------: | ----------------------: |
|             5 |        4 |       1 |                   80.00 |

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

### Результат

Запрос не вернул записей.

### Вывод

На **04.09.2026** среди активных абонементов нет таких, срок действия которых заканчивается в ближайшие 7 дней.


---

## Какие клиенты чаще всего пропускают занятия?


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

### Результат

| client_id | client_name      | no_show_count |
| --------: | ---------------- | ------------: |
|         5 | Дмитрий Кузнецов |             1 |


---

## Какие занятия проводит каждый тренер?

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

### Результат

| trainer_name     | session_type           | start_time       | duration_minutes |
| ---------------- | ---------------------- | ---------------- | ---------------: |
| Александр Волков | Функциональный тренинг | 2026-09-10 10:00 |               60 |
| Александр Волков | Функциональный тренинг | 2026-09-10 15:30 |               60 |
| Елена Фёдорова   | Йога                   | 2026-09-10 11:30 |               60 |
| Елена Фёдорова   | Йога                   | 2026-09-11 10:00 |               60 |
| Максим Павлов    | Силовая тренировка     | 2026-09-10 12:00 |               90 |
| Максим Павлов    | Силовая тренировка     | 2026-09-11 12:00 |               90 |
| Наталья Белова   | Пилатес                | 2026-09-10 14:00 |               60 |


---

## Какие занятия имеют максимальную и минимальную заполняемость?


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

### Результат

| session_id | type                   | confirmed_bookings | occupancy_percent | occupancy_rank |
| ---------: | ---------------------- | -----------------: | ----------------: | -------------: |
|          1 | Функциональный тренинг |                  2 |             25.00 |              1 |
|          3 | Силовая тренировка     |                  1 |             16.67 |              2 |
|          4 | Пилатес                |                  1 |             12.50 |              3 |
|          5 | Функциональный тренинг |                  1 |             12.50 |              3 |
|          2 | Йога                   |                  1 |             10.00 |              5 |
|          6 | Йога                   |                  1 |             10.00 |              5 |
|          7 | Силовая тренировка     |                  0 |              0.00 |              7 |


---


##  Какие клиенты имеют несколько записей на занятия?

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

### Результат

Запрос не вернул записей.

### Вывод

В тестовых данных нет клиентов, у которых было бы более одной подтверждённой записи.

Это связано с небольшим объёмом тестовых данных: сейчас каждый клиент имеет не более одной активной записи.

---

## Как распределяются занятия по времени суток?

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

### Результат

| time_period | sessions_count |
| ----------- | -------------: |
| День        |              4 |
| Утро        |              3 |


---

##  Какие типы занятий имеют наибольшую среднюю заполняемость?


```sql
WITH session_occupancy AS (
    SELECT
        s.session_id,
        s.type,
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
        s.max_participants
)
SELECT
    type,
    ROUND(AVG(occupancy_percent), 2) AS average_occupancy_percent
FROM session_occupancy
GROUP BY type
ORDER BY average_occupancy_percent DESC;
```

### Результат

| type                   | average_occupancy_percent |
| ---------------------- | ------------------------: |
| Функциональный тренинг |                     18.75 |
| Пилатес                |                     12.50 |
| Йога                   |                     10.00 |
| Силовая тренировка     |                      8.33 |







