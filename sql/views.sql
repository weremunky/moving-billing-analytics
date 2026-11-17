-- =====================================================================
-- Reusable views for the monthly report and the Tableau export
-- =====================================================================

-- Labor cost per job, using the pay rate active on each work date.
DROP VIEW IF EXISTS v_job_labor;
CREATE VIEW v_job_labor AS
SELECT
    ch.job_id,
    SUM(ch.hours)           AS crew_hours,
    SUM(ch.hours * pr.rate) AS labor_cost
FROM crew_hours ch
JOIN pay_rates pr
  ON pr.employee_id = ch.employee_id
 AND ch.work_date >= pr.start_date
 AND (pr.end_date IS NULL OR ch.work_date <= pr.end_date)
GROUP BY ch.job_id;

-- Non-labor costs per job (truck, equipment, materials).
DROP VIEW IF EXISTS v_job_other_costs;
CREATE VIEW v_job_other_costs AS
SELECT
    job_id,
    SUM(amount)                                            AS other_costs,
    SUM(CASE WHEN cost_type = 'truck'     THEN amount ELSE 0 END) AS truck_cost,
    SUM(CASE WHEN cost_type = 'equipment' THEN amount ELSE 0 END) AS equipment_cost,
    SUM(CASE WHEN cost_type = 'materials' THEN amount ELSE 0 END) AS materials_cost
FROM job_costs
GROUP BY job_id;

-- One row per (non-cancelled) job with revenue, costs and margin.
-- Labor and other costs are aggregated in separate views first,
-- so joining them never multiplies rows (no fan-out).
DROP VIEW IF EXISTS v_job_financials;
CREATE VIEW v_job_financials AS
SELECT
    j.job_id,
    j.client_id,
    c.client_type,
    j.job_date,
    strftime('%Y-%m', j.job_date)                   AS month,
    j.job_type,
    j.status,
    j.amount_billed                                 AS revenue,
    COALESCE(l.crew_hours, 0)                       AS crew_hours,
    CASE WHEN l.job_id IS NULL THEN 1 ELSE 0 END    AS missing_hours_flag, -- margin overstated
    COALESCE(l.labor_cost, 0)                       AS labor_cost,
    COALESCE(o.other_costs, 0)                      AS other_costs,
    j.amount_billed - COALESCE(l.labor_cost, 0)
                    - COALESCE(o.other_costs, 0)    AS margin,
    CASE WHEN l.crew_hours > 0
         THEN (j.amount_billed - COALESCE(l.labor_cost, 0) - COALESCE(o.other_costs, 0))
              / l.crew_hours END                    AS margin_per_crew_hour
FROM jobs j
JOIN clients c                ON c.client_id = j.client_id
LEFT JOIN v_job_labor l       ON l.job_id = j.job_id
LEFT JOIN v_job_other_costs o ON o.job_id = j.job_id
WHERE j.status <> 'cancelled';

-- Monthly report: the numbers the owner sees each month.
DROP VIEW IF EXISTS v_monthly_report;
CREATE VIEW v_monthly_report AS
SELECT
    month,
    COUNT(*)                                     AS jobs,
    ROUND(SUM(revenue), 2)                       AS revenue,
    ROUND(SUM(labor_cost), 2)                    AS labor_cost,
    ROUND(SUM(other_costs), 2)                   AS other_costs,
    ROUND(SUM(margin), 2)                        AS margin,
    ROUND(100.0 * SUM(margin) / NULLIF(SUM(revenue), 0), 1) AS margin_pct,
    ROUND(SUM(crew_hours), 1)                    AS crew_hours,
    ROUND(SUM(margin) / NULLIF(SUM(crew_hours), 0), 2)      AS margin_per_crew_hour
FROM v_job_financials
GROUP BY month;

-- Monthly report split by job type.
DROP VIEW IF EXISTS v_monthly_by_job_type;
CREATE VIEW v_monthly_by_job_type AS
SELECT
    month,
    job_type,
    COUNT(*)                                     AS jobs,
    ROUND(SUM(revenue), 2)                       AS revenue,
    ROUND(SUM(margin), 2)                        AS margin,
    ROUND(100.0 * SUM(margin) / NULLIF(SUM(revenue), 0), 1) AS margin_pct
FROM v_job_financials
GROUP BY month, job_type;
