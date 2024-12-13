#!/bin/bash

# 你需要配置Telegram Bot Token 和 Chat ID
TELEGRAM_BOT_TOKEN="${TGBotToken}" # Your 你的Telegram Bot Token
CHAT_ID="${TGChatID}" # Your 你的Telegram Chat ID


# 你可以修改監控閾值設置
CPU_THRESHOLD=90 # 監控CPU使用率閾值    
MEMORY_THRESHOLD=88 # 監控記憶體使用率閾值
DISK_THRESHOLD=80 # 監控硬碟使用率閾值
NETWORK_THRESHOLD_GB=8192 # 監控網路流量閾值



# 獲取設備資訊的變數
country=$(curl -s ipinfo.io/$public_ip/country)
isp_info=$(curl -s ipinfo.io/org | sed -e 's/\"//g' | awk -F' ' '{print $2}')

ipv4_address=$(curl -s ipv4.ip.sb)
masked_ip=$(echo $ipv4_address | awk -F'.' '{print "*."$3"."$4}')

# 發送Telegram通知的函數
send_tg_notification() {
    local MESSAGE=$1
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$MESSAGE"
}


# 獲取CPU使用率
get_cpu_usage() {
    awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else printf "%.0f\n", (($2+$4-u1) * 100 / (t-t1))}' \
        <(grep 'cpu ' /proc/stat) <(sleep 1; grep 'cpu ' /proc/stat)
}

# 獲取記憶體使用率
get_memory_usage() {
    free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}'
}

# 獲取硬碟使用率
get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# 獲取總的接收流量（位元組數）
get_rx_bytes() {
    awk 'BEGIN { rx_total = 0 }
        NR > 2 { rx_total += $2 }
        END {
            printf("%.2f", rx_total / (1024 * 1024 * 1024));
        }' /proc/net/dev
}

# 獲取總的發送流量（位元組數）
get_tx_bytes() {
    awk 'BEGIN { tx_total = 0 }
        NR > 2 { tx_total += $10 }
        END {
            printf("%.2f", tx_total / (1024 * 1024 * 1024));
        }' /proc/net/dev
}

# 檢查並發送通知
check_and_notify() {
    local USAGE=$1
    local TYPE=$2
    local THRESHOLD=$3
    local CURRENT_VALUE=$4

    if (( $(echo "$USAGE > $THRESHOLD" | bc -l) )); then
        send_tg_notification "警告Warning: ${isp_info}-${country}-${masked_ip} 的 $TYPE 使用率已達 $USAGE% Usage rate reached，超過Usage rate has exceeded the閾值 $THRESHOLD%."
    fi
}

# 主循環
while true; do
    CPU_USAGE=$(get_cpu_usage)
    MEMORY_USAGE=$(get_memory_usage)
    DISK_USAGE=$(get_disk_usage)
    RX_GB=$(get_rx_bytes)
    TX_GB=$(get_tx_bytes)

    check_and_notify $CPU_USAGE "CPU使用率" $CPU_THRESHOLD $CPU_USAGE
    check_and_notify $MEMORY_USAGE "記憶體MEM" $MEMORY_THRESHOLD $MEMORY_USAGE
    check_and_notify $DISK_USAGE "硬碟Disk" $DISK_THRESHOLD $DISK_USAGE

    # 檢查入站流量是否超過閾值
    if (( $(echo "$RX_GB > $NETWORK_THRESHOLD_GB" | bc -l) )); then
        send_tg_notification "警告Warning: ${isp_info}-${country}-${masked_ip} 入棧流量已達 ${RX_GB}GB(InBound Data Reached)，超過Data has exceeded the ${NETWORK_THRESHOLD_GB}GB 閾值threshold."
    fi

    # 檢查出站流量是否超過閾值
    if (( $(echo "$TX_GB > $NETWORK_THRESHOLD_GB" | bc -l) )); then
        send_tg_notification "警告Warning: ${isp_info}-${country}-${masked_ip} 出棧流量已達 ${TX_GB}GB(OutBound Data Reached)，超過Data has exceeded the ${NETWORK_THRESHOLD_GB}GB 閾值threshold."
    fi

    # 休眠5分鐘
    sleep 300
done