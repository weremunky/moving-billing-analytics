-- Q5. Duplicate charges, e.g. a truck rental entered twice on a multi-day job.
-- Skills: GROUP BY + HAVING COUNT(*) > 1.
-- Exact duplicates: same job, cost type, amount AND date -> almost certainly double entry.
SELECT
    job_id,
    cost_type,
    cost_date,
    amount,
    COUNT(*)                       AS times_entered,
    amount * (COUNT(*) - 1)        AS overcharge_if_duplicate,
    GROUP_CONCAT(cost_id)          AS cost_ids
FROM job_costs
GROUP BY job_id, cost_type, cost_date, amount
HAVING COUNT(*) > 1
ORDER BY overcharge_if_duplicate DESC;

-- Possible duplicates to review by hand: more truck-rental entries than
-- days the crew actually worked the job. Catches double entries even when
-- the second one was typed with a different date.
WITH truck AS (
    SELECT job_id, COUNT(*) AS truck_entries, SUM(amount) AS truck_total
    FROM job_costs
    WHERE cost_type = 'truck'
    GROUP BY job_id
),
work_days AS (
    SELECT job_id, COUNT(DISTINCT work_date) AS days_worked
    FROM crew_hours
    GROUP BY job_id
)
SELECT
    j.job_id,
    j.job_type,
    w.days_worked,
    t.truck_entries,
    t.truck_total
FROM truck t
JOIN jobs j      ON j.job_id = t.job_id
JOIN work_days w ON w.job_id = t.job_id
WHERE t.truck_entries > w.days_worked
ORDER BY t.truck_entries - w.days_worked DESC, j.job_id;
