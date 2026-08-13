#!/bin/bash
# =============================================
# Database:    Oracle 19c/21c
# Author:      Suleman
# Description: Emergency Failover Script
--              Failover = UNPLANNED role change
--              Used when PRIMARY is DOWN
--              ⚠️ Cannot be reversed easily
--              Data loss possible
-- =============================================

export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

echo "============================================"
echo "   ⚠️  DATA GUARD EMERGENCY FAILOVER  ⚠️ "
echo "============================================"
echo ""
echo "ONLY use this when PRIMARY is completely DOWN"
echo "and CANNOT be recovered quickly"
echo ""
echo "⚠️  This may result in DATA LOSS"
echo "⚠️  The old primary cannot rejoin automatically"
echo ""
read -p "Confirm FAILOVER? Type FAILOVER to continue: " CONFIRM

if [ "$CONFIRM" != "FAILOVER" ]; then
    echo "Failover cancelled"
    exit 0
fi

# -----------------------------------------------
# METHOD 1: DGMGRL Failover (Recommended)
# -----------------------------------------------
failover_with_broker() {
    echo "Starting Failover via DGMGRL..."

    dgmgrl sys/your_password@COMPANYDB_STB << EOF

    -- Check configuration
    SHOW CONFIGURATION;

    -- Perform immediate failover
    -- IMMEDIATE = don't wait for logs
    FAILOVER TO 'COMPANYDB_STB' IMMEDIATE;

    -- Verify new primary
    SHOW CONFIGURATION;
    SHOW DATABASE 'COMPANYDB_STB';

    EXIT;
EOF

    echo "✅ Failover Completed"
    echo "New PRIMARY: COMPANYDB_STB"
}

# -----------------------------------------------
# METHOD 2: Manual Failover
-- -----------------------------------------------
failover_manual() {
    echo "=== Starting Manual Failover ==="

    sqlplus -s sys/your_password@COMPANYDB_STB as sysdba << EOF

    -- Step 1: Flush any remaining redo
    ALTER DATABASE RECOVER MANAGED STANDBY DATABASE
        FINISH FORCE;

    -- Step 2: Activate the standby database
    ALTER DATABASE ACTIVATE PHYSICAL STANDBY DATABASE;

    -- Step 3: Open the new primary
    ALTER DATABASE OPEN;

    -- Step 4: Create a new password file if needed
    -- (run from OS: orapwd file=orapwCOMPANYDB password=xxx)

    -- Step 5: Verify
    SELECT
        DB_UNIQUE_NAME,
        DATABASE_ROLE,
        OPEN_MODE,
        SWITCHOVER_STATUS
    FROM V$DATABASE;

    EXIT;
EOF

    echo "✅ New Primary is OPEN and ACTIVE"
    echo ""
    echo "============================================"
    echo "POST FAILOVER ACTIONS REQUIRED:"
    echo "============================================"
    echo "1. Update application connection strings"
    echo "   to point to new primary: standby-srv"
    echo ""
    echo "2. When old primary is fixed, reinstate it"
    echo "   as new standby using RMAN DUPLICATE"
    echo ""
    echo "3. Update monitoring and backup scripts"
    echo ""
    echo "4. Notify team of role change"
    echo "============================================"
}

# Run failover
failover_with_broker
