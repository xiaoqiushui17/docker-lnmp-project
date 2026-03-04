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
