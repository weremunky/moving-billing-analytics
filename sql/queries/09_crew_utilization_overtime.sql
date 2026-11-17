-- Q9. Crew utilization and overtime by week.
-- Skills: window functions (SUM OVER with PARTITION BY), CTEs.
-- California rule: overtime after 8 hrs in a day OR 40 hrs in a week.
-- (Simplified: ignores double-time and the 7th-consecutive-day rule.)
WITH daily AS (
    SELECT
        employee_id,
        work_date,
        strftime('%Y-W%W', work_date) AS week,
        SUM(hours)                    AS day_hours
    FROM crew_hours
    GROUP BY employee_id, work_date
),
daily_with_ot AS (
    SELECT *, MAX(day_hours - 8, 0) AS daily_ot
    FROM daily
),
weekly AS (
    SELECT
        employee_id,
        week,
        SUM(day_hours) AS week_hours,
        SUM(daily_ot)  AS daily_ot_hours,
        COUNT(*)       AS days_worked
    FROM daily_with_ot
    GROUP BY employee_id, week
)
SELECT
    week,
    employee_id,
    days_worked,
    ROUND(week_hours, 1)                                   AS week_hours,
    ROUND(100.0 * week_hours / 40, 0)                      AS utilization_pct_of_40,
    ROUND(MAX(daily_ot_hours, week_hours - 40, 0), 1)      AS est_ot_hours,
    ROUND(100.0 * week_hours / SUM(week_hours) OVER (PARTITION BY week), 1) AS pct_of_crew_hours
FROM weekly
ORDER BY week, week_hours DESC;
-- est_ot_hours takes the larger of daily OT and weekly OT, a conservative
-- estimate that avoids double-counting the same hours. Confirm with payroll.
