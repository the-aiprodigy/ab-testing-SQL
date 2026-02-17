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
SELECT COUNT(*) FROM dashboard_sessions;
SELECT COUNT(*) FROM ext_dashboard_sessions;

SELECT timestamp_str
FROM ext_dashboard_sessions
WHERE ROWNUM <= 20;

SELECT *
FROM dashboard_sessions
FETCH FIRST 5 ROWS ONLY;

-- Find any malformed timestamps:
SELECT timestamp_str
FROM ext_dashboard_sessions
WHERE NOT REGEXP_LIKE(
    timestamp_str,
    '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$'
);

