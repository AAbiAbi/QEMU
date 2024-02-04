#!/bin/bash

# SSH配置
SSH_USER="abiqemu" # SSH用户名
SSH_KEY_PATH="/Users/a25076/.ssh/id_rsa" # SSH私钥的路径

# 测试SSH连接
echo "Testing SSH connection to QEMU virtual machine using SSH key..."

# 尝试SSH连接并执行简单的回显命令
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" -p 2222 "$SSH_USER@localhost"  "sysbench cpu --cpu-max-prime=50000 --time=30 run; echo 'SSH connection successful'"

# 检查SSH命令的返回值
if [ $? -eq 0 ]; then
    echo "SSH connection test passed."
else
    echo "SSH connection test failed."
fi
