#!/bin/bash

# 告警脚本 - 模拟发送告警（实际可扩展为邮件/钉钉）
# 用法：./alert.sh "告警内容"

MESSAGE="$1"
LOG_FILE="/root/docker-lnmp-project/scripts/alert.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 告警：$MESSAGE" >> $LOG_FILE
