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

# DNS 配置文件路徑
DNS_CONFIG_FILE="/etc/dns_regions.conf"

# 創建默認 DNS 配置文件
create_default_dns_config() {
    cat > "$DNS_CONFIG_FILE" << 'EOF'
[GLOBAL]
name=Leading全球DNS優化(Cloudflare & AdGuard)
dns1_ipv4=1.0.0.1
dns2_ipv4=94.140.14.15
dns1_ipv6=2606:4700:4700::1001
dns2_ipv6=2a00:5a60::ad1:0ff

[LATAM]
name=LATAM 南美洲地區DNS優化(AR & sec.dns.br)
dns1_ipv4=200.160.0.11
dns2_ipv4=189.4.130.159
dns1_ipv6=2001:12ff::14
dns2_ipv6=2001:12ff::11

[EUROPE]
name=EuropeDNS歐洲地區(DNS.WATCH & UncensoredDNS)
dns1_ipv4=84.200.70.40
dns2_ipv4=89.233.43.71
dns1_ipv6=2001:1608:10:25::9249:d69b
dns2_ipv6=2a01:3a0:53:53::

[CHINA]
name=CN Mainland大陸地區DNS優化(HKNet & Hinet)
dns1_ipv4=202.67.240.222
dns2_ipv4=168.95.192.1
dns1_ipv6=2001:300::6
dns2_ipv6=2001:b000:168::1

[APAC]
name=APAC亞太地區DNS(TWNIC.TW&DNS.IIJ.JP)
dns1_ipv4=101.102.103.104
dns2_ipv4=103.2.57.5
dns1_ipv6=2001:418:3ff::53
dns2_ipv6=2001:300::5
EOF
}

# 驗證 IP 地址格式
validate_ip() {
    local ip=$1
    local type=$2
    
    if [ "$type" = "ipv4" ]; then
        if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            return 0
        fi
    elif [ "$type" = "ipv6" ]; then
        if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
            return 0
        fi
    fi
    return 1
}

# 添加新的 DNS 區域配置
add_dns_region() {
    echo "添加新的 DNS 區域配置"
    
    # 區域名稱驗證
    while true; do
        read -p "請輸入區域名稱(例如: APAC): " region
        if [[ $region =~ ^[A-Z0-9]+$ ]]; then
            break
        else
            echo "錯誤：區域名稱只能包含大寫字母和數字"
        fi
    done
    
    read -p "請輸入區域描述: " description
    
    # IPv4 DNS 輸入（支持多個，空格分隔）
    while true; do
        read -p "請輸入 IPv4 DNS (多個地址用空格分隔): " ipv4_dns
        valid=true
        for ip in $ipv4_dns; do
            if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                valid=false
                break
            fi
        done
        [[ $valid == true ]] && break
        echo "錯誤：請輸入有效的 IPv4 地址"
    done
    
    # IPv6 DNS 輸入（支持多個，空格分隔）
    while true; do
        read -p "請輸入 IPv6 DNS (多個地址用空格分隔): " ipv6_dns
        valid=true
        for ip in $ipv6_dns; do
            if ! [[ $ip =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]]; then
                valid=false
                break
            fi
        done
        [[ $valid == true ]] && break
        echo "錯誤：請輸入有效的 IPv6 地址"
    done
    
    # 將 DNS 地址轉換為數組
    IFS=' ' read -r -a dns_ipv4_array <<< "$ipv4_dns"
    IFS=' ' read -r -a dns_ipv6_array <<< "$ipv6_dns"

    # 添加新配置
    cat >> "$DNS_CONFIG_FILE" << EOF

[$region]
name=$description
dns1_ipv4=${dns_ipv4_array[0]}
dns2_ipv4=${dns_ipv4_array[1]}
dns1_ipv6=${dns_ipv6_array[0]}
dns2_ipv6=${dns_ipv6_array[1]}
EOF
    echo "新的 DNS 區域配置已添加"
}

# 讀取 DNS 配置
load_dns_config() {
    local region=$1
    if [ ! -f "$DNS_CONFIG_FILE" ]; then
        create_default_dns_config
    fi
    
    # 讀取指定區域的 DNS 配置
    local section_found=false
    while IFS= read -r line; do
        if [[ $line =~ ^\[(.*)\]$ ]]; then
            if [ "${BASH_REMATCH[1]}" = "$region" ]; then
                section_found=true
                continue
            else
                [ "$section_found" = true ] && break
            fi
        fi
        
        if [ "$section_found" = true ]; then
            case "$line" in
                dns1_ipv4=*) dns1_ipv4="${line#*=}" ;;
                dns2_ipv4=*) dns2_ipv4="${line#*=}" ;;
                dns1_ipv6=*) dns1_ipv6="${line#*=}" ;;
                dns2_ipv6=*) dns2_ipv6="${line#*=}" ;;
            esac
        fi
    done < "$DNS_CONFIG_FILE"
    
    if [ "$section_found" = false ]; then
        echo "錯誤：找不到指定的區域配置"
        return 1
    fi
}

# 自動設置 DNS
auto_set_dns_by_region() {
    local country
    country=$(curl -s ipinfo.io/country)
    
    case "$country" in
        "CN") load_dns_config "CHINA" ;;
        "TW"|"HK"|"JP"|"KR"|"SG"|"VN"|"TH"|"ID"|"MY") load_dns_config "APAC" ;;
        "DE"|"FR"|"GB"|"IT"|"ES"|"NL"|"SE"|"CH") load_dns_config "EUROPE" ;;
        *) load_dns_config "GLOBAL" ;;
    esac
    
    set_dns
}

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

# 更新菜單選項
set_dns_ui() {
    while true; do
        clear
        echo "優化DNS地址"
        echo "------------------------"
        echo "當前DNS地址"
        cat /etc/resolv.conf
        echo "------------------------"
        echo "1. 使用全球DNS配置"
        echo "2. 根據GeoIP自動配置DNS"
        echo "3. 手動編輯DNS配置"
        echo "4. 使用歐洲地區DNS"
        echo "5. 使用中國大陸DNS"
        echo "6. 使用亞太地區DNS"
        echo "7. 添加新的DNS區域配置"
        echo "8. 查看所有DNS配置"
        echo "0. 退出"
        echo "------------------------"
        
        read -e -p "請輸入你的選擇: " option
        case "$option" in
            1) load_dns_config "GLOBAL" && set_dns ;;
            2) auto_set_dns_by_region ;;
            3) nano /etc/resolv.conf ;;
            4) load_dns_config "EUROPE" && set_dns ;;
            5) load_dns_config "CHINA" && set_dns ;;
            6) load_dns_config "APAC" && set_dns ;;
            7) add_dns_region ;;
            8) cat "$DNS_CONFIG_FILE" ;;
            0) break ;;
            *) echo "無效選項，請重新選擇。" ;;
        esac
        
        read -n 1 -s -r -p "按任意鍵繼續..."
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