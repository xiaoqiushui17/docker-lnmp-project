#docker-lnmp-project搭建记录
本项目用于在基于Docker的LNMP集群运维自动化。以下是我执行的每一步命令以及遇到的问题和解决方法。
---

第一步：安装必要工具（docker、git）


##卸载旧版本（如果有残留）
- 命令: yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 
- 作用: yum remove确保没有旧版本干扰

##安装必要工具（yum-utils提供yum-config-manager）
- 命令: yum install -y yum-utils
- 作用：安装工具包，里面包含yum-config-manager,用来管理yum源

##设置Docker的yum源（使用阿里云镜像，国内下载快）
- 命令: yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
- 作用: 把Docker官方的yum源添加到系统中，这里用了阿里云镜像，下载速度快

##安装Docker引擎
- 命令:  yum install -y docker-ce docker-ce-cli containerd.io
- 作用: 安装Docker社区版（CE）及其依赖

##启动 Docker 并设置开机自启
- 命令: systemctl start docker && systemctl enable docker

##验证安装
- 命令: docker --version
- 作用: 检查是否安装成功，输出Docker version 26.1.4, build 5650f9b的版本号

##安装Git
- 命令: yum install -y git
- 作用：Git 用来版本控制，后面我们要把项目推送到 GitHub，需要它。

##验证安装
- 命令：git --version

第二步：安装 Docker Compose


### 下载 Docker Compose 二进制文件
- 命令：wget -O /usr/local/bin/docker-compose https://mirrors.aliyun.com/docker-toolbox/linux/compose/1.21.2/docker-compose-Linux-x86_64（官网）
- 作用：Docker Compose 是一个单独的工具，用来定义和运行多容器 Docker 应用。

##查看文件类型（确认是二进制）
- 命令：file /usr/local/bin/docker-compose
- 输出类似：/usr/local/bin/docker-compose: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), dynamically linked ...

##赋予可执行权限
- 命令：chmod +x /usr/local/bin/docker-compose

##验证版本
- 命令：docker-compose --version

第三步：测试 Docker 是否正常工作


- 命令：docker run hello-world
- 作用：执行一个 hello-world 容器，确保 Docker 能正常拉取镜像并运行
- 出现问题：镜像找不到
- 解决方法：先拉取镜像，我用的是华为云的镜像加速器（登录华为云——>容器镜像服务SWR——>复制加速器地址）
- 命令： vim /etc/docker/daemon.json
- 写入：{
    "registry-mirrors": [ "我的加速器地址" ]
}
- 重启doccker、拉取镜像：systemctl restart docker && docker info && docker pull hello-world && docker run hello-world

第一阶段：用 Docker Compose 部署 LNMP 环境（Nginx + PHP-FPM + MySQL）


##第一步：创建项目目录结构
- 作用：在项目文件夹下创建以下子目录，用于存放网站代码、Nginx 配置、MySQL 数据
- 命令：cd /root/docker-lnmp-project 
        mkdir -p html nginx/conf.d mysql/data
- 解释：html：存放网站文件（如 index.php、info.php）
        nginx/conf.d：存放自定义的 Nginx 虚拟主机配置文件
        mysql/data：MySQL 数据库文件（持久化存储）

##第二步：编写 docker-compose.yml
- 命令：vim docker-compose.yml
- 内容：version: '3'

services:
  mysql:
    image: mysql:5.7
    container_name: lnmp_mysql
    restart: always
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: 517127
      MYSQL_DATABASE: wordpress
    volumes:
      - ./mysql/data:/var/lib/mysql
    networks:
      - lnmp_network

  php:
    image: php:7.4-fpm
    container_name: lnmp_php
    restart: always
    volumes:
      - ./html:/var/www/html
    networks:
      - lnmp_network
    depends_on:
      - mysql

  nginx:
    image: nginx:alpine
    container_name: lnmp_nginx
    restart: always
    ports:
      - "80:80"
    volumes:
      - ./html:/var/www/html
      - ./nginx/conf.d:/etc/nginx/conf.d
    networks:
      - lnmp_network
    depends_on:
      - php

networks:
  lnmp_network:
    driver: bridge
- 解释：version: '3'：docker-compose 文件格式版本。
        services：定义三个服务（容器）。
        mysql：
          image: mysql:5.7：使用 MySQL 5.7 镜像。
             restart: always：容器退出时自动重启。
             ports: "3306:3306"：将容器的 3306 端口映射到宿主机的 3306 端口，方便外部连接（如 Navicat）。
             environment：设置环境变量，初始化 root 密码和数据库。
             volumes：将宿主机的 ./mysql/data 挂载到容器内的 /var/lib/mysql，实现数据持久化。
        php：
          image: php:7.4-fpm：PHP-FPM 镜像。
             volumes：将 ./html 挂载到容器内的网站根目录 /var/www/html，这样 Nginx 和 PHP 都能访问同一份代码。
             depends_on：确保 MySQL 先启动（但 PHP 不会等待 MySQL 完全就绪，只是启动顺序控制）。
        nginx:
          image: nginx:alpine：轻量级 Nginx 镜像。
             ports: "80:80"：将宿主机 80 端口映射到容器 80 端口。
             volumes：挂载网站代码目录和自定义 Nginx 配置目录。
             networks：创建一个名为 lnmp_network 的桥接网络，三个容器都在这个网络中，可以通过服务名互相通信（例如 Nginx 可以通过 php:9000 访问 PHP-FPM）。

##第三步：添加 Nginx 配置文件
- 作用：为了让 Nginx 能够处理 PHP 请求，需要编写一个虚拟主机配置文件。在 nginx/conf.d 目录下创建 default.conf
- 命令：vim nginx/conf.d/default.conf
- 内容：
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;          # php 是服务名，对应 PHP-FPM 容器
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
- 解释：fastcgi_pass php:9000：将 PHP 请求转发到名为 php 的容器（即 PHP-FPM 服务）的 9000 端口。
        fastcgi_param SCRIPT_FILENAME：指定要执行的 PHP 文件路径，$document_root 对应 /var/www/html。

##第四步：创建一个简单的 PHP 测试文件
- 命令： vim html/index.php
- 内容：
<?php
phpinfo();
?>
- 再创建一个 info.php 用来测试数据库连接
- 命令： vim html/db.php
- 内容：
<?php
$servername = "mysql";
$username = "root";
$password = "517127";

// 创建连接
$conn = new mysqli($servername, $username, $password);

// 检查连接
if ($conn->connect_error) {
    die("连接失败: " . $conn->connect_error);
}
echo "MySQL 连接成功！";
?>

##第五步：启动容器
- 命令：docker-compose up -d
- 解释：-d 表示后台运行。首次启动会拉取镜像（mysql:5.7, php:7.4-fpm, nginx:alpine），可能需要几分钟，取决于网络速度。
- 出现问题1：宿主机 3306 端口已被占用，导致 MySQL 容器无法启动。
- 解决方法：找出占用 3306 端口的进程——>ss -tlnp | grep :3306
            发现：宿主机上已经运行了一个 MySQL 服务（pid=17929），占用了 3306 端口，导致容器内的 MySQL 无法绑                   定同一个端口。
            找出正确的服务名：systemctl list-units --type=service | grep -E 'mysql|mariadb'
            宿主机上运行的是 MariaDB 服务，systemd 服务名是 mariadb.service，所以停止并禁用
            - 命令：systemctl stop mariadb && systemctl disable mariadb
- 出现问题2：宿主机上 9000 端口被占用，导致 PHP-FPM 容器无法启动。
- 解决方法：找出占用端口的进程并处理——>ss -tlnp | grep :9000
            发现：宿主机上的 php-fpm 占用了 9000 端口。
            修改 docker-compose.yml，去掉 PHP 容器的端口映射。
            cd /root/docker-lnmp-project
            cp docker-compose.yml docker-compose.yml.bak（备份当前 docker-compose.yml，防止改错）
            vim docker-compose.yml（找到 php 服务部分，将 ports: 及其下一行 - "9000:9000" 删除，或者用 # 注释掉这两行。）
            先删除之前创建失败的 PHP 容器（避免残留）：docker-compose rm -f php
- 出现问题3：宿主机上 80 端口被占用，导致 Nginx 容器无法绑定。
- 解决方法：找出占用 80 端口的进程——>ss -tlnp | grep :80
            宿主机上运行着 nginx 服务（PID 46390、46391、46392），占用了 80 端口。我们需要停止这个 nginx 服务，释放端口。
            停止 nginx 服务：systemctl stop nginx（如果提示 Failed to stop nginx.service: Unit nginx.service not loaded.，说明 systemd 没有管理这个 nginx，可以直接杀掉进程：kill -9 46390 46391 46392）
            禁用开机自启：systemctl disable nginx

## 重新启动 Docker 容器
- 命令：docker-compose up -d（cd /root/docker-lnmp-project）

##检查容器状态
- 命令：docker-compose ps
- 返回：三个容器都是 Up 状态。

## 测试访问
- 命令：curl http://localhost
- 再测试数据库连接
- 命令：curl http://localhost/db.php
- 出现问题：PHP 容器缺少 mysqli 扩展
- 解决方法：重新创建 MySQL 容器（使密码生效）
            先停止并删除当前 MySQL 容器（数据卷保留，数据不会丢）
       - 命令：docker-compose stop mysql && docker-compose rm -f mysql
            然后重新启动所有容器and检查状态
            进入 PHP 容器安装 mysqli 扩展，因为PHP 7.4-fpm 官方镜像默认没有安装 mysqli 扩展，需要手动安装。          - 命令： docker exec -it lnmp_php bash
            更新软件源（容器内可能没有更新）
       - 命令：apt-get update
            安装必要的依赖
       - 命令：apt-get install -y libmysqlclient-dev
            安装 mysqli 扩展
       - 命令：docker-php-ext-install mysqli
            安装成功后，会提示 extension=mysqli.so 已启用。退出容器。
            重启 PHP 容器使扩展生效
       - 命令：docker restart lnmp_php
            最后再测试db.php and 验证 index.php


第二阶段：编写自动化运维脚本，实现备份、监控和故障恢复，模拟真实运维场景。


## 第一步：创建脚本目录
- 命令：cd /root/docker-lnmp-project
        mkdir scripts（用来存放我们编写的备份脚本、监控脚本等）
        cd scripts

##第二步：编写备份脚本
- 命令： vim backup.sh
- 内容：
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

- 解释：BACKUP_BASE：备份文件存放的根目录。
        MYSQL_CONTAINER：MySQL 容器的名称（与 docker-compose.yml 中定义的 container_name 一致）。
        MYSQL_USER 和 MYSQL_PASSWORD：MySQL 的用户名和密码（我的是 517127）。
        WEB_DIR：网站文件所在目录。
        DATE：当前时间，格式如 20260304_143050，用于给备份文件命名。
        RETENTION_DAYS：保留备份的天数，超过此天数的旧备份会被删除。
        docker exec $MYSQL_CONTAINER：在运行的 MySQL 容器中执行命令。
        mysqldump -u$MYSQL_USER -p$MYSQL_PASSWORD --all-databases：执行 MySQL 的备份命令，导出所有数据库。
        > $BACKUP_BASE/mysql/mysql_$DATE.sql：将导出的内容重定向到指定的 SQL 文件中。
        $? 获取上一条命令的退出状态码，0 表示成功，非 0 表示失败。
        如果 mysqldump 成功（$? -eq 0），则打印成功信息，并用 gzip 压缩备份文件以节省空间。
        如果失败，打印错误信息并退出脚本（exit 1）
        tar -czf：创建压缩归档文件，c 创建，z 通过 gzip 压缩，f 指定文件名。
        -C $(dirname $WEB_DIR)：先切换到网站目录的父目录（即 /root/docker-lnmp-project），然后打包 html 目录
        $(basename $WEB_DIR)：提取 html 目录名，这样打包出来的文件内容直接是 html/...，而不是包含完整路径。
        find 命令在指定目录下查找文件。
        -name "mysql_*.sql.gz"：匹配以 mysql_ 开头、以 .sql.gz 结尾的文件。
        -mtime +$RETENTION_DAYS：文件的修改时间超过 $RETENTION_DAYS 天（即 7 天前）。
        -delete：删除找到的文件。

##赋予执行权限
- 命令：chmod +x backup.sh

##第三步：手动测试备份脚本
- 命令：mkdir -p /root/docker-lnmp-project/backups
- 执行脚本：./backup.sh

##第四步：设置定时任务（cron）
- 命令：crontab -e
- 内容：0 2 * * * /root/docker-lnmp-project/scripts/backup.sh >> /root/docker-lnmp-project/backups/backup.log 2>&1（每天凌晨 2 点执行备份，日志记录到指定文件）
- 解释：0 2 * * *：cron 时间表达式，表示每天凌晨 2 点整执行。
        /root/docker-lnmp-project/scripts/backup.sh：要执行的脚本路径。
        >> /root/docker-lnmp-project/backups/backup.log：将脚本的标准输出追加到 backup.log 文件。
        2>&1：将标准错误（2）重定向到标准输出（1），即错误信息也写入同一个日志文件。

##第五步：编写监控脚本
- 命令：cd /root/docker-lnmp-project/scripts
        vim monitor.sh
- 内容：
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
        fi
    else
        log "正常：容器 $container 正在运行"
    fi
done

log "========== 监控检查结束 =========="

- 解释：for container in "${CONTAINERS[@]}"：遍历容器列表。
        docker inspect -f '{{.State.Running}}' $container 2>/dev/null：使用 docker inspect 获取容器的运行状态，-f 指定输出格式，只输出 true 或 false。错误输出（如容器不存在）重定向到 /dev/null 忽略。
       如果输出不是 "true"，说明容器未运行，则记录警告并尝试用 docker start 重启容器。根据重启是否成功记录相应日志。
       如果容器正在运行，记录正常状态。
## 赋予执行权限
- 命令：chmod +x monitor.sh

##第六步：手动测试监控脚本
- 执行脚本：./monitor.sh
- 查看日志文件：cat monitor.log
- 故意停止一个容器测试脚本是否自动重启：docker stop lnmp_nginx && ./monitor.sh

##第七步：设置监控定时任务
- 命令：crontab -e
- 内容：*/5 * * * * /root/docker-lnmp-project/scripts/monitor.sh
- 解释：*/5 表示每 5 分钟执行一次，即 0,5,10,... 分钟时运行。

##第八步：编写告警脚本
- 命令：cd /root/docker-lnmp-project/scripts
        vim alert.sh
- 内容：
#!/bin/bash

# 告警脚本 - 模拟发送告警（实际可扩展为邮件/钉钉）
# 用法：./alert.sh "告警内容"

MESSAGE="$1"
LOG_FILE="/root/docker-lnmp-project/scripts/alert.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 告警：$MESSAGE" >> $LOG_FILE

- 赋予权限
- 命令：chmod +x alert.sh
- 测试：./alert.sh "CPU 负载过高"
        cat alert.log

##第九步：故障演练与排查文档
- 命令：cd /root/docker-lnmp-project
        mkdir docs
        vim docs/troubleshooting.md
- 内容：# 故障排查记录

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

-----------------------------------------
完善——>1.添加 Prometheus + Grafana 监控
作用：实时监控宿主机和容器的性能指标（CPU、内存、磁盘、网络等），并通过 Grafana 可视化仪表盘展示，替代你目前的简单监控脚本，让监控更专业、更直观。
新增组件：
Prometheus：监控数据采集和存储
Grafana：数据可视化展示
Node Exporter：采集宿主机指标（CPU、内存、磁盘等）
2.添加 CI/CD（GitHub Actions）
作用：每次你推送代码到 GitHub 时，自动构建自定义 Docker 镜像并推送到 Docker Hub，展示自动化部署能力。
新增组件：
GitHub Actions workflow 文件
---------------------------------------
第一步：备份当前的 docker-compose.yml（保险点）
- 命令：cp docker-compose.yml docker-compose.yml.bak.$(date +%Y%m%d)
第二步：编辑 docker-compose.yml 添加监控服务
1.在最后一行也就是networks:之前加：
prometheus:
  image: prom/prometheus:latest
  container_name: prometheus
  restart: always
  volumes:
    - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  ports:
    - "9090:9090"
  networks:
    - lnmp_network
grafana:
  image: grafana/grafana:latest
  container_name: grafana
  restart: always
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
  volumes:
    - grafana_data:/var/lib/grafana
  networks:
    - lnmp_network
node-exporter:
  image: prom/node-exporter:latest
  container_name: node-exporter
  restart: always
  ports:
    - "9100:9100"
  networks:
- lnmp_network
2.在文件末尾添加 volumes 定义：
volumes:
  prometheus_data:
  grafana_data:
3.检查语法
- 命令：docker-compose config
第三步：创建 Prometheus 配置文件（告诉它要监控哪些目标，然后启动监控服务）
1.创建配置目录
- 命令：mkdir -p /root/docker-lnmp-project/prometheus
- 作用：这个目录用来存放 Prometheus 的配置文件
2.创建配置文件
- 命令：vim /root/docker-lnmp-project/prometheus/prometheus.yml
- 内容：
global:
  scrape_interval: 15s      # 每15秒采集一次数据
  evaluation_interval: 15s  # 每15秒评估一次告警规则（本例未设置告警）
scrape_configs:
  - job_name: 'prometheus'   # 监控任务名称：采集 Prometheus 自身指标
    static_configs:
      - targets: ['localhost:9090']  # 目标地址：Prometheus 本机9090端口
  - job_name: 'node-exporter' # 监控任务：采集宿主机指标（CPU、内存等）
    static_configs:
      - targets: ['node-exporter:9100'] # 目标地址：node-exporter 容器9100端口
- 解释：global：全局配置，适用于所有监控任务。
scrape_configs：定义要监控的目标列表。
node-exporter:9100：通过容器名称 node-exporter 访问，因为它们在同一个 Docker 网络中，可以直接用容器名通信。
3.启动新增的三个监控服务
- 命令：docker-compose up -d prometheus grafana node-exporter
4.检查容器状态
- 命令：docker-compose ps
5.验证 Prometheus 是否正常
- 命令：curl http://localhost:9090
第四步：配置 Grafana 数据源并导入仪表盘
1.检查 Grafana 是否可访问
- 命令：curl -I http://localhost:3000
2.打开浏览器访问 Grafana
- 命令：http://192.168.10.17:3000（用户名：admin，密码：517127）
3.添加 Prometheus 数据源
- 操作：connections——>data sources——>add new data sources——>选择prometheus——>在 HTTP 栏的 URL 输入：http://prometheus:9090（因为 Grafana 和 Prometheus 在同一个 Docker 网络中，可以直接用容器名通信）——>滚动到底部，点击 Save & Test。
4.导入 Node Exporter 仪表盘
- 操作：dashborads——>new——>import——>在 Import via grafana.com 输入框里输入仪表盘 ID：1860（这是 Node Exporter Full 仪表盘，专门用来展示 node-exporter 采集的宿主机指标）——>Load——>Prometheus 数据源选择刚才添加的 Prometheus——>import。
第五步：添加 CI/CD（GitHub Actions）
1.在项目根目录创建 Dockerfile（用于构建自定义镜像）
- 作用：我们为 Nginx 和 PHP 分别创建 Dockerfile，将你现有的配置打包进镜像，这样以后可以直接使用这些镜像部署，而不需要挂载配置文件。
（1）创建 Nginx 的 Dockerfile
- 命令：cd /root/docker-lnmp-project && vim Dockerfile.nginx
- 内容：
FROM nginx:alpine
COPY nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY html /usr/share/nginx/html
- 解释：FROM nginx:alpine：基于官方 nginx:alpine 镜像
COPY nginx/conf.d/default.conf：把自定义的 Nginx 配置复制到镜像内
COPY html：把网站文件复制到镜像内，这样镜像本身就包含了静态文件
（2）创建 PHP 的 Dockerfile
- 命令：vim Dockerfile.php
- 内容：FROM php:7.4-fpm
RUN docker-php-ext-install mysqli
COPY html /var/www/html
- 解释：FROM php:7.4-fpm：基于官方 PHP 7.4 FPM 镜像
RUN docker-php-ext-install mysqli：安装 mysqli 扩展（解决你之前遇到的故障）
COPY html：把网站文件复制到镜像内
2.创建 GitHub Actions 工作流文件
- 命令：mkdir -p .github/workflows  && vim .github/workflows/docker-build.yml
- 内容：
name: Build and Push Docker Images
on:
  push:
    branches: [ main ]   # 当推送到 main 分支时触发
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - name: Build and push Nginx image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.nginx
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/lnmp-nginx:latest
      - name: Build and push PHP image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.php
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/lnmp-php:latest
- 解释：on.push.branches：触发分支，这里是 main
jobs.build.steps：定义了构建步骤
docker/login-action：登录 Docker Hub，需要提供用户名和密码（通过 GitHub Secrets 传入，确保安全）
docker/build-push-action：构建并推送镜像，file 指定我们刚才创建的 Dockerfile，tags 指定镜像标签
3.将新增文件提交到本地 Git 仓库
- 命令：git add .github/ Dockerfile.nginx Dockerfile.php
        git commit -m "Add CI/CD: GitHub Actions for building Docker images"
4.在 GitHub 仓库中配置 Secrets（敏感信息）
- 作用：我们需要把 Docker Hub 的用户名和密码（或访问令牌）以加密方式存储在 GitHub 仓库中，供 Actions 使用
- 操作：进入我的docker-lnmp-project仓库——>Settings——>Secrets and variables——>Actions——>New repository secret——>Name 输入：DOCKER_USERNAME——>Secret 输入：Docker Hub 用户名（xiaoqiushui17）——>Add secret——>再次点击New repository secret——>Name 输入：DOCKER_PASSWORD——>Secret 输入： Docker Hub 密码
5.推送代码到 GitHub 触发 CI/CD
- 命令：git push（推送成功后，可以在 GitHub 仓库的 Actions 标签页看到正在运行的工作流。点击进去可以查看实时日志）
6.验证 CI/CD 运行结果
- 等待工作流完成，所有步骤应为绿色（成功）。
- 登录 Docker Hub，查看是否出现了两个镜像仓库：lnmp-nginx 和 lnmp-php，且都有 latest 标签
