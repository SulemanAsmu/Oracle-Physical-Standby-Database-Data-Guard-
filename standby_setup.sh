#!/bin/bash
# =============================================
# Database:    Oracle 19c/21c
# Author:      Suleman
# Description: Standby Server Setup
#              for Data Guard Physical Standby
# Run On:      STANDBY SERVER as oracle user
# =============================================

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=COMPANYDB
export PATH=$ORACLE_HOME/bin:$PATH

PRIMARY_HOST="primary-srv"
STANDBY_HOST="standby-srv"
ORACLE_DATA="/u01/oradata/COMPANYDB"
ORACLE_FRA="/u01/fra/COMPANYDB"
ORACLE_ADMIN="/u01/app/oracle/admin/COMPANYDB"

echo "============================================"
echo "Standby Server Data Guard Setup"
echo "============================================"

# -----------------------------------------------
# STEP 1: Create Required Directories
# -----------------------------------------------
echo "Creating directories..."

mkdir -p $ORACLE_DATA
mkdir -p $ORACLE_FRA
mkdir -p $ORACLE_ADMIN/adump
mkdir -p $ORACLE_ADMIN/cdump
mkdir -p $ORACLE_HOME/dbs

echo "✅ Directories created"

# -----------------------------------------------
# STEP 2: Configure Standby Listener
# -----------------------------------------------
echo "Configuring Standby Listener..."

cat > $ORACLE_HOME/network/admin/listener.ora << EOF
# Standby Server Listener
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)
                 (HOST = $STANDBY_HOST)
                 (PORT = 1521))
    )
  )

# Static registration - REQUIRED for Data Guard
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = COMPANYDB_STB)
      (ORACLE_HOME   = $ORACLE_HOME)
      (SID_NAME      = COMPANYDB)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = COMPANYDB_STB_DGMGRL)
      (ORACLE_HOME   = $ORACLE_HOME)
      (SID_NAME      = COMPANYDB)
    )
  )

ENABLE_GLOBAL_DYNAMIC_ENDPOINT_LISTENER = ON
EOF

echo "✅ Standby listener.ora configured"

# -----------------------------------------------
# STEP 3: Configure Standby TNS
# -----------------------------------------------
cat > $ORACLE_HOME/network/admin/tnsnames.ora << EOF
# Primary Database
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

# Standby Database
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

echo "✅ Standby tnsnames.ora configured"

# -----------------------------------------------
# STEP 4: Start Standby Listener
# -----------------------------------------------
lsnrctl stop
lsnrctl start
lsnrctl status

echo "✅ Standby listener started"

# -----------------------------------------------
# STEP 5: Create Standby PFILE
#         Edit the copied primary PFILE
# -----------------------------------------------
echo "Creating Standby PFILE..."

cat > $ORACLE_HOME/dbs/initCOMPANYDB.ora << EOF
# =============================================
# Standby Database PFILE
# Generated for Data Guard Physical Standby
# =============================================

# Database Identification
*.db_name                    = 'COMPANYDB'
*.db_unique_name             = 'COMPANYDB_STB'
*.db_domain                  = ''

# Memory Settings (adjust based on your server)
*.sga_target                 = 2G
*.pga_aggregate_target       = 512M
*.memory_target              = 0

# File Locations
*.db_create_file_dest        = '$ORACLE_DATA'
*.db_recovery_file_dest      = '$ORACLE_FRA'
*.db_recovery_file_dest_size = 50G

# Archive Log Settings
*.log_archive_format         = '%t_%s_%r.arc'
*.log_archive_max_processes  = 4

# Archive Destinations
*.log_archive_dest_1         = 'LOCATION=USE_DB_RECOVERY_FILE_DEST
                                VALID_FOR=(ALL_LOGFILES,ALL_ROLES)
                                DB_UNIQUE_NAME=COMPANYDB_STB'

*.log_archive_dest_2         = 'SERVICE=COMPANYDB_PRI
                                ASYNC
                                VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE)
                                DB_UNIQUE_NAME=COMPANYDB_PRI
                                COMPRESSION=ENABLE'

*.log_archive_dest_state_1   = ENABLE
*.log_archive_dest_state_2   = ENABLE

# FAL Settings (for gap resolution)
*.fal_server                 = 'COMPANYDB_PRI'
*.fal_client                 = 'COMPANYDB_STB'

# Standby Specific
*.standby_file_management    = 'AUTO'

# Data Guard Broker
*.dg_broker_start            = TRUE
*.dg_broker_config_file1     = '$ORACLE_HOME/dbs/dr1COMPANYDB.dat'
*.dg_broker_config_file2     = '$ORACLE_HOME/dbs/dr2COMPANYDB.dat'

# Security
*.remote_login_passwordfile  = 'EXCLUSIVE'

# Audit
*.audit_trail                = 'DB'
*.audit_file_dest            = '$ORACLE_ADMIN/adump'

# Diagnostics
*.diagnostic_dest            = '$ORACLE_BASE'

# Redo Log Conversion
# If primary and standby have different paths
*.db_file_name_convert       = '/u01/oradata/COMPANYDB',
                               '/u01/oradata/COMPANYDB'
*.log_file_name_convert      = '/u01/oradata/COMPANYDB',
                               '/u01/oradata/COMPANYDB'
EOF

echo "✅ Standby PFILE created"

# -----------------------------------------------
# STEP 6: Copy Controlfile to Correct Location
# -----------------------------------------------
echo "Placing standby controlfile..."

cp /tmp/standby.ctl $ORACLE_DATA/control01.ctl
cp /tmp/standby.ctl $ORACLE_DATA/control02.ctl

echo "✅ Controlfiles placed"

# -----------------------------------------------
# STEP 7: Start Standby in NOMOUNT
# -----------------------------------------------
echo "Starting Standby database in NOMOUNT..."

sqlplus -s / as sysdba << EOF
STARTUP NOMOUNT PFILE='$ORACLE_HOME/dbs/initCOMPANYDB.ora';
EXIT;
EOF

echo "✅ Standby started in NOMOUNT"

# -----------------------------------------------
# STEP 8: Mount Standby with Controlfile
# -----------------------------------------------
echo "Mounting standby database..."

sqlplus -s / as sysdba << EOF
ALTER DATABASE MOUNT STANDBY DATABASE;
EXIT;
EOF

echo "✅ Standby mounted"

echo "============================================"
echo "Standby Shell Setup Complete!"
echo "Now run 04_standby_setup.sql on STANDBY"
echo "============================================"
