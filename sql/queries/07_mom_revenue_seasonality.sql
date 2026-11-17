-- Q7. Month-over-month revenue change and seasonality.
-- Skills: LAG window function, date functions.
WITH monthly AS (
    SELECT
        strftime('%Y-%m', job_date) AS month,
        SUM(amount_billed)          AS revenue,
        COUNT(*)                    AS jobs
    FROM jobs
    WHERE status <> 'cancelled'
    GROUP BY month
)
SELECT
    month,
    CASE WHEN month = strftime('%Y-%m', 'now') THEN 'partial' END AS note,
    jobs,
    ROUND(revenue, 2)                                         AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2)              AS prev_month_revenue,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2)    AS mom_change,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS mom_change_pct,
    ROUND(AVG(revenue) OVER (ORDER BY month
          ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)       AS rolling_3mo_avg
FROM monthly
ORDER BY month;

-- Seasonality: day of week (moves cluster on weekends / month-end).
SELECT
    CASE strftime('%w', job_date)
        WHEN '0' THEN '0 Sun' WHEN '1' THEN '1 Mon' WHEN '2' THEN '2 Tue'
        WHEN '3' THEN '3 Wed' WHEN '4' THEN '4 Thu' WHEN '5' THEN '5 Fri'
        ELSE '6 Sat' END                        AS weekday,
    COUNT(*)                                    AS jobs,
    ROUND(AVG(amount_billed), 2)                AS avg_ticket
FROM jobs
WHERE status <> 'cancelled'
GROUP BY weekday
ORDER BY weekday;

-- Seasonality: early vs. late in the month (lease turnover).
SELECT
    CASE WHEN CAST(strftime('%d', job_date) AS INTEGER) >= 25
           OR CAST(strftime('%d', job_date) AS INTEGER) <= 2
         THEN 'month-end (25th-2nd)' ELSE 'mid-month' END AS period,
    COUNT(*)                     AS jobs,
    ROUND(SUM(amount_billed), 2) AS revenue
FROM jobs
WHERE status <> 'cancelled'
GROUP BY period;
