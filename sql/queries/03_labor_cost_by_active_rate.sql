-- Q3. Labor cost per job using the pay rate active on that date.
-- Skills: JOIN on a date range. A raise mid-month changes the cost of
-- later shifts only, which a single "current rate" column gets wrong.
WITH hours_with_rate AS (
    SELECT
        ch.job_id,
        ch.employee_id,
        ch.work_date,
        ch.hours,
        pr.rate,
        ch.hours * pr.rate AS shift_cost
    FROM crew_hours ch
    LEFT JOIN pay_rates pr
      ON pr.employee_id = ch.employee_id
     AND ch.work_date >= pr.start_date
     AND (pr.end_date IS NULL OR ch.work_date <= pr.end_date)
)
SELECT
    j.job_id,
    j.job_date,
    j.job_type,
    ROUND(SUM(h.hours), 1)                         AS crew_hours,
    ROUND(SUM(h.shift_cost), 2)                    AS labor_cost,
    ROUND(SUM(h.shift_cost) / SUM(h.hours), 2)     AS blended_rate,
    SUM(CASE WHEN h.rate IS NULL THEN 1 ELSE 0 END) AS shifts_missing_rate  -- should be 0
FROM jobs j
JOIN hours_with_rate h ON h.job_id = j.job_id
GROUP BY j.job_id, j.job_date, j.job_type
ORDER BY j.job_date, j.job_id;
