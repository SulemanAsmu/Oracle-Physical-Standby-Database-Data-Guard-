#!/bin/bash
# =============================================
# Database:    Oracle 19c/21c
# Author:      Suleman
# Description: Planned Switchover Script
--              Switchover = PLANNED role change
--              Zero data loss
--              Can be reversed
-- =============================================

export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

echo "============================================"
echo "       DATA GUARD PLANNED SWITCHOVER"
echo "============================================"
echo ""
echo "⚠️  WARNING: This will switch roles:"
echo "    Current PRIMARY → becomes STANDBY"
echo "    Current STANDBY → becomes PRIMARY"
echo ""
read -p "Are you sure? Type YES to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Switchover cancelled"
    exit 0
fi

# -----------------------------------------------
# METHOD 1: Using DGMGRL (Recommended)
# -----------------------------------------------
switchover_with_broker() {
    echo "Starting Switchover via DGMGRL..."

    dgmgrl sys/your_password@COMPANYDB_PRI << EOF

    -- Verify configuration is healthy
    SHOW CONFIGURATION;
    SHOW DATABASE 'COMPANYDB_PRI';
    SHOW DATABASE 'COMPANYDB_STB';

    -- Validate switchover readiness
    VALIDATE DATABASE 'COMPANYDB_STB';

    -- Perform Switchover
    SWITCHOVER TO 'COMPANYDB_STB';

    -- Verify new roles
    SHOW CONFIGURATION;
    SHOW DATABASE 'COMPANYDB_PRI';
    SHOW DATABASE 'COMPANYDB_STB';

    EXIT;
EOF

    echo "✅ Switchover Completed via Broker"
}

# -----------------------------------------------
# METHOD 2: Manual Switchover (without broker)
# -----------------------------------------------
switchover_manual() {

    echo "=== STEP 1: Verify Primary is Ready ==="
    sqlplus -s sys/your_password@COMPANYDB_PRI as sysdba << EOF
    SELECT SWITCHOVER_STATUS FROM V$DATABASE;
    -- Must show: TO STANDBY or SESSIONS ACTIVE
    EXIT;
EOF

    echo "=== STEP 2: Switch Primary to Standby ==="
    sqlplus -s sys/your_password@COMPANYDB_PRI as sysdba << EOF
    -- Convert primary to standby role
    ALTER DATABASE COMMIT TO SWITCHOVER TO PHYSICAL STANDBY
        WITH SESSION SHUTDOWN;
    EXIT;
EOF

    echo "✅ Primary converted to Standby role"

    echo "=== STEP 3: Shutdown Old Primary ==="
    sqlplus -s sys/your_password@COMPANYDB_PRI as sysdba << EOF
    SHUTDOWN ABORT;
    STARTUP MOUNT;
    EXIT;
EOF

    echo "=== STEP 4: Switch Standby to Primary ==="
    sqlplus -s sys/your_password@COMPANYDB_STB as sysdba << EOF

    -- Check switchover status
    SELECT SWITCHOVER_STATUS FROM V$DATABASE;
    -- Must show: TO PRIMARY or SESSIONS ACTIVE

    -- Convert standby to primary
    ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY
        WITH SESSION SHUTDOWN;

    -- Open new primary
    ALTER DATABASE OPEN;

    -- Verify
    SELECT
        DB_UNIQUE_NAME,
        DATABASE_ROLE,
        OPEN_MODE
    FROM V$DATABASE;

    EXIT;
EOF

    echo "✅ New Primary is OPEN"

    echo "=== STEP 5: Start Apply on New Standby ==="
    sqlplus -s sys/your_password@COMPANYDB_PRI as sysdba << EOF

    -- Open old primary (now standby) in mount
    -- (Should already be in mount from STEP 3)

    -- Start MRP on new standby
    ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
        USING CURRENT LOGFILE
        DISCONNECT FROM SESSION;

    -- Verify
    SELECT PROCESS, STATUS, SEQUENCE#
    FROM V$MANAGED_STANDBY
    WHERE PROCESS LIKE 'MRP%';

    EXIT;
EOF

    echo "✅ New Standby is Applying Logs"
    echo "============================================"
    echo "Switchover Completed Successfully!"
    echo "New PRIMARY: COMPANYDB_STB (standby-srv)"
    echo "New STANDBY: COMPANYDB_PRI (primary-srv)"
    echo "============================================"
}

# Use broker method (recommended)
switchover_with_broker
