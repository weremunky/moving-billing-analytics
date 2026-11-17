-- Q10. Unpaid jobs by age (0-30, 31-60, 60+). ONLY meaningful if payments
-- are tracked in the payments table; otherwise skip this question.
-- Skills: CTE, CASE, LEFT JOIN.
WITH paid AS (
    SELECT job_id, SUM(amount) AS paid_amount
    FROM payments
    GROUP BY job_id
),
open_items AS (
    SELECT
        j.job_id,
        j.client_id,
        j.job_date,
        j.amount_billed,
        COALESCE(p.paid_amount, 0)                       AS paid_amount,
        j.amount_billed - COALESCE(p.paid_amount, 0)     AS balance,
        CAST(julianday('now') - julianday(j.job_date) AS INTEGER) AS age_days
    FROM jobs j
    LEFT JOIN paid p ON p.job_id = j.job_id
    WHERE j.status IN ('completed', 'billed', 'paid')
)
SELECT
    CASE WHEN age_days <= 30 THEN '1. 0-30 days'
         WHEN age_days <= 60 THEN '2. 31-60 days'
         ELSE                     '3. 60+ days' END AS age_bucket,
    COUNT(*)                                        AS open_jobs,
    ROUND(SUM(balance), 2)                          AS amount_outstanding
FROM open_items
WHERE balance > 0.01
GROUP BY age_bucket
ORDER BY age_bucket;
