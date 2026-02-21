SELECT *
FROM dashboard_sessions;

-- DATA CLEANING & TRANSFORMATION
----------------------------------------------------------------------------------
--Handle outliers and create analytical variables
-- Create cleaned dataset view
CREATE OR REPLACE VIEW vw_dashboard_clean AS
SELECT 
    session_id,
    user_id,
    session_timestamp,
    group_id,
    device_type,
    country,
    cookie_segment,
    
    -- Preserve Raw Metrics
    page_load_time_sec      AS page_load_time_raw,
    time_on_dashboard_sec   AS time_on_dashboard_raw,
    
    -- Clean page load time (cap extreme values)
    CASE 
        WHEN page_load_time_sec < 0 THEN 0
        WHEN page_load_time_sec > 10 THEN 10
        ELSE page_load_time_sec
    END AS page_load_time_clean,
    
    -- Clean time on dashboard (cap extreme values)
    CASE 
        WHEN time_on_dashboard_sec < 0 THEN 0
        WHEN time_on_dashboard_sec > 600 THEN 600
        ELSE time_on_dashboard_sec
    END AS time_on_dashboard_clean,
    
    
    -- Original metrics
    widgets_viewed,
    filters_applied,
    bounce,
    conversion,
    
    -- Derived behavioral features
    CASE WHEN widgets_viewed > 0 THEN 1 ELSE 0 END AS widget_engaged,
    CASE WHEN filters_applied > 0 THEN 1 ELSE 0 END AS filter_engaged,

    CASE 
        WHEN time_on_dashboard_sec >= 300 THEN 'High'
        WHEN time_on_dashboard_sec >= 120 THEN 'Medium'
        ELSE 'Low'
    END AS engagement_tier,
    
    -- Date components for temporal analysis (temporal features)
    TO_CHAR(session_timestamp, 'YYYY-MM') AS year_month,
    TRIM(TO_CHAR(session_timestamp, 'Day')) AS day_of_week,
    TO_NUMBER(TO_CHAR(session_timestamp, 'HH24')) AS hour_of_day,
    
    -- Quality flag
    CASE 
        WHEN page_load_time_sec < 0 
          OR time_on_dashboard_sec < 0 THEN 'Anomaly'
        WHEN page_load_time_sec > 10 
          OR time_on_dashboard_sec > 600 THEN 'Outlier'
        ELSE 'Normal'
    END AS data_quality

FROM dashboard_sessions;

SELECT * FROM vw_dashboard_clean;

-- Validation of Test Setup (Randomization Check)
----------------------------------------------------------------------------------
-- Ensure proper randomization across dimensions
-- Check 1: Test group balance across devices
SELECT 
    device_type,
    group_id,
    COUNT(*) AS sessions,
    ROUND(
        COUNT(*) * 100.0 
        / SUM(COUNT(*)) OVER (PARTITION BY device_type),
        2
    ) AS pct_within_device
FROM vw_dashboard_clean
GROUP BY device_type, group_id
ORDER BY device_type, group_id;


-- Check 2: Test group balance across cookie segments
SELECT 
    cookie_segment,
    group_id,
    COUNT(*) AS sessions,
    ROUND(
        COUNT(*) * 100.0 
        / SUM(COUNT(*)) OVER (PARTITION BY cookie_segment),
        2
    ) AS pct_within_segment
FROM vw_dashboard_clean
GROUP BY cookie_segment, group_id
ORDER BY cookie_segment, group_id;

-- Check 3: Chi-square test for independence (randomization validation)
-- Checking if test group assignment is independent of pre-existing user characteristics
WITH observed_counts AS (
    SELECT cookie_segment,
           group_id,
           COUNT(*) AS observed
    FROM vw_dashboard_clean
    GROUP BY cookie_segment, group_id
),
totals AS (
    SELECT
        cookie_segment,
        SUM(observed) row_total
    FROM observed_counts
    GROUP BY cookie_segment
),
col_totals AS (
    SELECT
        group_id,
        SUM(observed) col_total
    FROM observed_counts
    GROUP BY group_id
),
grand_total AS (
    SELECT SUM(observed) total FROM observed_counts
)
SELECT
    o.cookie_segment,
    o.group_id,
    o.observed,
    (t.row_total * c.col_total) / g.total AS expected
FROM observed_counts o
JOIN totals t ON o.cookie_segment = t.cookie_segment
JOIN col_totals c ON o.group_id = c.group_id
JOIN grand_total g ON 1=1
ORDER BY o.cookie_segment, o.group_id;

-- Calculate total chi-square statistic
WITH chi_components AS (
    SELECT 
        o.cookie_segment,
        o.group_id,
        POWER(o.observed - 
            (SUM(o.observed) OVER (PARTITION BY o.cookie_segment) * 
             SUM(o.observed) OVER (PARTITION BY o.group_id)) / 
            SUM(o.observed) OVER (), 2
        ) / NULLIF(
            (SUM(o.observed) OVER (PARTITION BY o.cookie_segment) * 
             SUM(o.observed) OVER (PARTITION BY o.group_id)) / 
            SUM(o.observed) OVER (), 0
        ) AS chi_component
    FROM (
        SELECT cookie_segment, group_id, COUNT(*) AS observed
        FROM vw_dashboard_clean
        GROUP BY cookie_segment, group_id
    ) o
)
SELECT 
    ROUND(SUM(chi_component), 4) AS chi_square_statistic,
    -- Degrees of freedom = (rows - 1) * (columns - 1) = (5 - 1) * (2 - 1) = 4
    4 AS degrees_of_freedom,
    -- Critical value at ?=0.05, df=4 is 9.488
    CASE 
        WHEN SUM(chi_component) > 9.488 THEN 'REJECT NULL - Groups are NOT randomly assigned'
        ELSE 'ACCEPT NULL - Groups appear randomly assigned'
    END AS randomization_conclusion
FROM chi_components;

-- Summary Statistics
--------------------------------------------------------------------------------
-- Comprehensive summary table
SELECT 
    'Data Preparation Complete' AS status,
    COUNT(*) AS total_sessions,
    COUNT(DISTINCT user_id) AS unique_users,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 2) AS avg_sessions_per_user,
    MIN(session_timestamp) AS first_session,
    MAX(session_timestamp) AS last_session,
    ROUND(
        (CAST(MAX(session_timestamp) AS DATE) - CAST(MIN(session_timestamp) AS DATE)), 0
    ) AS days_of_data
FROM vw_dashboard_clean
WHERE data_quality = 'Normal';

-- Quality metrics
SELECT 
    data_quality,
    COUNT(*) AS record_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM vw_dashboard_clean
GROUP BY data_quality
ORDER BY record_count DESC;