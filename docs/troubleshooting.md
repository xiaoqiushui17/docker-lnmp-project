# 故障排查记录

## 故障1：MySQL 容器无法启动（端口占用）
- **现象**：`docker-compose up -d` 时报错 `bind: address already in use`
- **排查**：用 `ss -tlnp | grep :3306` 发现宿主机 MariaDB 占用了 3306 端口
- **解决**：停止宿主机 MariaDB 服务 `systemctl stop mariadb && systemctl disable mariadb`
- **启示**：容器化部署前需确保宿主机端口未被占用

## 故障2：PHP 容器缺少 mysqli 扩展
- **现象**：访问 `db.php` 报错 `Class 'mysqli' not found`
- **排查**：进入容器检查 PHP 扩展 `docker exec -it lnmp_php php -m | grep mysqli` 无输出
- **解决**：进入容器执行 `docker-php-ext-install mysqli` 并重启容器
- **启示**：官方镜像可能缺少必要扩展，需自定义

## 故障3：Nginx 容器 80 端口被宿主机 nginx 占用
- **现象**：启动时 `bind: address already in use` on port 80
- **排查**：`ss -tlnp | grep :80` 发现宿主机 nginx 进程
- **解决**：停止宿主机 nginx `systemctl stop nginx`（或 kill 进程）
- **启示**：检查宿主机服务冲突

## 故障4：备份脚本权限问题
- **现象**：备份脚本执行失败，提示无权限写入目录
- **排查**：检查目录权限，发现 backups 目录不存在
- **解决**：脚本中增加 `mkdir -p` 自动创建目录
- **启示**：脚本需考虑健壮性，自动创建依赖目录
