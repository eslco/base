#!/bin/bash
# 檢查是否以 root 權限運行
if [ "$(id -u)" != "0" ]; then
    echo "錯誤：此腳本需要 root 權限才能執行"
    echo "請使用 sudo 運行此腳本"
    exit 1
fi

# 檢查 resolv.conf 是否存在
if [ ! -f /etc/resolv.conf ]; then
    echo "錯誤：/etc/resolv.conf 文件不存在"
    exit 1
fi

# 備份原始文件
echo "正在備份原始 resolv.conf..."
cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)

echo "備份完成!"

# 嘗試解除文件不可變屬性
echo "正在解除文件不可變屬性..."
if ! chattr -i /etc/resolv.conf 2>/dev/null; then
    echo "警告：無法解除文件鎖定屬性，可能未設置"
fi

# 寫入新的 DNS 配置
echo "正在寫入新的 DNS 配置..."
if ! tee /etc/resolv.conf << 'EOF'
# Cloudflare IPv4&v6
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
# Google IPv4&v6
nameserver 8.8.4.4
nameserver 2001:4860:4860::8844
# GoogleDNS NAT64
nameserver 2001:4860:4860:0:0:0:0:6464
nameserver 2001:4860:4860:0:0:0:0:64

EOF
then
    echo "錯誤：無法寫入 /etc/resolv.conf"
    exit 1
fi

# 檢查網絡服務是否存在
if systemctl list-unit-files | grep -q networking.service; then
    echo "正在重啟網絡服務..."
    if ! systemctl restart networking; then
        echo "警告：網絡服務重啟失敗"
    fi
else
    echo "提示：未找到 networking 服務，可能使用其他網絡管理服務"
    # 對於使用 NetworkManager 的系統
    if systemctl list-unit-files | grep -q NetworkManager.service; then
        echo "正在重啟 NetworkManager..."
        if ! systemctl restart NetworkManager; then
            echo "警告：NetworkManager 重啟失敗"
        fi
    fi
fi

printf "\033c"




echo "DNS 配置更新完成!"
echo "当前DNS配置文件路径: /etc/resolv.conf"
echo "当前DNS配置文件内容如下: CLI命令:(cat /etc/resolv.conf)"
echo #######################################################
cat ~/etc/resolv.conf
echo "以上是当前DNS配置文件内容"
echo #######################################################
echo "Tips:"
echo "可以使用 'cat /etc/resolv.conf' 檢查配置"
echo "使用 'ping -6 google.com' 測試 IPv6 連接"
echo "======================================================"
echo "感謝使用此脚本!"
echo "再次使用請執行以下命令"
echo "curl -sSL https://raw.github.com/eslco/base/main/script/linux/dnsconfig.sh | sudo bash"
echo "更多内容 請查看Github倉庫"
echo "https://github.com/eslco/base/script"
echo "======================================================" 
echo "感謝使用!再見"