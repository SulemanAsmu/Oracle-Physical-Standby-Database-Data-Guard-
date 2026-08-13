-- =============================================
-- Database:    Oracle 19c/21c
-- Author:      Suleman
-- Description: Standby Database Creation
--              Using RMAN Duplicate
--              *** MOST RECOMMENDED METHOD ***
-- Run On:      STANDBY SERVER
-- =============================================

-- -----------------------------------------------
-- METHOD 1: RMAN DUPLICATE (Recommended)
--           Run from STANDBY server
--           Copies all files automatically
-- -----------------------------------------------

/*
Run this from OS command line on STANDBY server:

rman TARGET sys@COMPANYDB_PRI AUXILIARY /

Then inside RMAN run the DUPLICATE command below:
*/

-- RMAN Script for Duplicate (save as duplicate.rman)
/*
RUN {
    ALLOCATE CHANNEL pri1
        TYPE DISK;
    ALLOCATE AUXILIARY CHANNEL stb1
        TYPE DISK;

    DUPLICATE TARGET DATABASE
        FOR STANDBY
        FROM ACTIVE DATABASE
        DORECOVER
        SPFILE
            SET DB_UNIQUE_NAME          'COMPANYDB_STB'
            SET LOG_ARCHIVE_DEST_2      'SERVICE=COMPANYDB_PRI
                                         ASYNC
                                         VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
                                         DB_UNIQUE_NAME=COMPANYDB_PRI'
            SET FAL_SERVER              'COMPANYDB_PRI'
            SET FAL_CLIENT              'COMPANYDB_STB'
            SET STANDBY_FILE_MANAGEMENT 'AUTO'
            SET DB_FILE_NAME_CONVERT    '/u01/oradata/COMPANYDB',
                                        '/u01/oradata/COMPANYDB'
            SET LOG_FILE_NAME_CONVERT   '/u01/oradata/COMPANYDB',
                                        '/u01/oradata/COMPANYDB'
        NOFILENAMECHECK;
}
*/

-- -----------------------------------------------
-- After RMAN Duplicate Completes:
-- Run these on STANDBY to start Redo Apply
-- -----------------------------------------------

-- Start Managed Recovery Process (MRP)
-- This applies redo logs from primary continuously
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
    USING CURRENT LOGFILE
    DISCONNECT FROM SESSION;

-- Verify MRP is running
SELECT
    PROCESS,
    STATUS,
    THREAD#,
    SEQUENCE#,
    BLOCK#,
    BLOCKS
FROM V$MANAGED_STANDBY
ORDER BY PROCESS;

-- -----------------------------------------------
-- Verify Standby is Receiving and Applying Logs
-- -----------------------------------------------

-- Check last received sequence
SELECT
    THREAD#,
    MAX(SEQUENCE#)  AS LAST_RECEIVED
FROM V$ARCHIVED_LOG
WHERE DEST_ID = 1
GROUP BY THREAD#;

-- Check last applied sequence
SELECT
    THREAD#,
    MAX(SEQUENCE#)  AS LAST_APPLIED
FROM V$LOG_HISTORY
GROUP BY THREAD#;

-- Check apply lag
SELECT
    NAME,
    VALUE,
    DATUM_TIME
FROM V$DATAGUARD_STATS
WHERE NAME IN (
    'transport lag',
    'apply lag',
    'apply finish time'
)
ORDER BY NAME;

-- -----------------------------------------------
-- Open Standby as READ ONLY (Optional)
-- Allows reporting queries on standby
-- -----------------------------------------------

-- Stop MRP first
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Open read only
ALTER DATABASE OPEN READ ONLY;

-- Restart MRP in read only mode (Active Data Guard)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
    USING CURRENT LOGFILE
    DISCONNECT FROM SESSION;

-- Verify standby is open and applying
SELECT
    DB_UNIQUE_NAME,
    OPEN_MODE,
    DATABASE_ROLE,
    PROTECTION_MODE
FROM V$DATABASE;
