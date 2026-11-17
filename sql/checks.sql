-- =====================================================================
-- Data-quality checks. Run before each billing cycle.
-- Every row returned is something to fix. Zero rows = clean.
-- =====================================================================
DROP VIEW IF EXISTS v_data_quality;
CREATE VIEW v_data_quality AS

-- 1. Completed/billed jobs with no crew hours logged
SELECT 'missing_crew_hours' AS check_name, j.job_id,
       'status=' || j.status || ', billed $' || j.amount_billed AS detail,
       j.amount_billed AS amount_at_risk
FROM jobs j
LEFT JOIN crew_hours ch ON ch.job_id = j.job_id
WHERE ch.job_id IS NULL
  AND j.status IN ('completed', 'billed', 'paid')

UNION ALL
-- 2. Exact duplicate cost entries (same job, type, date, amount)
SELECT 'duplicate_cost', job_id,
       cost_type || ' $' || amount || ' on ' || COALESCE(cost_date, '?')
           || ' entered ' || COUNT(*) || 'x',
       amount * (COUNT(*) - 1)
FROM job_costs
GROUP BY job_id, cost_type, cost_date, amount
HAVING COUNT(*) > 1

UNION ALL
-- 3. Duplicate crew-hour rows (same person, job, day)
SELECT 'duplicate_hours', job_id,
       employee_id || ' on ' || work_date || ' entered ' || COUNT(*) || 'x',
       NULL
FROM crew_hours
GROUP BY job_id, employee_id, work_date
HAVING COUNT(*) > 1

UNION ALL
-- 4. Billed hours differ from payroll hours by more than 0.5
SELECT 'billed_vs_payroll_mismatch', j.job_id,
       'billed ' || j.billed_hours || ' hrs vs payroll ' || p.payroll_hours || ' hrs',
       NULL
FROM jobs j
JOIN (SELECT job_id, SUM(hours) AS payroll_hours FROM crew_hours GROUP BY job_id) p
  ON p.job_id = j.job_id
WHERE j.billed_hours IS NOT NULL
  AND j.status <> 'cancelled'
  AND ABS(j.billed_hours - p.payroll_hours) > 0.5

UNION ALL
-- 5. Hours logged with no pay rate active that day (labor cost would be missing)
SELECT 'no_active_pay_rate', ch.job_id,
       ch.employee_id || ' on ' || ch.work_date, NULL
FROM crew_hours ch
LEFT JOIN pay_rates pr
  ON pr.employee_id = ch.employee_id
 AND ch.work_date >= pr.start_date
 AND (pr.end_date IS NULL OR ch.work_date <= pr.end_date)
WHERE pr.employee_id IS NULL

UNION ALL
-- 6. Hours logged before the job started (likely wrong job_id or date)
SELECT 'hours_before_job_date', ch.job_id,
       ch.employee_id || ' logged ' || ch.work_date || ', job starts ' || j.job_date, NULL
FROM crew_hours ch
JOIN jobs j ON j.job_id = ch.job_id
WHERE ch.work_date < j.job_date

UNION ALL
-- 7. Overlapping pay-rate periods for the same employee
SELECT 'overlapping_pay_rates', NULL,
       a.employee_id || ': ' || a.start_date || ' overlaps ' || b.start_date, NULL
FROM pay_rates a
JOIN pay_rates b
  ON a.employee_id = b.employee_id
 AND a.start_date < b.start_date
 AND (a.end_date IS NULL OR a.end_date >= b.start_date)

UNION ALL
-- 8. Cancelled jobs that still have hours or costs attached
SELECT 'cancelled_job_with_activity', j.job_id, 'cancelled but has hours/costs', NULL
FROM jobs j
WHERE j.status = 'cancelled'
  AND (EXISTS (SELECT 1 FROM crew_hours ch WHERE ch.job_id = j.job_id)
    OR EXISTS (SELECT 1 FROM job_costs jc WHERE jc.job_id = j.job_id));

-- Summary
SELECT check_name, COUNT(*) AS issues, ROUND(SUM(amount_at_risk), 2) AS dollars_flagged
FROM v_data_quality
GROUP BY check_name
ORDER BY issues DESC;
