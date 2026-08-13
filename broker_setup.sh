#!/bin/bash
# =============================================
# Database:    Oracle 19c/21c
# Author:      Suleman
# Description: Data Guard Broker Setup
--              dgmgrl simplifies management
--              switchover and failover
-- Run On:      PRIMARY SERVER
-- =============================================

export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

echo "============================================"
echo "Data Guard Broker Configuration"
echo "============================================"

dgmgrl sys/your_password@COMPANYDB_PRI << EOF

-- -----------------------------------------------
-- Create Broker Configuration
-- -----------------------------------------------
CREATE CONFIGURATION 'DG_COMPANYDB'
    AS PRIMARY DATABASE IS 'COMPANYDB_PRI'
    CONNECT IDENTIFIER IS COMPANYDB_PRI;

-- Add Standby Database to Configuration
ADD DATABASE 'COMPANYDB_STB'
    AS CONNECT IDENTIFIER IS COMPANYDB_STB
    MAINTAINED AS PHYSICAL;

-- -----------------------------------------------
-- Enable the Configuration
-- -----------------------------------------------
ENABLE CONFIGURATION;

-- -----------------------------------------------
-- Verify Configuration
-- -----------------------------------------------
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE 'COMPANYDB_PRI';
SHOW DATABASE VERBOSE 'COMPANYDB_STB';

-- -----------------------------------------------
-- Set Protection Mode
-- Options:
--   MaxPerformance  (default - async shipping)
--   MaxAvailability (sync - near zero data loss)
--   MaxProtection   (sync - zero data loss)
-- -----------------------------------------------
EDIT CONFIGURATION
    SET PROTECTION MODE AS MaxAvailability;

-- Verify protection mode
SHOW CONFIGURATION;

EXIT;
EOF

echo "✅ Data Guard Broker Configured"
