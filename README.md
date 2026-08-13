# Oracle Data Guard - Physical Standby Setup

## 🏗️ Architecture Overview

## 📋 Environment Details

| Item                | Primary              | Standby              |
|--------------------|----------------------|----------------------|
| Hostname            | primary-srv          | standby-srv          |
| IP Address          | 192.168.1.1          | 192.168.1.2          |
| DB Name (db_name)   | COMPANYDB            | COMPANYDB            |
| DB Unique Name      | COMPANYDB_PRI        | COMPANYDB_STB        |
| Oracle SID          | COMPANYDB            | COMPANYDB            |
| Oracle Home         | /u01/app/oracle/19c  | /u01/app/oracle/19c  |
| Data Files          | /u01/oradata         | /u01/oradata         |
| FRA                 | /u01/fra             | /u01/fra             |
| Listener Port       | 1521                 | 1521                 |
| Oracle Version      | 19c                  | 19c                  |

## 🔄 Data Guard Protection Modes

| Mode               | Data Loss Risk | Performance Impact | Use Case              |
|-------------------|----------------|--------------------|-----------------------|
| Maximum Protection | Zero           | High               | Financial/Critical    |
| Maximum Availability| Near Zero     | Medium             | Most Production       |
| Maximum Performance | Some          | Low                | Less Critical         |

## 📝 Setup Steps Summary

1. Prepare Primary Database
2. Configure Primary Parameters
3. Configure Primary Listener and TNS
4. Create Standby Controlfile and PFILE
5. Copy Files to Standby Server
6. Configure Standby Listener and TNS
7. Start and Configure Standby
8. Verify Redo Apply is Working
9. Configure Data Guard Broker (Optional)
10. Test Switchover and Failover

## ⚠️ Prerequisites
- Both servers have Oracle 19c installed
- Same Oracle version on both servers
- Network connectivity between servers
- Sufficient disk space on standby
- SSH access between servers
- Oracle user setup on both servers
