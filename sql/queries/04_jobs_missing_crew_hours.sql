-- Q4. Jobs with no crew hours logged (catch before billing).
-- Skills: LEFT JOIN + IS NULL (anti-join).
SELECT
    j.job_id,
    j.job_date,
    j.job_type,
    j.status,
    j.amount_billed,
    CAST(julianday('now') - julianday(j.job_date) AS INTEGER) AS days_since_job
FROM jobs j
LEFT JOIN crew_hours ch ON ch.job_id = j.job_id
WHERE ch.job_id IS NULL
  AND j.status IN ('completed', 'billed', 'paid')
  AND j.job_date <= date('now')
ORDER BY j.job_date;
