#!/bin/bash

# 檢查是否以 root 身份運行
if [ "$(id -u)" -ne 0 ]; then
    echo "此腳本必須以 root 身份運行。請切換到 root 使用者或使用 sudo。"
    exit 1
fi
# 检查脚本是否以root身份运行。
# 如果当前用户不是root用户（id -u 返回的用户ID不为0），则输出提示信息并退出脚本。

# 獲取用戶輸入的密碼，並進行二次確認
while true; do
    read -sp "Enter new root password: " root_password
    echo
    read -sp "Confirm new root password: " confirm_password
    echo
    if [ "$root_password" == "$confirm_password" ]; then
        break
    else
        echo "Passwords do not match. Please try again."
        echo "密碼不匹配。請重試!"
    fi
done

# 提示用户输入新root密码，并进行确认。
# 使用read -sp读取用户输入的密码，-s选项使输入不可见（隐藏）。
# 验证两次输入的密码是否一致。如果一致，则继续；否则，提示重新输入。
# 修改 root 用户的密码
echo "注意,當前ROOT密碼已關閉明文顯示, 可通過修改 sysctl.conf 配置文件開啓顯示"
echo "root:$root_password" | sudo chpasswd || { echo "Failed to change root password"; exit 1; }
echo "ROOT密碼修改完成!"
echo  "請妥善保存 $root_password"
# 备份 SSH 配置文件
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak || { echo "Failed to backup SSH configuration"; exit 1; }
# 备份当前的SSH配置文件/etc/ssh/sshd_config到/etc/ssh/sshd_config.bak。
# 如果备份失败，则输出错误信息并退出脚本。

# 函數：檢查端口是否已被佔用
is_port_in_use() {
    netstat -tuln | grep ":$1 " > /dev/null
}

# 提示用戶輸入新的 SSH 端口或選擇隨機端口
ports=()
while true; do
    read -p "請輸入新的 SSH 端口（留空則隨機選擇），多個端口用逗號分隔: " input_ports
    if [ -z "$input_ports" ]; then
        # 隨機選擇一個未被佔用的端口
        while true; do
            new_port=$(( ( RANDOM % 64000 ) + 1024 ))
            if ! is_port_in_use "$new_port"; then
                ports+=("$new_port")
                break
            fi
        done
        echo "選擇的隨機端口: ${ports[-1]}"
    else
        IFS=',' read -ra port_list <<< "$input_ports"
        for port in "${port_list[@]}"; do
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1024 ] || [ "$port" -gt 65535 ]; then
                echo "無效的端口號。請輸入一個有效的端口號（1024-65535）。"
                continue 2
            elif is_port_in_use "$port"; then
                echo "端口 $port 已被佔用。請選擇另一個端口。"
                continue 2
            else
                ports+=("$port")
            fi
        done
        break
    fi
done

# 檢查是否有使用默認端口 22
if [[ " ${ports[@]} " =~ " 22 " ]]; then
    echo "警告: 使用默認端口 22 可能會有安全風險。建議使用其他端口。"
fi

# 修改 SSH 配置文件中的 Port 參數
for port in "${ports[@]}"; do
    echo "Port $port" | sudo tee -a /etc/ssh/sshd_config > /dev/null || { echo "更新 SSH Port 失敗"; exit 1; }
done
# 修改默認 SSH 監聽地址
sudo sed -i 's/^#\?ListenAddress.*/ListenAddress 0.0.0.0\nListenAddress ::/g' /etc/ssh/sshd_config || { echo "更新 ListenAddress 0.0.0.0 |:: 失敗"; exit 1; }

# 修改 SSH 配置以允許 root 登入和啟用密碼認證，公鑰登入認證
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config || { echo "Filed to update PermitRootLogin"; exit 1; }
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config || { echo "Failed to update PasswordAuthentication "; exit 1; }
sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config || { echo "Failed to open PubkeyAuthentication "; exit 1; }

# 檢查系統是否為 Ubuntu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" == "ubuntu" ]; then
        # 修改 ChallengeResponseAuthentication 為 yes（如果存在）
        sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config || { echo "更新 ChallengeResponseAuthentication 失敗"; exit 1; }
    fi
fi

# 修改 TCP/IP 配置
sudo sed -i 's/^#\?AllowAgentForwarding.*/AllowAgentForwarding yes/g' /etc/ssh/sshd_config || { echo "Failed to update AllowAgentForwarding"; exit 1; }
sudo sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding yes/g' /etc/ssh/sshd_config || { echo "Failed to update AllowTcpForwarding"; exit 1; }
sudo sed -i 's/^#\?X11Forwarding.*/X11Forwarding yes/g' /etc/ssh/sshd_config || { echo "Failed to update X11Forwarding"; exit 1; }
sudo sed -i 's/^#\?TCPKeepAlive.*/TCPKeepAlive yes/g' /etc/ssh/sshd_config || { echo "Failed to update TCPKeepAlive"; exit 1; }

# 修改 賬戶安全Config
sudo sed -i 's/^#\?PermitTTY.*/PermitTTY yes/g' /etc/ssh/sshd_config || { echo "Failed to update PermitTTY"; exit 1; }
# 重启 SSH 服务
sudo service ssh restart || { echo "Failed to restart SSH service"; exit 1; }

echo "Password changed successfully and SSH configuration updated."
echo "SSH 配置已更新!"
echo "新的 SSH 登錄端口為: $new_port"
# 总结
## 这段脚本主要实现了以下功能：
## 检查是否以root用户运行。
## 提示用户输入和确认新root密码。
## 更新root密码。
## 备份SSH配置文件。
## 修改SSH配置以允许root登录并启用密码认证，公钥登录认证。
## 如果系统是Ubuntu，还启用ChallengeResponseAuthentication。
## 重启SSH服务。
## 输出操作成功的信息。