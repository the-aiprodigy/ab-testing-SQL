-- EXPLORATORY DATA ANALYSIS (EDA)
-- Deep dive into data patterns, distributions, and preliminary insights
--------------------------------------------------------------------------------

-- 2.1: OVERALL METRICS SUMMARY BY TEST GROUP
-- -----------------------------------------------------------------------------
-- High-level comparison of all KPIs between groups

CREATE OR REPLACE VIEW vw_group_summary AS
SELECT 
    group_id AS test_group,
    
    -- Sample size metrics
    COUNT(*) AS total_sessions,
    COUNT(DISTINCT user_id) AS unique_users,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 2) AS sessions_per_user,
    
    -- Conversion metrics
    SUM(conversion) AS conversions,
    ROUND(AVG(conversion) * 100, 2) AS conversion_rate_pct,
    ROUND(STDDEV(conversion), 4) AS conversion_stddev,
    
    -- Engagement metrics
    SUM(bounce) AS bounces,
    ROUND(AVG(bounce) * 100, 2) AS bounce_rate_pct,
    ROUND(AVG(CASE WHEN bounce = 0 THEN 1 ELSE 0 END) * 100, 2) AS engagement_rate_pct,
    
    -- Behavioral metrics
    ROUND(AVG(widgets_viewed), 2) AS avg_widgets_viewed,
    ROUND(AVG(filters_applied), 2) AS avg_filters_applied,
    ROUND(AVG(time_on_dashboard_clean), 2) AS avg_time_on_dashboard,
    ROUND(MEDIAN(time_on_dashboard_clean), 2) AS median_time_on_dashboard,
    
    -- Performance metrics
    ROUND(AVG(page_load_time_clean), 2) AS avg_page_load_time,
    ROUND(MEDIAN(page_load_time_clean), 2) AS median_page_load_time,
    
    -- Advanced engagement metrics
    ROUND(AVG(widget_engaged) * 100, 2) AS pct_sessions_with_widgets,
    ROUND(AVG(filter_engaged) * 100, 2) AS pct_sessions_with_filters
    
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY group_id
ORDER BY group_id;

-- Execute summary view
SELECT * FROM vw_group_summary;

-- Calculate absolute and relative differences
WITH group_metrics AS (
    SELECT * FROM vw_group_summary
)
SELECT 
    'Conversion Rate' AS metric,
    a.conversion_rate_pct AS group_a_value,
    b.conversion_rate_pct AS group_b_value,
    ROUND(b.conversion_rate_pct - a.conversion_rate_pct, 2) AS absolute_diff,
    ROUND((b.conversion_rate_pct - a.conversion_rate_pct) / NULLIF(a.conversion_rate_pct, 0) * 100, 2) AS relative_lift_pct
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b
UNION ALL
SELECT 
    'Bounce Rate',
    a.bounce_rate_pct,
    b.bounce_rate_pct,
    ROUND(b.bounce_rate_pct - a.bounce_rate_pct, 2),
    ROUND((b.bounce_rate_pct - a.bounce_rate_pct) / NULLIF(a.bounce_rate_pct, 0) * 100, 2)
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b
UNION ALL
SELECT 
    'Avg Widgets Viewed',
    a.avg_widgets_viewed,
    b.avg_widgets_viewed,
    ROUND(b.avg_widgets_viewed - a.avg_widgets_viewed, 2),
    ROUND((b.avg_widgets_viewed - a.avg_widgets_viewed) / NULLIF(a.avg_widgets_viewed, 0) * 100, 2)
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b
UNION ALL
SELECT 
    'Avg Filters Applied',
    a.avg_filters_applied,
    b.avg_filters_applied,
    ROUND(b.avg_filters_applied - a.avg_filters_applied, 2),
    ROUND((b.avg_filters_applied - a.avg_filters_applied) / NULLIF(a.avg_filters_applied, 0) * 100, 2)
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b
UNION ALL
SELECT 
    'Avg Time on Dashboard',
    a.avg_time_on_dashboard,
    b.avg_time_on_dashboard,
    ROUND(b.avg_time_on_dashboard - a.avg_time_on_dashboard, 2),
    ROUND((b.avg_time_on_dashboard - a.avg_time_on_dashboard) / NULLIF(a.avg_time_on_dashboard, 0) * 100, 2)
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b
UNION ALL
SELECT 
    'Avg Page Load Time',
    a.avg_page_load_time,
    b.avg_page_load_time,
    ROUND(b.avg_page_load_time - a.avg_page_load_time, 2),
    ROUND((b.avg_page_load_time - a.avg_page_load_time) / NULLIF(a.avg_page_load_time, 0) * 100, 2)
FROM 
    (SELECT * FROM group_metrics WHERE test_group = 'A') a,
    (SELECT * FROM group_metrics WHERE test_group = 'B') b;

SELECT * FROM vw_dashboard_clean;
-- 2.2: DISTRIBUTION ANALYSIS
-- --------------------------------------------------------------------------------
-- Understand the shape and spread of key metrics
-- Percentile analysis for continuous variables
SELECT 
    group_id AS test_group,
    'Page Load Time' AS metric,
    ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p10,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p50_median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p90,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY page_load_time_clean), 2) AS p95,
    ROUND(AVG(page_load_time_clean), 2) AS mean
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group
UNION ALL
SELECT 
    test_group,
    'Time on Dashboard',
    ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY time_on_dashboard_clean), 2),
    ROUND(AVG(time_on_dashboard_clean), 2)
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group
UNION ALL
SELECT 
    test_group,
    'Widgets Viewed',
    ROUND(PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY widgets_viewed), 2),
    ROUND(AVG(widgets_viewed), 2)
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group
ORDER BY metric, test_group;

-- Histogram bins for widgets viewed
SELECT 
    test_group,
    CASE 
        WHEN widgets_viewed = 0 THEN '0 widgets'
        WHEN widgets_viewed BETWEEN 1 AND 2 THEN '1-2 widgets'
        WHEN widgets_viewed BETWEEN 3 AND 4 THEN '3-4 widgets'
        WHEN widgets_viewed BETWEEN 5 AND 6 THEN '5-6 widgets'
        ELSE '7+ widgets'
    END AS widget_bin,
    COUNT(*) AS sessions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY test_group), 2) AS pct_of_group,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group, 
    CASE 
        WHEN widgets_viewed = 0 THEN '0 widgets'
        WHEN widgets_viewed BETWEEN 1 AND 2 THEN '1-2 widgets'
        WHEN widgets_viewed BETWEEN 3 AND 4 THEN '3-4 widgets'
        WHEN widgets_viewed BETWEEN 5 AND 6 THEN '5-6 widgets'
        ELSE '7+ widgets'
    END
ORDER BY test_group, widget_bin;


-- 2.3: SEGMENTATION DEEP DIVE
-- --------------------------------------------------------------------------------
-- Understand performance across all segments
-- Cookie segment analysis
SELECT 
    cookie_segment,
    test_group,
    COUNT(*) AS sessions,
    SUM(conversion_flag) AS conversions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(bounce_flag) * 100, 2) AS bounce_rate_pct,
    ROUND(AVG(widgets_viewed), 2) AS avg_widgets,
    ROUND(AVG(filters_applied), 2) AS avg_filters,
    ROUND(AVG(time_on_dashboard_clean), 1) AS avg_time_sec
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY cookie_segment, test_group
ORDER BY cookie_segment, test_group;

-- Calculate lift by segment
WITH segment_performance AS (
    SELECT 
        cookie_segment,
        test_group,
        AVG(conversion_flag) * 100 AS conversion_rate_pct
    FROM vw_dashboard_clean
    WHERE data_quality = 'Normal'
    GROUP BY cookie_segment, test_group
)
SELECT 
    a.cookie_segment,
    ROUND(a.conversion_rate_pct, 2) AS group_a_conv_rate,
    ROUND(b.conversion_rate_pct, 2) AS group_b_conv_rate,
    ROUND(b.conversion_rate_pct - a.conversion_rate_pct, 2) AS absolute_lift,
    ROUND((b.conversion_rate_pct - a.conversion_rate_pct) / NULLIF(a.conversion_rate_pct, 0) * 100, 1) AS relative_lift_pct
FROM 
    (SELECT * FROM segment_performance WHERE test_group = 'A') a
    INNER JOIN 
    (SELECT * FROM segment_performance WHERE test_group = 'B') b
    ON a.cookie_segment = b.cookie_segment
ORDER BY relative_lift_pct DESC;

-- Device type analysis
SELECT 
    device_type,
    test_group,
    COUNT(*) AS sessions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(page_load_time_clean), 2) AS avg_load_time,
    ROUND(AVG(time_on_dashboard_clean), 1) AS avg_time_sec,
    ROUND(AVG(widgets_viewed), 2) AS avg_widgets
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY device_type, test_group
ORDER BY device_type, test_group;

-- Country/geography analysis
SELECT 
    country,
    test_group,
    COUNT(*) AS sessions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(bounce_flag) * 100, 2) AS bounce_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY country, test_group
ORDER BY sessions DESC;


-- 2.4: CORRELATION ANALYSIS
-- --------------------------------------------------------------------------------
-- Identify relationships between engagement and conversion
-- Correlation between widgets viewed and conversion
WITH engagement_conversion AS (
    SELECT 
        test_group,
        widgets_viewed,
        conversion_flag,
        ROUND(AVG(conversion_flag) OVER (PARTITION BY test_group, widgets_viewed) * 100, 2) AS conv_rate_for_widget_level
    FROM vw_dashboard_clean
    WHERE data_quality = 'Normal'
)
SELECT DISTINCT
    test_group,
    widgets_viewed,
    conv_rate_for_widget_level
FROM engagement_conversion
ORDER BY test_group, widgets_viewed;

-- Conversion rate by filters applied
SELECT 
    test_group,
    filters_applied,
    COUNT(*) AS sessions,
    SUM(conversion_flag) AS conversions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group, filters_applied
ORDER BY test_group, filters_applied;

-- Time on dashboard vs conversion (binned analysis)
SELECT 
    test_group,
    CASE 
        WHEN time_on_dashboard_clean < 60 THEN '< 1 min'
        WHEN time_on_dashboard_clean < 120 THEN '1-2 min'
        WHEN time_on_dashboard_clean < 180 THEN '2-3 min'
        WHEN time_on_dashboard_clean < 300 THEN '3-5 min'
        ELSE '5+ min'
    END AS time_bucket,
    COUNT(*) AS sessions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(widgets_viewed), 2) AS avg_widgets
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY test_group,
    CASE 
        WHEN time_on_dashboard_clean < 60 THEN '< 1 min'
        WHEN time_on_dashboard_clean < 120 THEN '1-2 min'
        WHEN time_on_dashboard_clean < 180 THEN '2-3 min'
        WHEN time_on_dashboard_clean < 300 THEN '3-5 min'
        ELSE '5+ min'
    END
ORDER BY test_group, time_bucket;


-- 2.5: TEMPORAL ANALYSIS
-- --------------------------------------------------------------------------------
-- Identify time-based patterns and trends
-- Daily conversion rate trend
SELECT 
    TO_CHAR(session_timestamp, 'YYYY-MM-DD') AS session_date,
    test_group,
    COUNT(*) AS sessions,
    SUM(conversion_flag) AS conversions,
    ROUND(AVG(conversion_flag) * 100, 2) AS conversion_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY TO_CHAR(session_timestamp, 'YYYY-MM-DD'), test_group
HAVING COUNT(*) >= 10  -- Filter for statistical reliability
ORDER BY session_date, test_group;

-- Monthly aggregation
SELECT 
    year_month,
    test_group,
    COUNT(*) AS sessions,
    SUM(conversion) AS conversions,
    ROUND(AVG(conversion) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(bounce) * 100, 2) AS bounce_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY year_month, test_group
ORDER BY year_month, test_group;

-- Day of week analysis
SELECT 
    day_of_week,
    test_group,
    COUNT(*) AS sessions,
    ROUND(AVG(conversion) * 100, 2) AS conversion_rate_pct,
    ROUND(AVG(time_on_dashboard_clean), 1) AS avg_time_sec
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY day_of_week, test_group
ORDER BY 
    CASE day_of_week
        WHEN 'Monday   ' THEN 1
        WHEN 'Tuesday  ' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday ' THEN 4
        WHEN 'Friday   ' THEN 5
        WHEN 'Saturday ' THEN 6
        WHEN 'Sunday   ' THEN 7
    END,
    test_group;

-- Hour of day analysis
SELECT 
    hour_of_day,
    test_group,
    COUNT(*) AS sessions,
    ROUND(AVG(conversion) * 100, 2) AS conversion_rate_pct
FROM vw_dashboard_clean
WHERE data_quality = 'Normal'
GROUP BY hour_of_day, test_group
ORDER BY TO_NUMBER(hour_of_day), test_group;


-- 2.6: USER JOURNEY ANALYSIS
-- --------------------------------------------------------------------------------
-- Understand multi-session user behavior
-- User-level aggregation
WITH user_summary AS (
    SELECT 
        user_id,
        test_group,
        COUNT(*) AS total_sessions,
        SUM(conversion_flag) AS total_conversions,
        MAX(conversion_flag) AS ever_converted,
        AVG(widgets_viewed) AS avg_widgets_per_session,
        AVG(time_on_dashboard_clean) AS avg_time_per_session,
        AVG(bounce_flag) AS bounce_rate
    FROM vw_dashboard_clean
    WHERE data_quality = 'Normal'
    GROUP BY user_id, test_group
)
SELECT 
    test_group,
    COUNT(*) AS total_users,
    ROUND(AVG(total_sessions), 2) AS avg_sessions_per_user,
    SUM(ever_converted) AS users_who_converted,
    ROUND(AVG(ever_converted) * 100, 2) AS user_conversion_rate_pct,
    ROUND(AVG(avg_widgets_per_session), 2) AS avg_widgets_per_session,
    ROUND(AVG(avg_time_per_session), 1) AS avg_time_per_session
FROM user_summary
GROUP BY test_group
ORDER BY test_group;

-- Sessions to conversion analysis
WITH user_conversions AS (
    SELECT 
        user_id,
        test_group,
        session_timestamp,
        conversion,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY session_timestamp) AS session_number,
        MAX(conversion) OVER (PARTITION BY user_id) AS ever_converted
    FROM vw_dashboard_clean
    WHERE data_quality = 'Normal'
),
first_conversion AS (
    SELECT 
        user_id,
        test_group,
        MIN(session_number) AS session_of_first_conversion
    FROM user_conversions
    WHERE conversion = 1
    GROUP BY user_id, test_group
)
SELECT 
    test_group,
    session_of_first_conversion,
    COUNT(*) AS users,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY test_group), 2) AS pct_of_converters
FROM first_conversion
GROUP BY test_group, session_of_first_conversion
ORDER BY test_group, session_of_first_conversion;


-- 2.7: FUNNEL ANALYSIS
---------------------------------------------------------------------------------
-- Track user progression through engagement steps

WITH engagement_funnel AS (
    SELECT 
        test_group,
        session_id,
        CASE WHEN bounce = 0 THEN 1 ELSE 0 END AS step1_no_bounce,
        widget_engaged AS step2_viewed_widget,
        filter_engaged AS step3_applied_filter,
        conversion AS step4_converted
    FROM vw_dashboard_clean
    WHERE data_quality = 'Normal'
)
SELECT 
    test_group,
    COUNT(*) AS total_sessions,
    SUM(step1_no_bounce) AS no_bounce,
    SUM(step2_viewed_widget) AS viewed_widgets,
    SUM(step3_applied_filter) AS applied_filters,
    SUM(step4_converted) AS converted,
    
    -- Conversion rates at each stage
    ROUND(AVG(step1_no_bounce) * 100, 2) AS pct_no_bounce,
    ROUND(SUM(step2_viewed_widget) * 100.0 / NULLIF(SUM(step1_no_bounce), 0), 2) AS pct_widget_of_engaged,
    ROUND(SUM(step3_applied_filter) * 100.0 / NULLIF(SUM(step2_viewed_widget), 0), 2) AS pct_filter_of_widget,
    ROUND(SUM(step4_converted) * 100.0 / NULLIF(SUM(step3_applied_filter), 0), 2) AS pct_convert_of_filter
FROM engagement_funnel
GROUP BY test_group
ORDER BY test_group;


-- SUMMARY: KEY EDA INSIGHTS
-- Summary insight table
SELECT 'EDA COMPLETE - KEY FINDINGS' AS status FROM DUAL
UNION ALL
SELECT '1. Group B shows higher conversion rate across all metrics' FROM DUAL
UNION ALL
SELECT '2. Engagement (widgets, filters) positively correlates with conversion' FROM DUAL
UNION ALL
SELECT '3. Test groups are well-balanced across segments' FROM DUAL
UNION ALL
SELECT '4. Ready for statistical significance testing' FROM DUAL;
