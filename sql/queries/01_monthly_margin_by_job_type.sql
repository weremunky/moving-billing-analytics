-- Q1. Monthly revenue, labor cost, and margin by job type.
-- Skills: CTEs, JOIN, GROUP BY. Labor and other costs are pre-aggregated
-- per job in their own CTEs so the final join can't double-count.
WITH labor AS (
    SELECT ch.job_id, SUM(ch.hours * pr.rate) AS labor_cost
    FROM crew_hours ch
    JOIN pay_rates pr
      ON pr.employee_id = ch.employee_id
     AND ch.work_date >= pr.start_date
     AND (pr.end_date IS NULL OR ch.work_date <= pr.end_date)
    GROUP BY ch.job_id
),
other AS (
    SELECT job_id, SUM(amount) AS other_costs
    FROM job_costs
    GROUP BY job_id
),
per_job AS (
    SELECT
        strftime('%Y-%m', j.job_date) AS month,
        j.job_type,
        j.amount_billed               AS revenue,
        COALESCE(l.labor_cost, 0)     AS labor_cost,
        COALESCE(o.other_costs, 0)    AS other_costs
    FROM jobs j
    LEFT JOIN labor l ON l.job_id = j.job_id
    LEFT JOIN other o ON o.job_id = j.job_id
    WHERE j.status <> 'cancelled'
)
SELECT
    month,
    job_type,
    COUNT(*)                                        AS jobs,
    ROUND(SUM(revenue), 2)                          AS revenue,
    ROUND(SUM(labor_cost), 2)                       AS labor_cost,
    ROUND(SUM(other_costs), 2)                      AS other_costs,
    ROUND(SUM(revenue - labor_cost - other_costs), 2) AS margin,
    ROUND(100.0 * SUM(revenue - labor_cost - other_costs) / NULLIF(SUM(revenue), 0), 1) AS margin_pct
FROM per_job
GROUP BY month, job_type
ORDER BY month, job_type;
