-- Q8. Top clients and repeat customers.
-- Skills: RANK window function, COUNT, CTE.
WITH client_totals AS (
    SELECT
        c.client_id,
        c.client_type,
        COUNT(*)            AS jobs,
        SUM(f.revenue)      AS revenue,
        SUM(f.margin)       AS margin,
        MIN(f.job_date)     AS first_job,
        MAX(f.job_date)     AS last_job
    FROM v_job_financials f
    JOIN clients c ON c.client_id = f.client_id
    GROUP BY c.client_id, c.client_type
)
SELECT
    RANK() OVER (ORDER BY revenue DESC)              AS revenue_rank,
    client_id,
    client_type,
    jobs,
    CASE WHEN jobs > 1 THEN 'repeat' ELSE 'one-time' END AS customer_kind,
    ROUND(revenue, 2)                                AS revenue,
    ROUND(margin, 2)                                 AS margin,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total_revenue,
    first_job,
    last_job
FROM client_totals
ORDER BY revenue_rank
LIMIT 15;

-- Repeat-customer summary.
WITH client_jobs AS (
    SELECT client_id, COUNT(*) AS jobs, SUM(revenue) AS revenue
    FROM v_job_financials
    GROUP BY client_id
)
SELECT
    CASE WHEN jobs > 1 THEN 'repeat' ELSE 'one-time' END AS customer_kind,
    COUNT(*)                                             AS clients,
    SUM(jobs)                                            AS jobs,
    ROUND(SUM(revenue), 2)                               AS revenue,
    ROUND(100.0 * SUM(revenue) / (SELECT SUM(revenue) FROM client_jobs), 1) AS pct_revenue
FROM client_jobs
GROUP BY customer_kind;
