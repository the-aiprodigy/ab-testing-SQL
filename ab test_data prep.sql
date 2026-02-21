-- PHASE 1: DATA PREPARATION & ENVIRONMENT SETUP
--------------------------------------------------------------------------------

-- 1. TABLE CREATION
-- Table Creation and add NOT NULL constraints where logical
CREATE TABLE dashboard_sessions (
    user_id             VARCHAR2(20)    NOT NULL,
    session_id          VARCHAR2(20)    NOT NULL,
    timestamp           TIMESTAMP       NOT NULL,
    group_id            CHAR(1)         NOT NULL,  -- renamed to avoid GROUP keyword
    device_type         VARCHAR2(10),
    country             VARCHAR2(5),
    cookie_segment      VARCHAR2(20),
    page_load_time_sec  NUMBER(5,2),
    widgets_viewed      NUMBER(3),
    filters_applied     NUMBER(3),
    time_on_dashboard_sec NUMBER(6,1),
    bounce              NUMBER(1)       CHECK (bounce IN (0,1)),
    conversion          NUMBER(1)       CHECK (conversion IN (0,1))
)
TABLESPACE users
STORAGE (INITIAL 1M NEXT 1M);


-- Indexes for performance
CREATE INDEX idx_group ON dashboard_sessions(group_id);
CREATE INDEX idx_device ON dashboard_sessions(device_type);
CREATE INDEX idx_country ON dashboard_sessions(country);
CREATE INDEX idx_cookie ON dashboard_sessions(cookie_segment);
CREATE INDEX idx_user ON dashboard_sessions(user_id);
CREATE INDEX idx_group_user ON dashboard_sessions(group_id, user_id); -- composite index for experiment groups

-- Add primary key; Session IDs should be unique.
ALTER TABLE dashboard_sessions
ADD CONSTRAINT pk_sessions PRIMARY KEY (session_id);


-- 2. DATA LOADING (Using External Table - Recommended for CSV)
-- Step 1: Create directory object (run as SYS or DBA)
CREATE OR REPLACE DIRECTORY data_dir AS 'C:\app\psupa\product\21c\oradata\DATA_DIR';

SELECT USER FROM dual;

GRANT READ, WRITE ON DIRECTORY data_dir TO SYSTEM;

SELECT directory_name, directory_path
FROM all_directories
WHERE directory_name = 'DATA_DIR';

-- Verify directory (run as user with CREATE ANY DIRECTORY privilege)
SELECT * FROM all_directories WHERE directory_name = 'DATA_DIR';

DROP TABLE ext_dashboard_sessions;

-- Step 2: External table definition
-- Key: FIELDS list matches CSV headers EXACTLY (lowercase)
DROP TABLE ext_dashboard_sessions;

CREATE TABLE ext_dashboard_sessions (
    user_id               VARCHAR2(20),
    session_id            VARCHAR2(20),
    timestamp_str         VARCHAR2(30),
    group_id              CHAR(1),
    device_type           VARCHAR2(10),
    country               VARCHAR2(5),
    cookie_segment        VARCHAR2(20),
    page_load_time_sec    VARCHAR2(10),
    widgets_viewed        VARCHAR2(5),
    filters_applied       VARCHAR2(5),
    time_on_dashboard_sec VARCHAR2(10),
    bounce                VARCHAR2(1),
    conversion            VARCHAR2(1)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY data_dir
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
    )
    LOCATION ('dashboard_ab_test_cookie_data.csv')
)
REJECT LIMIT UNLIMITED;

SELECT directory_name, directory_path
FROM all_directories
WHERE directory_name = 'DATA_DIR';


-- Test load (preview first 10 rows)
SELECT * FROM ext_dashboard_sessions WHERE ROWNUM <= 10;

SELECT * FROM dashboard_sessions;

-- Remove previous incorrect rows
TRUNCATE TABLE dashboard_sessions;


-- Step 3: Load to main table (with cleaning)
INSERT /*+ APPEND */ INTO dashboard_sessions
SELECT 
    user_id,
    session_id,
    TO_TIMESTAMP(timestamp_str, 'DD/MM/YYYY HH24:MI'),
    group_id,
    device_type,
    country,
    cookie_segment,
    GREATEST(page_load_time_sec, 0),  -- clean negatives
    widgets_viewed,
    filters_applied,
    GREATEST(time_on_dashboard_sec, 0),  -- clean negatives
    bounce,
    conversion
FROM ext_dashboard_sessions;
COMMIT;

-- Verify after data load
SELECT * FROM ext_dashboard_sessions;

-- Verify no rows were skipped
SELECT COUNT(*) FROM ext_dashboard_sessions;
SELECT COUNT(*) FROM dashboard_sessions;

SELECT timestamp
FROM dashboard_sessions
WHERE ROWNUM <= 20;

SELECT *
FROM dashboard_sessions
FETCH FIRST 5 ROWS ONLY;

-- Find any malformed timestamps:
SELECT timestamp
FROM dashboard_sessions
WHERE NOT REGEXP_LIKE(
    timestamp,
    '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
);

-- 3. DATA QUALITY & BALANCE CHECKS
-- rename timestamp to session_timestamp to improves clarity and avoid confusion with Oracle’s TIMESTAMP datatype keyword.
ALTER TABLE dashboard_sessions
RENAME COLUMN timestamp TO session_timestamp;



-- Check 1: Record counts and completeness
SELECT 
    'Total Records' AS metric,
    COUNT(*) AS value,
    TO_CHAR(MIN(session_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS min_date,
    TO_CHAR(MAX(session_timestamp), 'YYYY-MM-DD HH24:MI:SS') AS max_date
FROM dashboard_sessions
UNION ALL
SELECT 
    'Missing Session IDs',
    COUNT(*),
    NULL,
    NULL
FROM dashboard_sessions
WHERE session_id IS NULL
UNION ALL
SELECT 
    'Missing User IDs',
    COUNT(*),
    NULL,
    NULL
FROM dashboard_sessions
WHERE user_id IS NULL
UNION ALL
SELECT 
    'Null Timestamps',
    COUNT(*),
    NULL,
    NULL
FROM dashboard_sessions
WHERE session_timestamp IS NULL;

-- Check 2: Duplicate detection
SELECT 
    'Duplicate Sessions' AS check_type,
    COUNT(*) - COUNT(DISTINCT session_id) AS duplicate_count
FROM dashboard_sessions
UNION ALL
SELECT 
    'Sessions per User (Avg)',
    ROUND(COUNT(*) / COUNT(DISTINCT user_id), 2)
FROM dashboard_sessions;

-- OR Check for duplicates only
SELECT 
    COUNT(*) AS total,
    COUNT(DISTINCT session_id) AS unique_sessions,
    CASE WHEN COUNT(*) = COUNT(DISTINCT session_id) THEN 'CLEAN' ELSE 'DUPLICATES' END AS status
FROM dashboard_sessions;


-- Check 3: Test group balance - should be ~50/50
SELECT 
    group_id,
    COUNT(*) AS session_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    COUNT(DISTINCT user_id) AS unique_users
FROM dashboard_sessions
GROUP BY group_id
ORDER BY group_id;


-- Check 4: Data quality flags and outlier detection
WITH outlier_detection AS (
    SELECT 
        session_id,
        CASE 
            WHEN page_load_time_sec < 0 THEN 'Negative Load Time'
            WHEN page_load_time_sec > 10 THEN 'Extreme Load Time'
            WHEN time_on_dashboard_sec < 0 THEN 'Negative Session Duration'
            WHEN time_on_dashboard_sec > 600 THEN 'Extreme Duration (>10min)'
            WHEN widgets_viewed > 10 THEN 'Unusually High Widgets'
            WHEN filters_applied > 10 THEN 'Unusually High Filters'
            ELSE 'Clean'
        END AS quality_flag
    FROM dashboard_sessions
)
SELECT 
    quality_flag,
    COUNT(*) AS record_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM outlier_detection
GROUP BY quality_flag
ORDER BY record_count DESC;


-- Check 5: Categorical variable distributions
SELECT *
FROM (
-- Device Distribution
    SELECT 'Device Type Distribution' AS category, NULL AS subcategory, NULL AS cnt, NULL AS pct FROM DUAL

    UNION ALL

    SELECT NULL, device_type, COUNT(*),
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)
    FROM dashboard_sessions
    GROUP BY device_type
    
-- Country Distribution
    UNION ALL

    SELECT 'Country Distribution', NULL, NULL, NULL FROM DUAL

    UNION ALL

    SELECT NULL, country, COUNT(*),
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)
    FROM dashboard_sessions
    GROUP BY country
    
  -- Cookie Segment Distribution
    UNION ALL

    SELECT 'Cookie Segment Distribution', NULL, NULL, NULL FROM DUAL

    UNION ALL

    SELECT NULL, cookie_segment, COUNT(*),
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)
    FROM dashboard_sessions
    GROUP BY cookie_segment
)
ORDER BY category NULLS LAST,
         cnt DESC NULLS LAST;
         
-- Check 6: Covariance Balance Checks
SELECT 
    device_type,
    group_id,
    COUNT(*) AS "COUNT"
FROM dashboard_sessions
GROUP BY device_type, group_id
ORDER BY device_type, group_id;

-- Country Covariate
SELECT country, group_id, COUNT(*) AS "COUNT"
FROM dashboard_sessions
GROUP BY country, group_id;

-- Cookie Segment Covariate
SELECT cookie_segment, group_id, COUNT(*) AS "COUNT"
FROM dashboard_sessions
GROUP BY cookie_segment, group_id;

-- Check 7: User-Level Exposure Consistency Check
SELECT user_id,
       COUNT(DISTINCT group_id) AS group_count
FROM dashboard_sessions
GROUP BY user_id
HAVING COUNT(DISTINCT group_id) > 1;

SELECT session_id,
       COUNT(DISTINCT group_id)
FROM dashboard_sessions
GROUP BY session_id
HAVING COUNT(DISTINCT group_id) > 1;

SELECT user_id,
       MIN(group_id),
       MAX(group_id)
FROM dashboard_sessions
GROUP BY user_id
HAVING MIN(group_id) != MAX(group_id);