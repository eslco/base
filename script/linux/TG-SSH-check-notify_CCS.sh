#!/bin/bash



TELEGRAM_BOT_TOKEN="${TGBotToken}" # 輸入你的 Bot API Token
CHAT_ID="${TGChatID}" # 輸入你的TG ID

# 初始化變量
public_ip=$(curl -s ifconfig.me)  # 獲取公共IP地址
country=""
isp_info=""
ipv4_address=""
masked_ip=""
IP=""
TIME=""
USERNAME=""
IP_as=""
IP_org=""
ACCESS_IP=""
ACCESS_CN=""
Scamlaytics_Score=""
IPQS_RESPONSE=""
IPQS_SCORE=""
IPQS_RISK=""
IPAPI_RESPONSE=""
IPAPI_SCORE=""
IPAPI_RISK=""
IPAPI_TYPE=""

# 獲取登錄信息
country=$(curl -s ipinfo.io/$public_ip/country)
isp_info=$(curl -s ipinfo.io/org | sed -e 's/\"//g' | awk -F' ' '{print $2}')

ipv4_address=$(curl -s ipv4.ip.sb)
masked_ip=$(echo $ipv4_address | awk -F'.' '{print "*."$3"."$4}')

# 獲取登錄IP&時間
IP=$(echo $SSH_CONNECTION | awk '{print $1}')
TIME=$(date +"%Y-%m-%d %H:%M:%S")

# 獲取當前用戶名
USERNAME=$(whoami)

# HTML 轉義函數
html_escape() {
    echo "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# URL 轉義函數
url_escape() {
    printf '%s' "$1" | jq -sRr @uri
}

IP_ESCAPED=$(echo "$IP" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

# 查詢IP地址對應的地區信息
IP_info=$(curl -s "http://ip-api.com/json/$IP" | jq -r '.as, .org, .city')
IFS=$'\n' read -r -d '' IP_as IP_org ACCESS_IP <<< "$IP_info"

# 獲取IP地址對應的國家信息
ACCESS_CN=$(curl -s "http://opendata.baidu.com/api.php?query=$IP&co=&resource_id=6006&oe=utf8&format=json" | jq -r '.data[0].location')
ACCESS_US=$(curl -s "http://ip-api.com/json/$IP" | jq -r '.city')
# 獲取IP地址對應的Scam詐騙分數
Scamlaytics_Score=$(curl -s "https://scamalytics.com/ip/$IP" | grep -oP '(?<=Fraud Score: )\d+')

# 新增 IPQS 查詢
IPQS_RESPONSE=$(curl -s "https://ipinfo.check.place/$IP?db=ipqualityscore")
IPQS_SCORE=$(echo "$IPQS_RESPONSE" | jq -r '.fraud_score')
IPQS_RISK="Low"
if [[ ${IPQS_SCORE} -ge 90 ]]; then
    IPQS_RISK="90+ Risky"
elif [[ ${IPQS_SCORE} -ge 85 ]]; then
    IPQS_RISK="85+ Suspicious"
elif [[ ${IPQS_SCORE} -ge 75 ]]; then
    IPQS_RISK="75+ Low"
elif [[ ${IPQS_SCORE} -lt 10 ]]; then
    IPQS_RISK="10- Low"
elif [[ ${IPQS_SCORE} -eq 0 ]]; then
    IPQS_RISK="0 Unknown!"
fi

# 新增 IPAPI 查詢
IPAPI_RESPONSE=$(curl -s "https://api.ipapi.is/?q=$IP")
IPAPI_SCORE=$(echo "$IPAPI_RESPONSE" | jq -r '.company.abuser_score' | awk '{print $1}')
IPAPI_RISK="Low"

if [[ -z $IPAPI_SCORE ]]; then
    IPAPI_RISK="Unknown!"
else
    case $(echo "$IPAPI_RESPONSE" | jq -r '.company.abuser_score' | awk -F'[()]' '{print $2}') in
        "Very High")
            IPAPI_RISK="Very High Risk"
            ;;
        "High")
            IPAPI_RISK="High Risk"
            ;;
        "Elevated") 
            IPAPI_RISK="Elevated Risk"
            ;;
        "Low")
            IPAPI_RISK="Low Risk"
            ;;
        "Very Low")
            IPAPI_RISK="Very Low Risk"
            ;;
        *)
            IPAPI_RISK="Unknown!"
            ;;
    esac
fi

# 獲取使用類型
IPAPI_TYPE=$(echo "$IPAPI_RESPONSE" | jq -r '.asn.type')
if [[ -z $IPAPI_TYPE ]]; then
    IPAPI_TYPE="Unknown"
else
    case $IPAPI_TYPE in
        "business") IPAPI_TYPE="Business";;
        "isp") IPAPI_TYPE="ISP";;
        "hosting") IPAPI_TYPE="Hosting";;
        "education") IPAPI_TYPE="Education";;
        "government") IPAPI_TYPE="Government";;
        "banking") IPAPI_TYPE="Banking";;
        *) IPAPI_TYPE="Other";;
    esac
fi

# URL 編碼
# 構建待發送的 Telegram 消息
# MESSAGE="ℹ️ 登錄信息 SSH Info: 
# 設備 Machine: ${isp_info}-${country}-${masked_ip}
# 用戶名 Username: $USERNAME
# 時間 Time: ${TIME}
# 地點:<tg-spoiler>${ACCESS_IP}|${ACCESS_CN}</tg-spoiler>
# 登錄 IP: <a href=\"https://ipapi.co/?q=${IP_ESCAPED}\">${IP}</a>
# <blockquote expandable>
# IP風險係數
# IPQS: ${IPQS_SCORE}|(${IPQS_RISK}) 
# IPAPI: ${IPAPI_SCORE}|(${IPAPI_RISK})
# Scam:(${Scamlaytics_Score}/110)
# AS: ${IP_as}
# ORG: ${IP_org}
# 更多信息
# <a href='https://html.zone/ip/query?q=${IP}'>HTML.Zone</a> | <a href='https://ip.im/${IP}'>IP.IM</a> | <a href='https://ip.ping0.cc/ip/${IP}'>Ping0.cc</a>

MESSAGE="ℹ️ <b>登錄信息 SSH Info:</b>

<b>設備 Machine:</b> ${isp_info}-${country}-${masked_ip}
<b>用戶名 Username:</b> $(html_escape "$USERNAME")
<b>時間 Time:</b> ${TIME}
<b>地點 Location:</b> <tg-spoiler>${ACCESS_CN}|${ACCESS_US}</tg-spoiler>
<b>登錄 IP:</b> <a href='https://ipapi.co/?q=${IP_ESCAPED}'>${IP}</a>
<b>📡 網絡信息</b>
• AS: ${IP_as}
• ORG: ${IP_org}
<b>🔍 IP 風險評估</b>
• IPQS: <code>${IPQS_SCORE}</code> | <i>${IPQS_RISK}</i>
• IPAPI: <code>${IPAPI_SCORE}</code> | <i>${IPAPI_RISK}</i>
• Scam: <code>${Scamlaytics_Score}|100</code>
<blockquote expandable>
<b>🔗 更多詳情</b>
• <a href='https://html.zone/ip/query?q=${IP}'>HTML.Zone</a> | <a href='https://ip.im/${IP}'>IP.IM</a> | <a href='https://ip.ping0.cc/ip/${IP}'>Ping0.cc</a>
</blockquote>"

# 發送 Telegram 消息
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$CHAT_ID" \
    -d "text=$MESSAGE" \
    -d "parse_mode=html" \
    -d "disable_web_page_preview=true" \
    > /dev/null 2>&1