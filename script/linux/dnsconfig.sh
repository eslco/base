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

# 定義 set_dns 函數
set_dns() {
    rm /etc/resolv.conf
    touch /etc/resolv.conf

    if [ -n "$dns1_ipv4" ]; then
        echo "nameserver $dns1_ipv4" >> /etc/resolv.conf
        echo "nameserver $dns2_ipv4" >> /etc/resolv.conf
    fi

    if [ -n "$dns1_ipv6" ]; then
        echo "nameserver $dns1_ipv6" >> /etc/resolv.conf
        echo "nameserver $dns2_ipv6" >> /etc/resolv.conf
    fi
}

# 定義 set_dns_ui 函數
set_dns_ui() {
    while true; do
        clear
        echo "優化DNS地址"
        echo "------------------------"
        echo "當前DNS地址"
        cat /etc/resolv.conf
        echo "------------------------"
        echo ""
        echo "1. 全球DNS優化(Cloudflare & AdGuard)"
        echo " v4: 1.0.0.1 94.140.14.15"
        echo " v6: 2606:4700:4700::1001 2a00:5a60::ad1:0ff"
		echo "2. Europe DNS 歐洲地區 (DNS.WATCH & Uncensored DNS)"
		echo v4 "84.200.70.40 & 89.233.43.71"
		echo v6 "2001:1608:10:25::9249:d69b & 2a01:3a0:53:53::"
        echo "3. APAC亞太地區DNS(TWNIC.TW & DNS.IIJ.JP)"
        echo " v4: 101.102.103.104 & 103.2.57.5"
        echo " v6: 2001:de4::102 & 2001:300::5"
        echo "========================"
        echo "------------------------"
        echo "5. 中國大陸地區DNS優化(HKNet & Hinet)"
        echo " v4: 202.67.240.222 & 168.95.192.1"
        echo " v6: 2001:300::6 & 2001:b000:168::1"
        echo "6. 手動編輯DNS配置"
        echo "------------------------"

        echo "0. 返回上一级"
        echo "------------------------"
        read -e -p "請輸入你的選擇: " option
        case "$option" in
            1)
                dns1_ipv4="1.0.0.1"
                dns2_ipv4="94.140.14.15"
                dns1_ipv6="2606:4700:4700::1001"
                dns2_ipv6="2a00:5a60::ad1:0ff"
                set_dns
                ;;
            2)
                dns1_ipv4="84.200.70.40"
                dns2_ipv4="89.233.43.71"
                dns1_ipv6="2001:1608:10:25::9249:d69b"
                dns2_ipv6="2a01:3a0:53:53::"
                set_dns
                ;;
            3)
                dns1_ipv4="101.102.103.104"
                dns2_ipv4="103.2.57.5"
                dns1_ipv6="2001:de4::102"
                dns2_ipv6="2001:300::5"
                set_dns
                ;;
			5)
                dns1_ipv4="202.67.240.222"
                dns2_ipv4="168.95.192.1"
                dns1_ipv6="2001:300::6"
                dns2_ipv6="2001:b000:168::1"
                set_dns
                ;;		
            6)
                nano /etc/resolv.conf
                ;;

            0)
                break
                ;;
            *)
                echo "無效選項，請重新選擇。"
                ;;
        esac
    done
}

# 調用 set_dns_ui 函數
set_dns_ui

# 重啟網絡服務
if systemctl list-unit-files | grep -q networking.service; then
    echo "正在重啟網絡服務..."
    if ! systemctl restart networking; then
        echo "警告：網絡服務重啟失敗"
    fi
else
    echo "提示：未找到 networking 服務，可能使用其他網絡管理服務"
    if systemctl list-unit-files | grep -q NetworkManager.service; then
        echo "正在重啟 NetworkManager..."
        if ! systemctl restart NetworkManager; then
            echo "警告:NetworkManager 重啟失敗"
        fi
    fi
fi

echo "DNS 配置更新完成!"
echo "當前DNS配置文件路徑: /etc/resolv.conf"
echo "當前DNS配置文件內容如下:"
echo "------------------------"
cat /etc/resolv.conf
echo "------------------------"
echo "提示:"
echo "可以使用 'cat /etc/resolv.conf' 檢查配置"
echo "使用 'ping -6 google.com' 測試 IPv6 連接"
echo "再次使用請執行以下命令"
echo "curl -sSL https://raw.github.com/eslco/base/main/script/linux/dnsconfig.sh | sudo bash"
echo "更多內容請查看Github倉庫"
echo "https://github.com/eslco/base/script"
echo ""感謝使用此腳本!"再見"