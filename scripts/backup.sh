#!/bin/bash

# ==================================================
# 备份脚本 - 备份 MySQL 数据库和网站文件
# 项目：基于 Docker 的 LNMP 运维自动化
# 作者：龚美平
# 日期：2026-03-04
# ==================================================

# 配置参数
BACKUP_BASE="/root/docker-lnmp-project/backups"
MYSQL_CONTAINER="lnmp_mysql"
MYSQL_USER="root"
MYSQL_PASSWORD="517127"          
WEB_DIR="/root/docker-lnmp-project/html"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 创建备份目录（如果不存在）
mkdir -p $BACKUP_BASE/{mysql,web}

# 备份 MySQL 所有数据库
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份 MySQL 数据库..."
docker exec $MYSQL_CONTAINER mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --all-databases > $BACKUP_BASE/mysql/mysql_$DATE.sql
if [ $? -eq 0 ]; then
    echo "MySQL 备份成功: $BACKUP_BASE/mysql/mysql_$DATE.sql"
    # 压缩备份文件以节省空间
    gzip $BACKUP_BASE/mysql/mysql_$DATE.sql
else
    echo "MySQL 备份失败！"
    exit 1
fi

# 备份网站文件
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份网站文件..."
tar -czf $BACKUP_BASE/web/web_$DATE.tar.gz -C $(dirname $WEB_DIR) $(basename $WEB_DIR)
if [ $? -eq 0 ]; then
    echo "网站文件备份成功: $BACKUP_BASE/web/web_$DATE.tar.gz"
else
    echo "网站文件备份失败！"
    exit 1
fi

# 删除超过保留天数的旧备份
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理超过 $RETENTION_DAYS 天的旧备份..."
find $BACKUP_BASE/mysql -name "mysql_*.sql.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_BASE/web -name "web_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份任务完成！"
