-- =============================================
-- Database:    Oracle 19c/21c
-- Author:      Suleman
-- Description: Primary Database Configuration
--              for Data Guard Setup
-- Run On:      PRIMARY SERVER
-- =============================================

-- -----------------------------------------------
-- STEP 1: Verify Primary Database is in
--         ARCHIVELOG mode
-- -----------------------------------------------
SELECT
    NAME,
    DB_UNIQUE_NAME,
    LOG_MODE,
    OPEN_MODE,
    PROTECTION_MODE,
    DATABASE_ROLE
FROM V$DATABASE;

-- If LOG_MODE = NOARCHIVELOG, enable it:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

-- Verify
ARCHIVE LOG LIST;

-- -----------------------------------------------
-- STEP 2: Enable FORCE LOGGING
--         Ensures all changes are logged
--         Required for Data Guard
-- -----------------------------------------------
ALTER DATABASE FORCE LOGGING;

-- Verify
SELECT
    NAME,
    FORCE_LOGGING
FROM V$DATABASE;

-- -----------------------------------------------
-- STEP 3: Set Required Primary Parameters
-- -----------------------------------------------

-- DB Unique Name (must be unique across all DBs)
ALTER SYSTEM SET DB_UNIQUE_NAME = 'COMPANYDB_PRI'
    SCOPE=SPFILE;

-- Enable Flashback (highly recommended)
ALTER SYSTEM SET DB_FLASHBACK_RETENTION_TARGET = 4320
    SCOPE=BOTH;    -- 3 days in minutes

ALTER DATABASE FLASHBACK ON;

-- Archive Log Destination 1 = Local
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1 =
    'LOCATION=USE_DB_RECOVERY_FILE_DEST
     VALID_FOR=(ALL_LOGFILES,ALL_ROLES)
     DB_UNIQUE_NAME=COMPANYDB_PRI'
    SCOPE=BOTH;

-- Archive Log Destination 2 = Standby Server
ALTER SYSTEM SET LOG_ARCHIVE_DEST_2 =
    'SERVICE=COMPANYDB_STB
     ASYNC
     VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
     DB_UNIQUE_NAME=COMPANYDB_STB
     COMPRESSION=ENABLE'
    SCOPE=BOTH;

-- Enable both destinations
ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_1 = ENABLE SCOPE=BOTH;
ALTER SYSTEM SET LOG_ARCHIVE_DEST_STATE_2 = ENABLE SCOPE=BOTH;

-- Set log archive format
ALTER SYSTEM SET LOG_ARCHIVE_FORMAT =
    '%t_%s_%r.arc'
    SCOPE=SPFILE;

-- Maximum number of archive log destinations
ALTER SYSTEM SET LOG_ARCHIVE_MAX_PROCESSES = 4
    SCOPE=BOTH;

-- FAL (Fetch Archive Log) settings
-- Used by standby to request missing archive logs
ALTER SYSTEM SET FAL_SERVER  = 'COMPANYDB_STB' SCOPE=BOTH;
ALTER SYSTEM SET FAL_CLIENT  = 'COMPANYDB_PRI' SCOPE=BOTH;

-- Standby file management
-- AUTO = Oracle manages standby file creation
ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT = AUTO SCOPE=BOTH;

-- Data Guard Broker
ALTER SYSTEM SET DG_BROKER_START = TRUE SCOPE=BOTH;
ALTER SYSTEM SET DG_BROKER_CONFIG_FILE1 =
    '/u01/app/oracle/19c/dbs/dr1COMPANYDB.dat'
    SCOPE=BOTH;
ALTER SYSTEM SET DG_BROKER_CONFIG_FILE2 =
    '/u01/app/oracle/19c/dbs/dr2COMPANYDB.dat'
    SCOPE=BOTH;

-- Remote Login Passwordfile
ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE = EXCLUSIVE
    SCOPE=SPFILE;

-- -----------------------------------------------
-- STEP 4: Add Standby Redo Log Files
--         Size must match online redo logs
--         Number = (online redo log groups + 1)
--         per thread
-- -----------------------------------------------

-- First check current online redo log size
SELECT
    GROUP#,
    MEMBERS,
    BYTES/1024/1024  AS SIZE_MB,
    STATUS
FROM V$LOG;

-- Add Standby Redo Logs
-- (same size as online redo logs)
ALTER DATABASE ADD STANDBY LOGFILE
    GROUP 4 '/u01/oradata/COMPANYDB/srl01.log' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE
    GROUP 5 '/u01/oradata/COMPANYDB/srl02.log' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE
    GROUP 6 '/u01/oradata/COMPANYDB/srl03.log' SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE
    GROUP 7 '/u01/oradata/COMPANYDB/srl04.log' SIZE 200M;

-- Verify Standby Redo Logs
SELECT
    GROUP#,
    DBID,
    STATUS,
    BYTES/1024/1024  AS SIZE_MB
FROM V$STANDBY_LOG;

-- -----------------------------------------------
-- STEP 5: Create Standby Controlfile
--         This will be copied to standby server
-- -----------------------------------------------
ALTER DATABASE CREATE STANDBY CONTROLFILE
    AS '/tmp/standby.ctl';

-- -----------------------------------------------
-- STEP 6: Create PFILE from SPFILE
--         Edit it for standby parameters
-- -----------------------------------------------
CREATE PFILE='/tmp/initCOMPANYDB.ora'
    FROM SPFILE;

-- -----------------------------------------------
-- STEP 7: Verify All Settings
-- -----------------------------------------------
-- Check archive log destinations
SELECT
    DEST_ID,
    DEST_NAME,
    STATUS,
    TARGET,
    ARCHIVER,
    SCHEDULE,
    DESTINATION,
    DB_UNIQUE_NAME
FROM V$ARCHIVE_DEST
WHERE DEST_ID IN (1,2);

-- Check protection mode
SELECT
    NAME,
    DB_UNIQUE_NAME,
    PROTECTION_MODE,
    DATABASE_ROLE,
    SWITCHOVER_STATUS
FROM V$DATABASE;

-- Check Standby Redo Logs
SELECT * FROM V$STANDBY_LOG;

-- Check Flashback is ON
SELECT
    DB_UNIQUE_NAME,
    FLASHBACK_ON
FROM V$DATABASE;
