#!/bin/bash
# Journald 日誌清理腳本
# 功能：清理 systemd-journald 日誌，保留最近 30 天的記錄

set -e

echo "=========================================="
echo "Journald 日誌清理工具"
echo "=========================================="
echo ""

# 顯示清理前的狀態
echo "【清理前狀態】"
echo "----------------------------------------"
BEFORE_SIZE=$(journalctl --disk-usage --no-pager -q 2>/dev/null | grep -o '[0-9.]*[MG]' || echo "未知")
echo "Journald 日誌大小: $BEFORE_SIZE"
echo ""
df -h / | tail -1 | awk '{printf "硬碟使用: %s / %s (剩餘: %s, 使用率: %s)\n", $3, $2, $4, $5}'
echo ""

# 執行清理（保留 30 天）
echo "【執行清理】"
echo "----------------------------------------"
echo "正在清理超過 30 天的日誌記錄..."
sudo journalctl --vacuum-time=30d

echo ""
echo "【清理後狀態】"
echo "----------------------------------------"
AFTER_SIZE=$(journalctl --disk-usage --no-pager -q 2>/dev/null | grep -o '[0-9.]*[MG]' || echo "未知")
echo "Journald 日誌大小: $AFTER_SIZE"
echo ""
df -h / | tail -1 | awk '{printf "硬碟使用: %s / %s (剩餘: %s, 使用率: %s)\n", $3, $2, $4, $5}'
echo ""

echo "=========================================="
echo "清理完成！"
echo "=========================================="

