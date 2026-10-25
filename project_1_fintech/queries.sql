
-- ============================================================
-- SQL-анализ кредитных выдач в Астане за 2023–2026 годы
-- Проект Data Analytics
-- СУБД: MariaDB / MySQL
-- База данных: astana_credit_analysis
-- Таблица: credit_issuances
-- ============================================================

-- 1. ОБЩАЯ ИНФОРМАЦИЯ О ДАННЫХ

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT `Клиент_ID`) AS unique_customers,
    COUNT(DISTINCT `Менеджер_ID`) AS unique_managers,
    COUNT(DISTINCT `Продукт`) AS product_count,
    MIN(`Дата_выдачи`) AS first_issuance_date,
    MAX(`Дата_выдачи`) AS last_issuance_date,
    SUM(`Сумма_выдачи_KZT`) AS total_issuance_amount
FROM credit_issuances;


-- 2. ДИНАМИКА ВЫДАЧ ПО ГОДАМ

SELECT
    `Год` AS year,
    COUNT(*) AS issuance_count,
    SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt,
    COUNT(DISTINCT `Клиент_ID`) AS unique_customers
FROM credit_issuances
GROUP BY `Год`
ORDER BY `Год`;


-- 3. СРАВНЕНИЕ СОПОСТАВИМЫХ ПЕРИОДОВ: ЯНВАРЬ–СЕНТЯБРЬ

WITH period_summary AS (
    SELECT
        `Год` AS year,
        COUNT(*) AS issuance_count,
        SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt
    FROM credit_issuances
    WHERE `Месяц_номер` BETWEEN 1 AND 9
    GROUP BY `Год`
),
period_changes AS (
    SELECT
        year,
        issuance_count,
        total_amount_kzt,
        LAG(total_amount_kzt) OVER (ORDER BY year) AS previous_amount,
        LAG(issuance_count) OVER (ORDER BY year) AS previous_count
    FROM period_summary
)
SELECT
    year,
    issuance_count,
    total_amount_kzt,
    ROUND(
        100.0 * (total_amount_kzt - previous_amount)
        / NULLIF(previous_amount, 0), 2
    ) AS amount_change_pct,
    ROUND(
        100.0 * (issuance_count - previous_count)
        / NULLIF(previous_count, 0), 2
    ) AS count_change_pct
FROM period_changes
ORDER BY year;


-- 4. ЕЖЕМЕСЯЧНАЯ ДИНАМИКА

SELECT
    DATE_FORMAT(`Дата_выдачи`, '%Y-%m') AS issuance_month,
    COUNT(*) AS issuance_count,
    SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt
FROM credit_issuances
GROUP BY DATE_FORMAT(`Дата_выдачи`, '%Y-%m')
ORDER BY issuance_month;


-- 5. СРАВНЕНИЕ КРЕДИТНЫХ ПРОДУКТОВ

SELECT
    `Продукт` AS product,
    COUNT(*) AS issuance_count,
    SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt,
    COUNT(DISTINCT `Клиент_ID`) AS unique_customers,
    ROUND(
        100.0 * SUM(`Сумма_выдачи_KZT`)
        / (SELECT SUM(`Сумма_выдачи_KZT`) FROM credit_issuances),
        2
    ) AS amount_share_pct,
    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM credit_issuances),
        2
    ) AS issuance_share_pct
FROM credit_issuances
GROUP BY `Продукт`
ORDER BY total_amount_kzt DESC;


-- 6. КЛИЕНТСКАЯ АКТИВНОСТЬ И ПОВТОРНЫЕ ВЫДАЧИ

SELECT
    COUNT(*) AS unique_customers,
    SUM(CASE WHEN issuance_count = 1 THEN 1 ELSE 0 END)
        AS single_issuance_customers,
    SUM(CASE WHEN issuance_count > 1 THEN 1 ELSE 0 END)
        AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN issuance_count > 1 THEN 1 ELSE 0 END)
        / COUNT(*), 2
    ) AS repeat_rate_pct,
    ROUND(AVG(total_credit_amount), 2)
        AS average_credit_amount_per_customer
FROM (
    SELECT
        `Клиент_ID`,
        COUNT(*) AS issuance_count,
        SUM(`Сумма_выдачи_KZT`) AS total_credit_amount
    FROM credit_issuances
    GROUP BY `Клиент_ID`
) AS customer_summary;


-- 7. ПРОФИЛЬ КЛИЕНТОВ С ПОВТОРНЫМИ ВЫДАЧАМИ

SELECT
    `Клиент_ID` AS customer_id,
    COUNT(*) AS issuance_count,
    SUM(`Сумма_выдачи_KZT`) AS total_credit_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt,
    MIN(`Дата_выдачи`) AS first_issuance_date,
    MAX(`Дата_выдачи`) AS last_issuance_date
FROM credit_issuances
GROUP BY `Клиент_ID`
HAVING COUNT(*) > 1
ORDER BY issuance_count DESC, total_credit_amount_kzt DESC;


-- 8. ПОМЕСЯЧНАЯ СТРУКТУРА ЗА ПОЛНЫЕ ГОДЫ 2023–2025

SELECT
    `Месяц_номер` AS calendar_month,
    COUNT(*) AS total_issuances,
    SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt,
    COUNT(DISTINCT `Год`) AS years_covered
FROM credit_issuances
WHERE `Год` BETWEEN 2023 AND 2025
GROUP BY `Месяц_номер`
ORDER BY `Месяц_номер`;


-- 9. АНАЛИЗ ВЫДАЧ ПО МЕНЕДЖЕРАМ

SELECT
    `Менеджер_ID` AS manager_id,
    COUNT(*) AS issuance_count,
    COUNT(DISTINCT `Клиент_ID`) AS unique_customers,
    SUM(`Сумма_выдачи_KZT`) AS total_amount_kzt,
    ROUND(AVG(`Сумма_выдачи_KZT`), 2) AS average_issuance_kzt
FROM credit_issuances
GROUP BY `Менеджер_ID`
ORDER BY total_amount_kzt DESC;


-- 10. ПРОВЕРКА КАЧЕСТВА ДАННЫХ

SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN `Сумма_выдачи_KZT` <= 0 THEN 1 ELSE 0 END)
        AS non_positive_amounts,
    SUM(
        CASE
            WHEN `Дата_выдачи` IS NULL
              OR `Дата_выдачи` = '0000-00-00'
            THEN 1 ELSE 0
        END
    ) AS invalid_dates,
    SUM(
        CASE
            WHEN `Клиент_ID` IS NULL OR `Клиент_ID` = ''
            THEN 1 ELSE 0
        END
    ) AS missing_customer_ids,
    SUM(
        CASE
            WHEN `Менеджер_ID` IS NULL OR `Менеджер_ID` = ''
            THEN 1 ELSE 0
        END
    ) AS missing_manager_ids,
    SUM(
        CASE
            WHEN `Продукт` IS NULL OR `Продукт` = ''
            THEN 1 ELSE 0
        END
    ) AS missing_products
FROM credit_issuances;

-- ============================================================
-- Конец SQL-анализа
-- ============================================================
