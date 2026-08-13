-- =============================================
-- Database:    Oracle 19c/21c
-- Author:      Suleman
-- Description: Data Guard Monitoring Scripts
--              Run on PRIMARY or STANDBY
-- =============================================

-- -----------------------------------------------
-- 1. Overall Data Guard Status
-- -----------------------------------------------
SELECT
    NAME,
    DB_UNIQUE_NAME,
    OPEN_MODE,
    DATABASE_ROLE,
    PROTECTION_MODE,
    PROTECTION_LEVEL,
    SWITCHOVER_STATUS,
    DATAGUARD_BROKER,
    GUARD_STATUS,
    FLASHBACK_ON
FROM V$DATABASE;

-- -----------------------------------------------
-- 2. Transport and Apply Lag
--    Run on STANDBY
-- -----------------------------------------------
SELECT
    NAME,
    VALUE,
    UNIT,
    TIME_COMPUTED
FROM V$DATAGUARD_STATS
WHERE NAME IN (
    'transport lag',
    'apply lag',
    'apply finish time',
    'estimated startup time'
)
ORDER BY NAME;

-- -----------------------------------------------
-- 3. MRP and RFS Process Status
--    Run on STANDBY
-- -----------------------------------------------
SELECT
    PROCESS,
    PID,
    STATUS,
    CLIENT_PROCESS,
    CLIENT_PID,
    THREAD#,
    SEQUENCE#,
    BLOCK#,
    BLOCKS,
    DELAY_MINS
FROM V$MANAGED_STANDBY
ORDER BY
    CASE PROCESS
        WHEN 'MRP0' THEN 1
        WHEN 'RFS'  THEN 2
        ELSE 3
    END;

-- -----------------------------------------------
-- 4. Archive Log Sequence Gap Check
--    Run on STANDBY
-- -----------------------------------------------
-- Sequences received from primary
SELECT
    'RECEIVED' AS TYPE,
    THREAD#,
    MAX(SEQUENCE#) AS MAX_SEQUENCE
FROM V$ARCHIVED_LOG
WHERE DEST_ID = 1
  AND STANDBY_DEST = 'NO'
GROUP BY THREAD#

UNION ALL

-- Sequences applied on standby
SELECT
    'APPLIED',
    THREAD#,
    MAX(SEQUENCE#)
FROM V$ARCHIVED_LOG
WHERE DEST_ID = 1
  AND APPLIED = 'YES'
GROUP BY THREAD#

ORDER BY THREAD#, TYPE;

-- -----------------------------------------------
-- 5. Check for Archive Log Gaps
--    Run on PRIMARY
-- -----------------------------------------------
SELECT
    THREAD#,
    LOW_SEQUENCE#,
    HIGH_SEQUENCE#
FROM V$ARCHIVE_GAP
ORDER BY THREAD#;

-- -----------------------------------------------
-- 6. Primary - Redo Shipping Status
--    Run on PRIMARY
-- -----------------------------------------------
SELECT
    DEST_ID,
    DEST_NAME,
    STATUS,
    TARGET,
    ARCHIVER,
    SCHEDULE,
    DESTINATION,
    AFFIRM,
    ASYNC_BLOCKS,
    NET_TIMEOUT,
    DELAY_MINS,
    DB_UNIQUE_NAME,
    SYNC_STATUS,
    ERROR
FROM V$ARCHIVE_DEST
WHERE TARGET = 'STANDBY'
  AND STATUS != 'INACTIVE';

-- -----------------------------------------------
-- 7. Standby Redo Log Status
-- -----------------------------------------------
SELECT
    GROUP#,
    THREAD#,
    SEQUENCE#,
    BYTES/1024/1024  AS SIZE_MB,
    STATUS
FROM V$STANDBY_LOG
ORDER BY GROUP#;

-- -----------------------------------------------
-- 8. Alert Log Errors Check
--    Recent errors from alert log
-- -----------------------------------------------
SELECT
    ORIGINATING_TIMESTAMP,
    MESSAGE_TEXT
FROM V$DIAG_ALERT_EXT
WHERE MESSAGE_TEXT LIKE '%ORA-%'
   OR MESSAGE_TEXT LIKE '%Error%'
   OR MESSAGE_TEXT LIKE '%GAP%'
ORDER BY ORIGINATING_TIMESTAMP DESC
FETCH FIRST 20 ROWS ONLY;

-- -----------------------------------------------
-- 9. Data Guard Health Check Summary
--    Run on STANDBY
-- -----------------------------------------------
SELECT
    'Database Role'        AS CHECK_ITEM,
    DATABASE_ROLE          AS STATUS
FROM V$DATABASE
UNION ALL
SELECT
    'Open Mode',
    OPEN_MODE
FROM V$DATABASE
UNION ALL
SELECT
    'Protection Mode',
    PROTECTION_MODE
FROM V$DATABASE
UNION ALL
SELECT
    'Flashback',
    FLASHBACK_ON
FROM V$DATABASE
UNION ALL
SELECT
    'MRP Status',
    STATUS
FROM V$MANAGED_STANDBY
WHERE PROCESS = 'MRP0'
UNION ALL
SELECT
    'Apply Lag',
    VALUE
FROM V$DATAGUARD_STATS
WHERE NAME = 'apply lag';
