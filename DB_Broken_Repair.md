# Database Broken Repair Guide
# 資料庫損壞修復指南

## Overview 概述

本文檔記錄了當 Telemetry 系統中的 MySQL 資料庫發生損壞時的診斷和修復步驟。主要針對因為斷電、異常關機等原因導致的 InnoDB redo log 檔案損壞問題。

## Common Symptoms 常見症狀

### 1. Container Status Issues 容器狀態問題
```bash
# Check container status
docker ps | grep zabbix

# Typical symptoms:
# - zabbix-web: Up XX minutes (unhealthy)
# - zabbix-db: Restarting (1) XX seconds ago
```

### 2. Connection Errors 連線錯誤
- Zabbix Web 介面無法存取 (ERR_CONNECTION_REFUSED)
- Grafana 無法連接到 Zabbix 資料源
- Web 容器日誌顯示：`MySQL server is not available. Waiting 5 seconds...`

### 3. Database Log Errors 資料庫日誌錯誤
```bash
# Check MySQL container logs
docker logs kevin-telemetry-zabbix-db --tail 20

# Common error patterns:
# [ERROR] [MY-013882] [InnoDB] Missing redo log file ./#innodb_redo/#ib_redoXXX
# [ERROR] [MY-012930] [InnoDB] Plugin initialization aborted with error Generic error
# [ERROR] [MY-010334] [Server] Failed to initialize DD Storage Engine
```

## Diagnostic Steps 診斷步驟

### Step 1: Check Container Status 檢查容器狀態
```bash
# Check all telemetry containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kevin-telemetry

# Check specific zabbix containers
docker ps | grep zabbix
```

### Step 2: Examine Container Logs 檢查容器日誌
```bash
# Check Zabbix Web logs
docker logs kevin-telemetry-zabbix-web --tail 20

# Check MySQL database logs
docker logs kevin-telemetry-zabbix-db --tail 20

# Check Zabbix Server logs
docker logs kevin-telemetry-zabbix-server --tail 20
```

### Step 3: Verify Network Connectivity 驗證網路連通性
```bash
# Check if port 8080 is listening
netstat -tlnp | grep :8080

# Test HTTP connectivity
curl -I http://100.64.0.113:8080
```

### Step 4: Inspect Database Volume 檢查資料庫 Volume
```bash
# Get volume information
docker volume inspect telemetry_zabbix_db_data

# Check redo log files (if accessible)
sudo ls -la /var/lib/docker/volumes/telemetry_zabbix_db_data/_data/#innodb_redo/
```

## Repair Procedures 修復程序

### Method 1: Restore from Backup (Recommended) 從備份還原（推薦）

#### Step 1: Stop All Containers 停止所有容器
```bash
cd /home/ella/kevin/telemetry
docker-compose down
```

#### Step 2: Remove Corrupted Database Volume 移除損壞的資料庫 Volume
```bash
# Remove the corrupted volume
docker volume rm telemetry_zabbix_db_data

# Verify removal
docker volume ls | grep telemetry
```

#### Step 3: Restore from Latest Backup 從最新備份還原
```bash
# Navigate to the latest backup directory
cd backups/
ls -la | tail -5  # Find the latest backup

# Go to the latest backup directory (example)
cd telemetry_backup_YYYYMMDD_HHMMSS

# Run the restore script
./restore.sh
```

#### Step 4: Restart All Services 重新啟動所有服務
```bash
# Return to main directory
cd /home/ella/kevin/telemetry

# Start all containers
docker-compose up -d
```

#### Step 5: Verify Recovery 驗證恢復
```bash
# Wait for containers to fully start
sleep 30

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test web interface connectivity
curl -I http://100.64.0.113:8080

# Check for healthy status
docker ps | grep zabbix-web | grep healthy
```

### Method 2: Manual Database Recovery (Advanced) 手動資料庫恢復（進階）

⚠️ **Warning**: Only use this method if backup restoration fails or is not available.

#### Step 1: Stop Database Container 停止資料庫容器
```bash
docker stop kevin-telemetry-zabbix-db
```

#### Step 2: Create Temporary Recovery Container 創建臨時恢復容器
```bash
# Start MySQL with recovery mode
docker run -d --name mysql-recovery \
  -v telemetry_zabbix_db_data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=zabbix \
  mysql:8.0 --innodb-force-recovery=1
```

#### Step 3: Export Data 匯出資料
```bash
# Wait for container to start
sleep 10

# Export database
docker exec mysql-recovery mysqldump -u root -pzabbix zabbix > zabbix_recovery.sql
```

#### Step 4: Recreate Database 重新創建資料庫
```bash
# Stop recovery container
docker stop mysql-recovery
docker rm mysql-recovery

# Remove corrupted volume
docker volume rm telemetry_zabbix_db_data

# Restart normal database container
docker-compose up -d kevin-telemetry-zabbix-db

# Wait for initialization
sleep 30

# Import recovered data
docker exec -i kevin-telemetry-zabbix-db mysql -u root -pzabbix zabbix < zabbix_recovery.sql
```

## Prevention Measures 預防措施

### 1. Regular Backups 定期備份
```bash
# Set up automated backup (if not already configured)
./setup_automated_backup.sh

# Manual backup
./backup_telemetry_data.sh
```

### 2. Graceful Shutdown 優雅關機
```bash
# Always use proper shutdown sequence
docker-compose down

# For system shutdown, ensure Docker service stops gracefully
sudo systemctl stop docker
```

### 3. UPS Protection UPS 保護
- Install Uninterruptible Power Supply (UPS) for critical systems
- Configure automatic shutdown scripts for low battery conditions

### 4. Health Monitoring 健康監控
```bash
# Regular health checks
./container_stats.sh

# Monitor container logs
./check_and_restore_containers.sh
```

## Troubleshooting Tips 故障排除提示

### Issue: Containers Keep Restarting 容器持續重啟
```bash
# Check resource usage
docker stats

# Check system resources
df -h
free -h

# Check Docker daemon logs
sudo journalctl -u docker.service --tail 50
```

### Issue: Backup Restoration Fails 備份還原失敗
```bash
# Verify backup integrity
cd backups/telemetry_backup_YYYYMMDD_HHMMSS/volumes
ls -la *.tar.gz

# Test backup files
tar -tzf zabbix_db_data.tar.gz | head -10

# Manual volume restoration
docker run --rm -v telemetry_zabbix_db_data:/data -v $(pwd):/backup ubuntu tar xzf /backup/zabbix_db_data.tar.gz -C /data
```

### Issue: Permission Problems 權限問題
```bash
# Fix volume permissions
sudo chown -R 999:999 /var/lib/docker/volumes/telemetry_zabbix_db_data/_data

# Check container user
docker exec kevin-telemetry-zabbix-db id mysql
```

## Recovery Time Estimates 恢復時間估計

- **Backup Restoration**: 5-10 minutes
- **Manual Recovery**: 20-30 minutes  
- **Full System Restart**: 2-5 minutes
- **Data Verification**: 5-10 minutes

## Contact Information 聯絡資訊

For additional support or complex recovery scenarios, refer to:
- System Administrator: [Contact Details]
- Backup Location: `/home/ella/kevin/telemetry/backups/`
- Log Files: Container logs via `docker logs [container-name]`

## Changelog 更新記錄

- **2025-09-18**: Initial version created after InnoDB redo log corruption incident
- Document covers MySQL 8.0 InnoDB recovery procedures
- Tested on Ubuntu system with Docker Compose

---

**Note**: Always test recovery procedures in a development environment before applying to production systems.
