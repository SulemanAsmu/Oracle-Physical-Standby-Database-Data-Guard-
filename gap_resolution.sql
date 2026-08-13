-- =============================================
-- Database:    Oracle 19c/21c
-- Author:      Suleman
-- Description: Archive Log Gap Detection
--              and Resolution
-- =============================================

-- -----------------------------------------------
-- 1. Detect Gap on STANDBY
-- -----------------------------------------------
-- Check for gaps
SELECT
    THREAD#,
    LOW_SEQUENCE#   AS GAP_START,
    HIGH_SEQUENCE#  AS GAP_END,
    HIGH_SEQUENCE# - LOW_SEQUENCE# + 1 AS GAP_SIZE
FROM V$ARCHIVE_GAP
ORDER BY THREAD#, LOW_SEQUENCE#;

-- If no rows returned = No Gap ✅
-- If rows returned = Gap exists ⚠️

-- -----------------------------------------------
-- 2. Check FAL (Fetch Archive Log) is configured
--    FAL automatically resolves gaps
-- -----------------------------------------------
SHOW PARAMETER FAL_SERVER;
SHOW PARAMETER FAL_CLIENT;

-- -----------------------------------------------
-- 3. Force FAL to Fetch Missing Logs
-- -----------------------------------------------
-- Stop MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Trigger FAL to fetch missing logs
ALTER DATABASE REGISTER PHYSICAL LOGFILE
    '/u01/fra/COMPANYDB/archivelog/missing.arc';

-- Restart MRP
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
    USING CURRENT LOGFILE
    DISCONNECT FROM SESSION;

-- -----------------------------------------------
-- 4. Manual Gap Resolution
--    If FAL cannot fetch automatically
--    Copy archives manually from PRIMARY
-- -----------------------------------------------

/*
-- Run on PRIMARY - find missing archives
SELECT
    NAME
FROM V$ARCHIVED_LOG
WHERE THREAD# = 1
  AND SEQUENCE# BETWEEN 100 AND 110
  AND STANDBY_DEST = 'NO';

-- Copy from PRIMARY to STANDBY (run on standby OS)
-- scp oracle@primary-srv:/u01/fra/COMPANYDB/archivelog/xxx.arc
--     /u01/fra/COMPANYDB/archivelog/

-- Register on STANDBY
ALTER DATABASE REGISTER PHYSICAL LOGFILE
    '/u01/fra/COMPANYDB/archivelog/xxx.arc';
*/

-- -----------------------------------------------
-- 5. Verify Gap is Resolved
-- -----------------------------------------------
-- Check sequences match
SELECT
    'PRIMARY LAST ARCHIVED' AS SOURCE,
    MAX(SEQUENCE#)          AS SEQUENCE
FROM V$ARCHIVED_LOG
WHERE DEST_ID  = 2
  AND THREAD#  = 1

UNION ALL

SELECT
    'STANDBY LAST APPLIED',
    MAX(SEQUENCE#)
FROM V$ARCHIVED_LOG
WHERE DEST_ID  = 1
  AND APPLIED  = 'YES'
  AND THREAD#  = 1;

-- -----------------------------------------------
-- 6. Monitor Real-Time Apply Status
-- -----------------------------------------------
SELECT
    PROCESS,
    STATUS,
    THREAD#,
    SEQUENCE#,
    TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') AS CHECK_TIME
FROM V$MANAGED_STANDBY
WHERE PROCESS IN ('MRP0','RFS')
ORDER BY PROCESS;
