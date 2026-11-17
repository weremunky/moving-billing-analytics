-- Q2. Are small 1-hour jobs or big moves more profitable per crew hour?
-- Skills: CTE, CASE. Uses v_job_financials (see views.sql).
-- Jobs with no logged hours are excluded (they'd divide by zero; Q4 lists them).
WITH sized AS (
    SELECT
        *,
        CASE
            WHEN crew_hours <= 4  THEN '1. Small (<=4 crew-hrs)'
            WHEN crew_hours <= 16 THEN '2. Medium (4-16 crew-hrs)'
            WHEN crew_hours <= 40 THEN '3. Large (16-40 crew-hrs)'
            ELSE                       '4. Very large (40+ crew-hrs)'
        END AS size_bucket
    FROM v_job_financials
    WHERE crew_hours > 0
)
SELECT
    size_bucket,
    COUNT(*)                                         AS jobs,
    ROUND(SUM(revenue), 2)                           AS revenue,
    ROUND(SUM(margin), 2)                            AS margin,
    ROUND(SUM(crew_hours), 1)                        AS crew_hours,
    ROUND(SUM(revenue) / SUM(crew_hours), 2)         AS revenue_per_crew_hour,
    ROUND(SUM(margin)  / SUM(crew_hours), 2)         AS margin_per_crew_hour,
    ROUND(100.0 * SUM(margin) / NULLIF(SUM(revenue), 0), 1) AS margin_pct
FROM sized
GROUP BY size_bucket
ORDER BY size_bucket;

-- Same question by the job_type label you assign in the sheet:
SELECT
    job_type,
    COUNT(*)                                  AS jobs,
    ROUND(SUM(margin) / SUM(crew_hours), 2)   AS margin_per_crew_hour
FROM v_job_financials
WHERE crew_hours > 0
GROUP BY job_type
ORDER BY margin_per_crew_hour DESC;
