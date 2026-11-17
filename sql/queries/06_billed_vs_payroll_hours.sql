-- Q6. Billed hours vs. payroll hours mismatches.
-- Skills: CTE + comparison. billed_hours = crew-hours on the invoice.
-- Positive diff = billed more than paid out; negative = unbilled labor.
WITH payroll AS (
    SELECT job_id, SUM(hours) AS payroll_hours
    FROM crew_hours
    GROUP BY job_id
)
SELECT
    j.job_id,
    j.job_date,
    j.job_type,
    j.billed_hours,
    p.payroll_hours,
    ROUND(j.billed_hours - p.payroll_hours, 2) AS diff_hours,
    CASE WHEN j.billed_hours < p.payroll_hours THEN 'under-billed'
         ELSE 'over-billed' END                AS direction
FROM jobs j
JOIN payroll p ON p.job_id = j.job_id
WHERE j.billed_hours IS NOT NULL
  AND j.status <> 'cancelled'
  AND ABS(j.billed_hours - p.payroll_hours) > 0.5   -- tolerance: half an hour
ORDER BY ABS(j.billed_hours - p.payroll_hours) DESC;
