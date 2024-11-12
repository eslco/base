#!/bin/bash

# 設置Telegram Bot Token 和 Chat ID
TELEGRAM_BOT_TOKEN="Type輸入Your你的TG Bot API Token" # Your 你的Telegram Bot Token
CHAT_ID="Type输入YourTG的Chat账号ID" # Your 你的Telegram Chat ID

# 設置CURL超時時間 #URL_TIMEOUT=8
# 獲取登錄信息 Information
country=$(curl -s ipinfo.io/${public_ip}/country)
isp_info=$(curl -s ipinfo.io/org | sed -e 's/\"//g' | awk -F' ' '{print $2}')

ipv4_address=$(curl -s ipv4.ip.sb)
masked_ip=$(echo $ipv4_address | awk -F'.' '{print "*."$3"."$4}')

# 獲取SSH連接的IP地址
IP=$(echo $SSH_CONNECTION | awk '{print $1}')
TIME=$(date +"%Y-%m-%d %H:%M:%S")


# 查詢IP地址對應的地理信息 GeoLocation 
# 備用 ACCESS0=$(curl -s https://ipapi.co/$IP/json/ | jq -r '.city')
IP_as=$(curl -s  "http://ip-api.com/json/$IP" | jq -r '.as')
IP_org=$(curl -s "http://ip-api.com/json/$IP" | jq -r '.org')
ACCESS_CN=$(curl -s "http://opendata.baidu.com/api.php?query=$IP&co=&resource_id=6006&oe=utf8&format=json" | jq -r '.data[0].location')
ACCESS_US=$(curl -s "http://ip-api.com/json/$IP" | jq -r '.city')
ScamRiskScore=$(curl -s "https://scamalytics.com/ip/$IP" | grep -oP '(?<=Fraud Score: )\d+')

# 獲取當前用戶名 UserName
USERNAME=$(whoami)
# 構建待發送的Telegram消息 Message
MESSAGE="ℹ️ 登錄信息SSH Info: 
設備 Machine: ${isp_info}-${country}-${masked_ip}
用戶名 Username: $USERNAME
時間 Time: $TIME
地點 GeoData: ${ACCESS_CN}|${ACCESS_US}
登錄 IP: <a href="http://ip-api.com/json/${IP}">${IP}</a>
Org所屬組織: ${IP_org}
AS自治域: ${IP_as}
風險因數 <a href="https://scamalytics.com/ip/${IP}"><strong>FraudScore:${ScamRiskScore}</strong></a>
IP詳情MoreInfo: <a href="https://html.zone/ip/query?ip=${IP}">HTML.Zone</a> | <a href="https://ip.im/${IP}">IP.IM</a> | <a href="https://ip.ping0.cc/ip/${IP}"><strong>Ping0.cc(${IP})</strong></a>"

 # 發送 Telegram 消息
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=$MESSAGE" \
    -d "parse_mode=html" \
    -d "disable_web_page_preview=true" \
    > /dev/null 2>&1