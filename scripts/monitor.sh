#!/bin/bash

# ==================================================
# 监控脚本 - 检查 LNMP 容器状态，异常时自动重启并记录日志
# 项目：基于 Docker 的 LNMP 运维自动化
# 作者：龚美平
# 日期：2026-03-04
# ==================================================

# 配置参数
PROJECT_DIR="/root/docker-lnmp-project"
LOG_FILE="$PROJECT_DIR/scripts/monitor.log"
CONTAINERS=("lnmp_mysql" "lnmp_php" "lnmp_nginx")

# 记录日志的函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

log "========== 开始监控检查 =========="

# 遍历所有容器
for container in "${CONTAINERS[@]}"; do
    # 检查容器是否运行
    if [ "$(docker inspect -f '{{.State.Running}}' $container 2>/dev/null)" != "true" ]; then
        log "警告：容器 $container 未运行，尝试重启..."
        docker start $container
        if [ $? -eq 0 ]; then
            log "成功重启容器 $container"
        else
            log "错误：重启容器 $container 失败！"
    echo -e "Subject: 容器重启告警\n\n容器 $container 重启失败，请立即检查！" | ssmtp cy5277fsq@163.com
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 告警：容器 $container 重启失败" >> /root/docker-lnmp-project/scripts/alert.log
        fi
    else
        log "正常：容器 $container 正在运行"
    fi
done

log "========== 监控检查结束 =========="
