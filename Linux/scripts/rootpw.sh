#!/bin/bash

# 检查是否以 root 身份运行

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please switch to root user or use sudo."
    exit 1
fi
# 检查脚本是否以root身份运行。
# 如果当前用户不是root用户（id -u 返回的用户ID不为0），则输出提示信息并退出脚本。

# 获取用户输入的密码，并进行二次确认
while true; do
    read -sp "Enter new root password: " root_password
    echo
    read -sp "Confirm new root password: " confirm_password
    echo
    if [ "$root_password" == "$confirm_password" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done
# 提示用户输入新root密码，并进行确认。
# 使用read -sp读取用户输入的密码，-s选项使输入不可见（隐藏）。
# 验证两次输入的密码是否一致。如果一致，则继续；否则，提示重新输入。

# 修改 root 用户的密码
echo "root:$root_password" | sudo chpasswd || { echo "Failed to change root password"; exit 1; }

# 备份 SSH 配置文件
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || { echo "Failed to backup SSH configuration"; exit 1; }
# 备份当前的SSH配置文件/etc/ssh/sshd_config到/etc/ssh/sshd_config.bak。
# 如果备份失败，则输出错误信息并退出脚本。

# 修改 SSH 配置以允许 root 登录和启用密码认证
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config || { echo "Failed to update PermitRootLogin"; exit 1; }
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config || { echo "Failed to update PasswordAuthentication"; exit 1; }
# 使用sed命令编辑SSH配置文件，启用PermitRootLogin（允许root登录）和PasswordAuthentication（启用密码认证）。
# 如果修改失败，则输出错误信息并退出脚本。

# 检查系统是否为 Ubuntu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" == "ubuntu" ]; then
        # 修改 ChallengeResponseAuthentication 为 yes（如果存在）
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config || { echo "Failed to update ChallengeResponseAuthentication"; exit 1; }
    fi
fi
# 检查系统是否为Ubuntu。
# 通过读取/etc/os-release文件，确定操作系统类型。
# 如果系统是Ubuntu，使用sed命令启用ChallengeResponseAuthentication（如果存在）。
# 如果修改失败，则输出错误信息并退出脚本。

# 重启 SSH 服务
sudo service ssh restart || { echo "Failed to restart SSH service"; exit 1; }

echo "Password changed successfully and SSH configuration updated."

# 总结
## 这段脚本主要实现了以下功能：
## 检查是否以root用户运行。
## 提示用户输入和确认新root密码。
## 更新root密码。
## 备份SSH配置文件。
## 修改SSH配置以允许root登录并启用密码认证。
## 如果系统是Ubuntu，还启用ChallengeResponseAuthentication。
## 重启SSH服务。
## 输出操作成功的信息。
#
