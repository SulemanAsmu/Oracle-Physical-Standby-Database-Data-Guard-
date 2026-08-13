#!/bin/bash
# =============================================
# Database:    Oracle 19c/21c
# Author:      Suleman
# Description: Primary Server Shell Setup
#              for Data Guard
# Run On:      PRIMARY SERVER as oracle user
# =============================================

# -----------------------------------------------
# Environment Variables
# -----------------------------------------------
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=COMPANYDB
export PATH=$ORACLE_HOME/bin:$PATH

PRIMARY_HOST="primary-srv"
STANDBY_HOST="standby-srv"
STANDBY_IP="192.168.1.2"
ORACLE_DATA="/u01/oradata/COMPANYDB"
ORACLE_FRA="/u01/fra/COMPANYDB"
TEMP_DIR="/tmp/dataguard_setup"

mkdir -p $TEMP_DIR

echo "============================================"
echo "Primary Server Data Guard Setup"
echo "============================================"

# -----------------------------------------------
# STEP 1: Configure Listener (listener.ora)
# -----------------------------------------------
echo "Configuring Primary Listener..."

cat > $ORACLE_HOME/network/admin/listener.ora << EOF
# Primary Server Listener
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)
                 (HOST = $PRIMARY_HOST)
                 (PORT = 1521))
    )
  )

# Static registration required for Data Guard
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = COMPANYDB_PRI)
      (ORACLE_HOME   = $ORACLE_HOME)
      (SID_NAME      = COMPANYDB)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = COMPANYDB_PRI_DGMGRL)
      (ORACLE_HOME   = $ORACLE_HOME)
      (SID_NAME      = COMPANYDB)
    )
  )

ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER = ON
EOF

echo "✅ Primary listener.ora configured"

# -----------------------------------------------
# STEP 2: Configure TNS (tnsnames.ora)
# -----------------------------------------------
echo "Configuring Primary TNS..."

cat > $ORACLE_HOME/network/admin/tnsnames.ora << EOF
# Primary Database TNS Entry
COMPANYDB_PRI =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)
               (HOST = $PRIMARY_HOST)
               (PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = COMPANYDB_PRI)
    )
  )

# Standby Database TNS Entry
COMPANYDB_STB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)
               (HOST = $STANDBY_HOST)
               (PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = COMPANYDB_STB)
      (UR = A)
    )
  )
EOF

echo "✅ Primary tnsnames.ora configured"

# -----------------------------------------------
# STEP 3: Reload Listener
# -----------------------------------------------
lsnrctl stop
lsnrctl start
lsnrctl status

echo "✅ Listener restarted"

# -----------------------------------------------
# STEP 4: Copy Password File to Standby
#         Both servers must have SAME password file
# -----------------------------------------------
echo "Copying password file to standby server..."

scp $ORACLE_HOME/dbs/orapwCOMPANYDB \
    oracle@$STANDBY_HOST:$ORACLE_HOME/dbs/orapwCOMPANYDB

echo "✅ Password file copied to standby"

# -----------------------------------------------
# STEP 5: Copy Standby Controlfile to Standby
# -----------------------------------------------
echo "Copying standby controlfile..."

scp /tmp/standby.ctl \
    oracle@$STANDBY_HOST:/tmp/standby.ctl

echo "✅ Standby controlfile copied"

# -----------------------------------------------
# STEP 6: Copy PFILE to Standby
# -----------------------------------------------
echo "Copying PFILE to standby..."

scp /tmp/initCOMPANYDB.ora \
    oracle@$STANDBY_HOST:/tmp/initCOMPANYDB.ora

echo "✅ PFILE copied to standby"

# -----------------------------------------------
# STEP 7: Test TNS Connectivity to Standby
# -----------------------------------------------
echo "Testing TNS connection to standby..."

tnsping COMPANYDB_STB

echo "============================================"
echo "Primary Setup Complete!"
echo "Now run 03_standby_setup.sh on standby server"
echo "============================================"
