#!/bin/bash

# DNS Configuration Management Script | DNS配置管理脚本
# Author: ESL Co. | 作者：Eslco.
# Version: 2.0 | 版本：2.0

# Global Constants | 全局常量
readonly SCRIPT_VERSION="2.0"
readonly CONFIG_DIR="/etc/dns"
readonly DNS_CONFIG_FILE="$CONFIG_DIR/dns_regions.conf"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly LOG_DIR="$CONFIG_DIR/logs"
readonly LOG_FILE="$LOG_DIR/dnsconfig.log"

# Language related definitions | 語言相關定義
readonly DEFAULT_LANG="en"  # Default language | 默認語言
readonly FALLBACK_LANG="en" # Fallback language | 後備語言

# Define supported languages | 定義支持的語言
declare -A SUPPORTED_LANGUAGES=(
    [zh]="中文:Chinese:zh_TW.UTF-8"
    [en]="English:English:en_US.UTF-8"
    [es]="Español:Spanish:es_ES.UTF-8"
    [ar]="العربية:Arabic:ar_SA.UTF-8"
    [fr]="Français:French:fr_FR.UTF-8"
    [ru]="Русский:Russian:ru_RU.UTF-8"
)

# Complete message definitions | 完整的消息定義
declare -A MESSAGES_ZH MESSAGES_EN
init_messages() {
    # Chinese messages | 中文消息
    MESSAGES_ZH=(
        [MENU_TITLE]="DNS配置管理脚本"
        [CURRENT_CONFIG]="當前DNS配置"
        [AUTO_CONFIG]="根據GeoIP自動配置DNS"
        [MANUAL_CONFIG]="手動配置DNS菜單"
        [REGION_MANAGE]="DNS區域管理"
        [EXIT]="退出"
        [INVALID_OPTION]="無效選項"
        [PRESS_ANY_KEY]="按任意鍵繼續..."
        [ERROR_OCCURRED]="發生錯誤"
        [ERROR_CODE]="錯誤代碼"
        [ERROR_MESSAGE]="錯誤信息"
        [SUGGESTED_ACTION]="建議操作"
        [EXECUTE_ACTION]="是否執行建議操作"
        [CONFIRM_EXIT]="確定要退出嗎"
        [YES_NO_PROMPT]="是否繼續？(y/n)"
        [LOADING]="正在加載..."
        [SUCCESS]="操作成功"
        [FAILED]="操作失敗"
        [BACKUP_CREATED]="已創建備份"
        [CONFIG_UPDATED]="配置已更新"
        [NETWORK_ERROR]="網絡錯誤"
        [PERMISSION_ERROR]="權限錯誤"
        [FILE_ERROR]="文件錯誤"
        [VALIDATION_ERROR]="驗證錯誤"
    )

    # English messages | 英文消息
    MESSAGES_EN=(
        [MENU_TITLE]="DNS Configuration Management"
        [CURRENT_CONFIG]="Current DNS Configuration"
        [AUTO_CONFIG]="Auto-configure DNS by GeoIP"
        [MANUAL_CONFIG]="Manual DNS Configuration Menu"
        [REGION_MANAGE]="DNS Region Management"
        [EXIT]="Exit"
        [INVALID_OPTION]="Invalid option"
        [PRESS_ANY_KEY]="Press any key to continue..."
        [ERROR_OCCURRED]="Error Occurred"
        [ERROR_CODE]="Error Code"
        [ERROR_MESSAGE]="Error Message"
        [SUGGESTED_ACTION]="Suggested Action"
        [EXECUTE_ACTION]="Execute suggested action"
        [CONFIRM_EXIT]="Confirm exit"
        [YES_NO_PROMPT]="Continue? (y/n)"
        [LOADING]="Loading..."
        [SUCCESS]="Operation successful"
        [FAILED]="Operation failed"
        [BACKUP_CREATED]="Backup created"
        [CONFIG_UPDATED]="Configuration updated"
        [NETWORK_ERROR]="Network error"
        [PERMISSION_ERROR]="Permission error"
        [FILE_ERROR]="File error"
        [VALIDATION_ERROR]="Validation error"
    )
}

# Improved language loading | 改進的語言加載
load_language() {
    local lang=${1:-$DEFAULT_LANG}
    
    # Validate language | 驗證語言
    if [[ ! -v SUPPORTED_LANGUAGES[$lang] ]]; then
        echo "Warning: Unsupported language '$lang', falling back to $FALLBACK_LANG"
        lang=$FALLBACK_LANG
    fi
    
    # Set locale | 設置語言環境
    IFS=':' read -r _ _ locale <<< "${SUPPORTED_LANGUAGES[$lang]}"
    if ! locale -a | grep -q "^$locale$"; then
        echo "Warning: Locale $locale not available, using system default"
    else
        export LANG=$locale
        export LC_ALL=$locale
    fi
    
    CURRENT_LANG=$lang
    return 0
}

# Improved message retrieval | 改進的消息獲取
get_message() {
    local key=$1
    local message=""
    
    # Try current language | 嘗試當前語言
    case "$CURRENT_LANG" in
        "zh") message="${MESSAGES_ZH[$key]}" ;;
        "en") message="${MESSAGES_EN[$key]}" ;;
        *) message="" ;;
    esac
    
    # Fallback to English if message not found | 如果消息未找到則使用英文
    if [[ -z "$message" ]]; then
        message="${MESSAGES_EN[$key]}"
    fi
    
    # Return message or key if not found | 返回消息或鍵名（如果未找到）
    echo "${message:-$key}"
}

# Language menu | 語言菜單
show_language_menu() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║ Select Language / 選擇語言             ║"
    echo "╠════════════════════════════════════════╣"
    
    local counter=1
    for lang in "${!SUPPORTED_LANGUAGES[@]}"; do
        IFS=':' read -r native english _ <<< "${SUPPORTED_LANGUAGES[$lang]}"
        printf "║ %d. %-20s %-15s ║\n" "$counter" "$native" "($english)"
        ((counter++))
    done
    
    echo "╠════════════════════════════════════════╣"
    echo "║ 0. Exit / 退出                         ║"
    echo "╚════════════════════════════════════════╝"
    
    while true; do
        read -p "Your choice / 您的選擇: " choice
        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ "$choice" =~ ^[1-9]$ ]] && [ "$choice" -le "${#SUPPORTED_LANGUAGES[@]}" ]; then
            local lang_code=$(echo "${!SUPPORTED_LANGUAGES[@]}" | tr ' ' '\n' | sed -n "${choice}p")
            load_language "$lang_code"
            save_language_config
            break
        else
            echo "Invalid choice / 無效選擇"
        fi
    done
}

# Initialize messages on script start | 腳本啟動時初始化消息
init_messages

# Initialize directories and files | 初始化目錄和文件
init_environment() {
    # Create necessary directories | 創建必要的目錄
    for dir in "$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || {
                echo "Error: Failed to create directory $dir"
                echo "錯誤：無法創建目錄 $dir"
                exit 1
            }
        fi
    done

    # Initialize log file | 初始化日誌文件
    touch "$LOG_FILE" || {
        echo "Error: Failed to create log file"
        echo "錯誤：無法創建日誌文件"
        exit 1
    }
}

# Logging function | 日誌記錄函數
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Improved menu display | 改進的菜單顯示
show_menu_header() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║ $(get_message MENU_TITLE) $(printf '%*s' $((47-${#MENU_TITLE})) '')║"
    echo "╠════════════════════════════════════════╣"
    show_breadcrumb
    echo "╠════════════════════════════════════════╣"
    echo "║ $(get_message CURRENT_CONFIG):         ║"
    echo "║ $(cat /etc/resolv.conf | sed 's/^/║ /')║"
    echo "╚════════════════════════════════════════╝"
}

# Enhanced hotkey handling | 增強的快捷鍵處理
handle_hotkeys() {
    local key=$1
    case "$key" in
        $'\e[A'|$'k') # Up arrow or k | 上箭頭或k
            return 0
            ;;
        $'\e[B'|$'j') # Down arrow or j | 下箭頭或j
            return 0
            ;;
        $'\e[D'|$'h') # Left arrow or h | 左箭頭或h
            go_back_menu
            return 0
            ;;
        $'\e[C'|$'l') # Right arrow or l | 右箭頭或l
            return 0
            ;;
        $'\e') # ESC | ESC鍵
            confirm_exit
            return $?
            ;;
        $'q') # Quick exit | 快速退出
            confirm_exit
            return $?
            ;;
        *) 
            return 2
            ;;
    esac
}

# Confirm exit | 確認退出
confirm_exit() {
    echo -e "\n$(get_message CONFIRM_EXIT)"
    read -n 1 -p "$(get_message YES_NO_PROMPT)" answer
    [[ $answer =~ ^[Yy]$ ]]
    return $?
}

# Enhanced error handling | 增強的錯誤處理
handle_error() {
    local error_code=$1
    local error_message=$2
    local recovery_action=${3:-""}
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log error | 記錄錯誤
    log_message "ERROR" "Code: $error_code, Message: $error_message"
    
    # Display error | 顯示錯誤
        echo "╔════════════════════════════════════════╗"
        echo "║ $(get_message ERROR_OCCURRED)          ║"
        echo "╠════════════════════════════════════════╣"
        echo "║ $(get_message ERROR_CODE): $error_code ║"
        echo "║ $(get_message ERROR_MESSAGE):          ║"
        echo "║ $error_message                         ║"
        echo "║                                        ║"
    if [ -n "$recovery_action" ]; then
        echo "╠════════════════════════════════════════╣"
        echo "║ $(get_message SUGGESTED_ACTION):       ║"
        echo "║ $recovery_action                       ║"
        echo "╚════════════════════════════════════════╝"
        
        read -p "$(get_message EXECUTE_ACTION) (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            eval "$recovery_action"
            return $?
        fi
    else
        echo "╚════════════════════════════════════════╝"
    fi
    
    return $error_code
}

# **Progress bar function** | **進度條函數**
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf ">"
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %3d%%" $percentage
}

# 顯示幫助信息
show_help() {
    echo "DNS配置管理腳本"
    echo "用法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  -i, --interactive, -menu    直接啟動交互菜單"
    echo "  -h, --help, -info          顯示幫助信息"
    echo "  -l, --lang                選擇語言"
    echo ""
    echo "示例:"
    echo "  $0 -i                       啟動交互式菜單"
    echo "  $0 --help                   顯示此幫助信息"
}

# 語言配置文件路徑
LANG_CONFIG_FILE="/etc/dns_lang.conf"

# 當前語言（默認英語）
CURRENT_LANG="en"

# 加載語言配置
load_language_config() {
    if [ -f "$LANG_CONFIG_FILE" ]; then
        CURRENT_LANG=$(cat "$LANG_CONFIG_FILE")
    fi
}

# 保存語言配置
save_language_config() {
    echo "$CURRENT_LANG" > "$LANG_CONFIG_FILE"
}

# 定義支持的編輯器
declare -A SUPPORTED_EDITORS=(
    [nano]="簡單易用的文本編輯器"
    [vim]="高級文本編輯器"
    [vi]="基礎文本編輯器"
    [emacs]="GNU Emacs編輯器"
    [mcedit]="Midnight Commander編輯器"
    [joe]="Joe's Own Editor"
    [micro]="現代化的終端編輯器"
)

# 檢測包管理器
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt-get"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# 安裝編輯器
install_editor() {
    local editor=$1
    local pkg_manager=$(detect_package_manager)
    
    if command -v "$editor" &>/dev/null; then
        echo "$editor 已安裝"
        return 0
    fi

    echo "正在安裝 $editor..."
    case "$pkg_manager" in
        "apt-get")
            apt-get update && apt-get install -y "$editor"
            ;;
        "dnf"|"yum")
            "$pkg_manager" install -y "$editor"
            ;;
        "pacman")
            pacman -Sy --noconfirm "$editor"
            ;;
        "zypper")
            zypper --non-interactive install "$editor"
            ;;
        "apk")
            apk add --no-cache "$editor"
            ;;
        *)
            echo "錯誤：無法識別的包管理器，請手動安裝 $editor"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "$editor 安裝成功"
        return 0
    else
        echo "錯誤：$editor 安裝失敗"
        return 1
    fi
}

# 檢查編輯器可用性
check_editor_availability() {
    local editor=$1
    if command -v "$editor" &>/dev/null; then
        return 0
    fi
    return 1
}

# 獲取已安裝的編輯器列表
get_installed_editors() {
    local installed=()
    for editor in "${!SUPPORTED_EDITORS[@]}"; do
        if check_editor_availability "$editor"; then
            installed+=("$editor")
        fi
    done
    echo "${installed[@]}"
}

# 添加菜單狀態追踪
declare -A MENU_STATE=(
    [CURRENT_MENU]="main"
    [PREVIOUS_MENU]=""
    [LAST_OPTION]=""
)

# 添加菜單歷史記錄
MENU_HISTORY=()

# 保存菜單狀態
save_menu_state() {
    MENU_STATE[PREVIOUS_MENU]=${MENU_STATE[CURRENT_MENU]}
    MENU_STATE[CURRENT_MENU]=$1
    MENU_STATE[LAST_OPTION]=$2
    MENU_HISTORY+=("${MENU_STATE[CURRENT_MENU]}")
}

# 返回上一級菜單
go_back_menu() {
    if [ ${#MENU_HISTORY[@]} -gt 1 ]; then
        unset 'MENU_HISTORY[${#MENU_HISTORY[@]}-1]'
        MENU_STATE[CURRENT_MENU]=${MENU_HISTORY[-1]}
        return 0
    fi
    return 1
}

# 顯示麵包屑導航
show_breadcrumb() {
    local separator=" > "
    local breadcrumb=""
    for menu in "${MENU_HISTORY[@]}"; do
        if [ -n "$breadcrumb" ]; then
            breadcrumb+="$separator"
        fi
        breadcrumb+="$(get_menu_title "$menu")"
    done
    echo "$breadcrumb"
}

# 獲取菜單標題
get_menu_title() {
    local menu=$1
    case "$menu" in
        "main") echo "$(get_message MENU_TITLE)" ;;
        "manual") echo "$(get_message MANUAL_CONFIG)" ;;
        "region") echo "$(get_message REGION_MANAGE)" ;;
        *) echo "$menu" ;;
    esac
}

# 改進菜單顯示函數
show_menu_header() {
    clear
    echo "=========================="
    show_breadcrumb
    echo "=========================="
    echo "$(get_message CURRENT_CONFIG):"
    cat /etc/resolv.conf
    echo "=========================="
}

# 添加快捷鍵處理
handle_hotkeys() {
    local key=$1
    case "$key" in
        $'\e[A') # 上箭頭
            return 0
            ;;
        $'\e[B') # 下箭頭
            return 0
            ;;
        $'\e[D') # 左箭頭 - 返回上一級
            go_back_menu
            return 0
            ;;
        $'\e') # ESC - 退出當前菜單
            return 1
            ;;
        *) 
            return 2
            ;;
    esac
}

# 改進錯誤處理
handle_error() {
    local error_code=$1
    local error_message=$2
    local recovery_action=${3:-""}
    
    echo "錯誤($error_code): $error_message"
    
    if [ -n "$recovery_action" ]; then
        echo "建議操作: $recovery_action"
        read -p "是否執行建議操作？(y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            eval "$recovery_action"
            return $?
        fi
    fi
    
    return $error_code
}

# 改進主菜單顯示
set_dns_ui() {
    save_menu_state "main" ""
    
    while true; do
        show_menu_header
        
        # 顯示快捷鍵提示
        echo "快捷鍵: ← 返回, ESC 退出"
        echo "------------------------"
        
        generate_menu_options
        
        echo "=========================="
        read -e -p "$(get_message ENTER_CHOICE): " -n 1 key
        
        # 處理快捷鍵
        handle_hotkeys "$key"
        local hotkey_status=$?
        
        case $hotkey_status in
            0) continue ;; # 快捷鍵已處理
            1) break ;; # ESC被按下
            2) # 不是快捷鍵，處理普通輸入
                case "$key" in
                    1) 
                        save_menu_state "auto" "1"
                        if ! auto_set_dns_by_region; then
                            handle_error 1 "自動配置失敗" "load_dns_config GLOBAL"
                        fi
                        ;;
                    2)
                        save_menu_state "manual" "2"
                        manual_edit_dns_menu
                        ;;
                    3)
                        save_menu_state "region" "3"
                        manage_dns_regions
                        ;;
                    0) break ;;
                    *)
                        if [ "$key" -ge 4 ] && [ "$key" -lt $((4 + $(get_available_regions | wc -l))) ]; then
                            local region=$(get_available_regions | sed -n "$((key-3))p")
                            save_menu_state "region_select" "$key"
                            if ! load_dns_config "$region" || ! set_dns; then
                                handle_error 2 "DNS配置失敗" "load_dns_config GLOBAL"
                            fi
                        else
                            handle_error 3 "$(get_message INVALID_OPTION)"
                        fi
                        ;;
                esac
                ;;
        esac
        
        # 顯示操作結果
        if [ $? -eq 0 ]; then
            echo "操作成功完成"
        else
            echo "操作未完成或出現錯誤"
        fi
        
        read -n 1 -s -r -p "$(get_message PRESS_ANY_KEY)"
    done
}

# 改進手動編輯菜單
manual_edit_dns_menu() {
    save_menu_state "manual" ""
    local installed_editors=($(get_installed_editors))
    
    while true; do
        show_menu_header
        echo "可用編輯器:"
        
        local counter=1
        for editor in "${installed_editors[@]}"; do
            printf "%d. %-15s %s\n" "$counter" "$editor" "${SUPPORTED_EDITORS[$editor]}"
            ((counter++))
        done
        
        echo "------------------------"
        echo "a. 安裝新編輯器"
        echo "r. 刷新列表"
        echo "b. 返回上級"
        echo "q. 退出"
        
        read -e -n 1 -p "選擇: " choice
        
        case "$choice" in
            [1-9])
                if [ "$choice" -le "${#installed_editors[@]}" ]; then
                    handle_editor_selection "${installed_editors[$((choice-1))]}"
                fi
                ;;
            a) handle_editor_installation ;;
            r) 
                installed_editors=($(get_installed_editors))
                echo "列表已更新"
                ;;
            b) return ;;
            q) exit 0 ;;
            *) handle_error 4 "無效選擇" ;;
        esac
    done
}

# 處理編輯器選擇
handle_editor_selection() {
    local editor=$1
    if ! check_editor_availability "$editor"; then
        handle_error 5 "$editor 不可用" "install_editor $editor"
        return 1
    fi
    
    # 備份配置
    cp /etc/resolv.conf "/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 使用編輯器
    if "$editor" /etc/resolv.conf; then
        echo "配置已更新"
        echo "新的DNS配置:"
        cat /etc/resolv.conf
        return 0
    else
        handle_error 6 "編輯過程出現問題"
        return 1
    fi
}

# 主程序入口
main() {
    # 解析命令行參數
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--interactive|-menu)
                INTERACTIVE=true
                shift
                ;;
            -h|--help|-info)
                show_help
                exit 0
                ;;
            -l|--lang)
                CURRENT_LANG="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option $1"
                echo "错误：未知选项 $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 檢查是否以 root 權限運行
    if [ "$(id -u)" != "0" ]; then
        echo "Error: This script requires root privileges"
        echo "错误：此脚本需要 root 权限"
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

    # 修改預設 DNS 區域定義和名稱
    readonly DEFAULT_REGIONS=(GLOBAL NAMERICA SAMERICA EUROPE AFRICA MEAST ASIA OCEANIA)
    declare -A REGION_NAMES=(
        [GLOBAL]="全球DNS配置"
        [NAMERICA]="北美洲DNS"
        [SAMERICA]="南美洲DNS"
        [EUROPE]="歐洲DNS"
        [AFRICA]="非洲DNS"
        [MEAST]="中東DNS"
        [ASIA]="亞洲DNS"
        [OCEANIA]="大洋洲DNS"
    )

    # 獲取所有可用的 DNS 區域
    get_available_regions() {
        if [ -f "$DNS_CONFIG_FILE" ]; then
            grep -o '^\[[^]]*\]' "$DNS_CONFIG_FILE" | tr -d '[]'
        fi
    }

    # 動態生成菜單選項
    generate_menu_options() {
        local regions=($(get_available_regions))
        local menu_text=""
        local counter=1

        # 添加固定選項
        menu_text+="1. 根據GeoIP自動配置DNS\n"
        menu_text+="2. 手動配置DNS菜單(通過 nano/vim 編輯)\n"
        menu_text+="3. DNS區域管理\n"
        counter=4

        # 添加動態區域選項
        for region in "${regions[@]}"; do
            local name="${REGION_NAMES[$region]:-$region}"
            menu_text+="$counter. 使用${name}\n"
            display_dns_info "$region"
            ((counter++))
        done

        menu_text+="0. 退出"
        echo -e "$menu_text"
    }

    # 修改預設配置文件創建函數
    create_default_dns_config() {
        cat > "$DNS_CONFIG_FILE" << 'EOF'
[GLOBAL]
name=Leading全球DNS優化(Cloudflare & AdGuard)
ipv4_dns=1.0.0.1 94.140.14.15
ipv6_dns=2606:4700:4700::1001 2a00:5a60::ad1:0ff

[NAMERICA]
name=北美洲DNS(Quad9 & OpenDNS)
ipv4_dns=9.9.9.9 208.67.222.222
ipv6_dns=2620:fe::fe 2620:119:35::35

[SAMERICA]
name=南美洲DNS(DNS.BR & LACNIC)
ipv4_dns=200.160.0.11 200.3.13.14
ipv6_dns=2001:12ff::11 2001:13c7:7001::53

[EUROPE]
name=歐洲DNS(DNS.WATCH & UncensoredDNS)
ipv4_dns=84.200.70.40 89.233.43.71
ipv6_dns=2001:1608:10:25::9249:d69b 2a01:3a0:53:53::

[AFRICA]
name=非洲DNS(AfriNIC & Internet Solutions)
ipv4_dns=196.216.2.1 196.4.160.4
ipv6_dns=2001:43f8:110::10 2c0f:ff00:0:35::1:1

[MEAST]
name=中東DNS(TurkTelekom & SaudiNIC)
ipv4_dns=195.175.39.39 212.26.6.5
ipv6_dns=2a00:1450:4016:804::200e 2a02:ed0:1234:5678::10

[ASIA]
name=亞洲DNS(TWNIC & JPNIC)
ipv4_dns=101.102.103.104 203.119.1.1
ipv6_dns=2001:de4::101 2001:dc4::1

[OCEANIA]
name=大洋洲DNS(AusRegistry & NZRS)
ipv4_dns=202.46.190.130 202.46.186.130
ipv6_dns=2401:fd80:404::1 2401:fd80:404::2
EOF
    }

    # 驗證 IP 地址格式
    validate_ip() {
        local ip=$1
        local type=$2
        
        if [ "$type" = "ipv4" ]; then
            if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "錯誤：'$ip' 不是有效的IPv4格式"
                return 1
            fi
            
            # 驗證每個段的範圍
            local IFS='.'
            read -ra ADDR <<< "$ip"
            for i in "${ADDR[@]}"; do
                if [ "$i" -lt 0 ] || [ "$i" -gt 255 ]; then
                    echo "錯誤：'$ip' 中的數值必須在0-255之間"
                    return 1
                fi
            done
        elif [ "$type" = "ipv6" ]; then
            if ! [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
                echo "錯誤：'$ip' 不是有效的IPv6格式"
                return 1
            fi
            
            # 檢查冒號數量
            if [ $(echo "$ip" | tr -cd ':' | wc -c) -gt 7 ]; then
                echo "錯誤：IPv6地址中冒號過多"
                return 1
            fi
        else
            echo "錯誤：未知的IP類型 '$type'"
            return 1
        fi
        
        return 0
    }

    # 驗證區域代碼
    validate_region_code() {
        local region=$1
        local is_modify=${2:-false}  # 新增參數，用於區分新增和修改操作
        
        # 檢查是否為空
        if [[ -z "$region" ]]; then
            echo "錯誤：區域代碼不能為空"
            return 1
        }
        
        # 檢查長度（2-10個字符）
        if [[ ${#region} -lt 2 || ${#region} -gt 10 ]]; then
            echo "錯誤：區域代碼長度必須在2-10個字符之間"
            return 1
        }
        
        # 檢查格式（只允許大寫字母和數字）
        if ! [[ $region =~ ^[A-Z0-9]+$ ]]; then
            echo "錯誤：區域代碼只能包含大寫字母和數字"
            return 1
        }
        
        # 檢查是否為預設區域
        if [[ " ${DEFAULT_REGIONS[@]} " =~ " ${region} " ]]; then
            if [ "$is_modify" = false ]; then
                echo "錯誤：'$region' 是預設區域，不能新增"
                return 1
            fi
        }
        
        # 檢查是否已存在（僅在新增時檢查）
        if [ "$is_modify" = false ]; then
            if grep -q "^\[$region\]$" "$DNS_CONFIG_FILE" 2>/dev/null; then
                echo "錯誤：區域代碼 '$region' 已存在"
                return 1
            }
        fi
        
        return 0
    }

    # 驗證區域描述
    validate_region_description() {
        local description=$1
        
        # 檢查是否為空
        if [[ -z "$description" ]]; then
            echo "錯誤：區域描述不能為空"
            return 1
        fi
        
        # 檢查長度
        if [[ ${#description} -gt 50 ]]; then
            echo "錯誤：區域描述不能超過50個字符"
            return 1
        fi
        
        # 檢查特殊字符
        if [[ "$description" =~ [^[:print:]] ]]; then
            echo "錯誤：區域描述包含無效字符"
            return 1
        fi
        
        return 0
    }

    # 驗證DNS配置
    validate_dns_config() {
        local region=$1
        local ipv4_list=("${ipv4_dns_array[@]}")
        local ipv6_list=("${ipv6_dns_array[@]}")
        
        # 檢查是否至少有一個IPv4 DNS
        if [[ ${#ipv4_list[@]} -eq 0 ]]; then
            echo "錯誤：必須至少配置一個IPv4 DNS服務器"
            return 1
        fi
        
        # 檢查DNS服務器數量限制
        if [[ ${#ipv4_list[@]} -gt 5 ]]; then
            echo "警告：IPv4 DNS服務器數量超過5個可能影響性能"
        fi
        
        if [[ ${#ipv6_list[@]} -gt 5 ]]; then
            echo "警告：IPv6 DNS服務器數量超過5個可能影響性能"
        fi
        
        return 0
    }

    # 添加新的 DNS 區域配置
    add_dns_region() {
        echo "添加新的 DNS 區域配置"
        
        # 區域名稱驗證
        while true; do
            read -p "請輸入區域代碼(2-10個大寫字母或數字，例如: APAC): " region
            if validate_region_code "$region"; then
                break
            else
                echo "錯誤：區域名稱只能包含大寫字母和數字"
            fi
            echo "請重新輸入區域代碼"
        done
        
        # 區域描述驗證
        while true; do
            read -p "請輸入區域描述: " description
            if [[ -z "$description" ]]; then
                echo "錯誤：區域描述不能為空"
                continue
            fi
            if [[ ${#description} -gt 50 ]]; then
                echo "錯誤：區域描述不能超過50個字符"
                continue
            fi
            break
        done
        
        # IPv4 DNS 輸入與驗證
        while true; do
            echo "請輸入 IPv4 DNS (多個地址用空格分隔，至少輸入一個): "
            read -a ipv4_dns_array
            
            # 驗證 IPv4 地址
            valid_ipv4=()
            for ip in "${ipv4_dns_array[@]}"; do
                if validate_ip "$ip" "ipv4"; then
                    valid_ipv4+=("$ip")
                else
                    echo "警告: $ip 不是有效的IPv4地址，已忽略"
                fi
            done
            
            if [[ ${#valid_ipv4[@]} -eq 0 ]]; then
                echo "錯誤：至少需要一個有效的IPv4 DNS地址"
                continue
            fi
            break
        done
        
        # IPv6 DNS 輸入與驗證（可選）
        echo "請輸入 IPv6 DNS (多個地址用空格分隔，可選): "
        read -a ipv6_dns_array
        
        # 驗證 IPv6 地址
        valid_ipv6=()
        for ip in "${ipv6_dns_array[@]}"; do
            if validate_ip "$ip" "ipv6"; then
                valid_ipv6+=("$ip")
            else
                echo "警告: $ip 不是有效的IPv6地址，已忽略"
            fi
        done

        # 確認添加
        echo "即將添加以下配置："
        echo "區域代碼：$region"
        echo "描述：$description"
        echo "IPv4 DNS：${valid_ipv4[*]}"
        [[ ${#valid_ipv6[@]} -gt 0 ]] && echo "IPv6 DNS：${valid_ipv6[*]}"
        
        read -p "確認添加？(y/n): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "操作已取消"
            return 1
        fi

        # 添加新配置
        {
            echo ""
            echo "[$region]"
            echo "name=$description"
            echo "ipv4_dns=${valid_ipv4[*]}"
            [[ ${#valid_ipv6[@]} -gt 0 ]] && echo "ipv6_dns=${valid_ipv6[*]}"
        } >> "$DNS_CONFIG_FILE"

        echo "新的 DNS 區域配置已添加"
        return 0
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
                    ipv4_dns=*) 
                        IFS=' ' read -r -a ipv4_dns_array <<< "${line#*=}"
                        ;;
                    ipv6_dns=*) 
                        IFS=' ' read -r -a ipv6_dns_array <<< "${line#*=}"
                        ;;
                esac
            fi
        done < "$DNS_CONFIG_FILE"
        
        if [ "$section_found" = false ]; then
            echo "錯誤：找不到指定的區域配置"
            return 1
        fi
    }

    # 改進自動設置DNS函數
    auto_set_dns_by_region() {
        local country
        local continent
        
        # 獲取國家代碼
        if ! country=$(curl -s --max-time 5 ipinfo.io/country); then
            echo "警告：無法獲取地理位置信息，使用全球DNS配置"
            load_dns_config "GLOBAL"
            return
        }
        
        # 獲取大洲信息
        if ! continent=$(curl -s --max-time 5 ipinfo.io/timezone | cut -d'/' -f1); then
            echo "警告：無法獲取時區信息，使用全球DNS配置"
            load_dns_config "GLOBAL"
            return
        }
        
        # 根據國家和大洲選擇DNS
        case "$country" in
            # 北美洲
            "US"|"CA"|"MX")
                load_dns_config "NAMERICA"
                ;;
            # 南美洲
            "BR"|"AR"|"CL"|"CO"|"PE"|"VE")
                load_dns_config "SAMERICA"
                ;;
            # 歐洲
            "GB"|"DE"|"FR"|"IT"|"ES"|"NL"|"SE"|"CH"|"NO"|"DK"|"FI"|"PL"|"AT"|"BE"|"IE"|"PT")
                load_dns_config "EUROPE"
                ;;
            # 非洲
            "ZA"|"EG"|"NG"|"KE"|"MA"|"GH"|"TN"|"UG"|"SN")
                load_dns_config "AFRICA"
                ;;
            # 中東
            "TR"|"SA"|"AE"|"IL"|"IQ"|"IR"|"JO"|"KW"|"LB"|"OM"|"QA"|"YE")
                load_dns_config "MEAST"
                ;;
            # 亞洲
            "CN"|"JP"|"KR"|"IN"|"ID"|"TH"|"VN"|"MY"|"PH"|"SG"|"TW"|"HK")
                load_dns_config "ASIA"
                ;;
            # 大洋洲
            "AU"|"NZ"|"FJ"|"PG"|"NC"|"VU")
                load_dns_config "OCEANIA"
                ;;
            *)
                # 如果國家代碼未知，根據大洲選擇
                case "$continent" in
                    "America") load_dns_config "NAMERICA" ;;
                    "Europe") load_dns_config "EUROPE" ;;
                    "Africa") load_dns_config "AFRICA" ;;
                    "Asia") load_dns_config "ASIA" ;;
                    "Oceania") load_dns_config "OCEANIA" ;;
                    *) 
                        echo "無法確定地理位置，使用全球DNS配置"
                        load_dns_config "GLOBAL"
                        ;;
                esac
                ;;
        esac
        
        # 設置DNS並驗證
        if ! set_dns; then
            echo "DNS設置失敗，回退到全球DNS配置"
            load_dns_config "GLOBAL"
            set_dns
        fi
        
        # 測試DNS連接
        test_dns_connection
    }

    # 添加DNS連接測試函數
    test_dns_connection() {
        echo "正在測試DNS連接..."
        local test_domains=("google.com" "cloudflare.com" "microsoft.com")
        local success=0
        
        for domain in "${test_domains[@]}"; do
            if nslookup "$domain" >/dev/null 2>&1; then
                ((success++))
            fi
        done
        
        if [ "$success" -eq 0 ]; then
            echo "警告：DNS解析測試失敗，可能需要手動檢查配置"
            return 1
        elif [ "$success" -lt ${#test_domains[@]} ]; then
            echo "警告：部分DNS解析測試失敗，但仍可使用"
        else
            echo "DNS解析測試成功"
        fi
        
        # 測試IPv6（如果配置了IPv6 DNS）
        if [[ ${#ipv6_dns_array[@]} -gt 0 ]]; then
            echo "測試IPv6連接..."
            if ping6 -c 1 google.com >/dev/null 2>&1; then
                echo "IPv6連接正常"
            else
                echo "警告：IPv6連接測試失敗，但IPv4仍可使用"
            fi
        fi
    }

    # 添加DNS性能測試函數
    test_dns_performance() {
        local dns_server=$1
        local test_domain="google.com"
        local total_time=0
        local tests=3
        
        echo "測試 $dns_server 的響應時間..."
        for ((i=1; i<=tests; i++)); do
            local start_time=$(date +%s%N)
            if dig "@$dns_server" "$test_domain" >/dev/null 2>&1; then
                local end_time=$(date +%s%N)
                local duration=$((($end_time - $start_time)/1000000))
                total_time=$((total_time + duration))
            else
                echo "警告：DNS服務器 $dns_server 響應失敗"
                return 1
            fi
        done
        
        local avg_time=$((total_time / tests))
        echo "DNS服務器 $dns_server 平均響應時間: ${avg_time}ms"
        return 0
    }

    # 定義 set_dns 函數
    set_dns() {
        rm /etc/resolv.conf
        touch /etc/resolv.conf

        # 添加 IPv4 DNS
        for ip in "${ipv4_dns_array[@]}"; do
            echo "nameserver $ip" >> /etc/resolv.conf
        done

        # 添加 IPv6 DNS
        for ip in "${ipv6_dns_array[@]}"; do
            echo "nameserver $ip" >> /etc/resolv.conf
        done

        echo "DNS配置已更新，當前配置:"
        cat /etc/resolv.conf
    }

    # 安裝編輯器
    install_editor() {
        local editor=$1
        local pkg_manager=$(detect_package_manager)
        
        if command -v "$editor" &>/dev/null; then
            echo "$editor 已安裝"
            return 0
        fi

        echo "正在安裝 $editor..."
        case "$pkg_manager" in
            "apt-get")
                apt-get update && apt-get install -y "$editor"
                ;;
            "dnf"|"yum")
                "$pkg_manager" install -y "$editor"
                ;;
            "pacman")
                pacman -Sy --noconfirm "$editor"
                ;;
            "zypper")
                zypper --non-interactive install "$editor"
                ;;
            "apk")
                apk add --no-cache "$editor"
                ;;
            *)
                echo "錯誤：無法識別的包管理器，請手動安裝 $editor"
                return 1
                ;;
        esac

        if [ $? -eq 0 ]; then
            echo "$editor 安裝成功"
            return 0
        else
            echo "錯誤：$editor 安裝失敗"
            return 1
        fi
    }

    # 檢查編輯器可用性
    check_editor_availability() {
        local editor=$1
        if command -v "$editor" &>/dev/null; then
            return 0
        fi
        return 1
    }

    # 獲取已安裝的編輯器列表
    get_installed_editors() {
        local installed=()
        for editor in "${!SUPPORTED_EDITORS[@]}"; do
            if check_editor_availability "$editor"; then
                installed+=("$editor")
            fi
        done
        echo "${installed[@]}"
    }

    # 手動編輯DNS配置子菜單
    manual_edit_dns_menu() {
        local installed_editors=($(get_installed_editors))
        local default_editor=""
        
        # 設置默認編輯器
        if check_editor_availability "nano"; then
            default_editor="nano"
        elif check_editor_availability "vim"; then
            default_editor="vim"
        elif check_editor_availability "vi"; then
            default_editor="vi"
        fi

        while true; do
            clear
            echo "手動編輯DNS配置"
            echo "=========================="
            echo "當前DNS配置:"
            cat /etc/resolv.conf
            echo "=========================="
            echo "可用編輯器:"
            
            local counter=1
            for editor in "${installed_editors[@]}"; do
                echo "$counter. $editor - ${SUPPORTED_EDITORS[$editor]}"
                if [ "$editor" = "$default_editor" ]; then
                    echo "   (推薦)"
                fi
                ((counter++))
            done
            
            echo "------------------------"
            echo "a. 安裝新編輯器"
            echo "r. 刷新編輯器列表"
            echo "0. 返回上一級菜單"
            echo "------------------------"
            
            read -e -p "請選擇編輯器或操作 (輸入0返回): " choice
            
            case "$choice" in
                [1-9])
                    if [ "$choice" -le "${#installed_editors[@]}" ]; then
                        local selected_editor="${installed_editors[$((choice-1))]}"
                        if ! check_editor_availability "$selected_editor"; then
                            echo "錯誤：$selected_editor 不可用"
                            read -n 1 -s -r -p "按任意鍵繼續..."
                            continue
                        fi
                        
                        # 備份配置
                        cp /etc/resolv.conf "/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
                        
                        # 使用選定的編輯器
                        if "$selected_editor" /etc/resolv.conf; then
                            echo "配置已更新"
                            echo "新的DNS配置:"
                            cat /etc/resolv.conf
                        else
                            echo "警告：編輯過程可能出現問題"
                        fi
                    else
                        echo "無效選項"
                    fi
                    ;;
                "a")
                    clear
                    echo "可安裝的編輯器:"
                    counter=1
                    for editor in "${!SUPPORTED_EDITORS[@]}"; do
                        if ! check_editor_availability "$editor"; then
                            echo "$counter. $editor - ${SUPPORTED_EDITORS[$editor]}"
                            ((counter++))
                        fi
                    done
                    echo "0. 返回"
                    
                    read -e -p "請選擇要安裝的編輯器 (輸入0返回): " install_choice
                    if [[ "$install_choice" =~ ^[1-9]+$ ]]; then
                        local editor_to_install=""
                        counter=1
                        for editor in "${!SUPPORTED_EDITORS[@]}"; do
                            if ! check_editor_availability "$editor"; then
                                if [ "$counter" = "$install_choice" ]; then
                                    editor_to_install="$editor"
                                    break
                                fi
                                ((counter++))
                            fi
                        done
                        
                        if [ -n "$editor_to_install" ]; then
                            install_editor "$editor_to_install"
                            installed_editors=($(get_installed_editors))
                        fi
                    fi
                    ;;
                "r")
                    installed_editors=($(get_installed_editors))
                    echo "編輯器列表已更新"
                    ;;
                "0")
                    break
                    ;;
                *)
                    echo "無效選項"
                    ;;
            esac
            
            read -n 1 -s -r -p "按任意鍵繼續..."
        done
    }

    # DNS區域管理菜單
    manage_dns_regions() {
        while true; do
            clear
            echo "DNS區域管理"
            echo "------------------------"
            echo "1. 添加新DNS區域"
            echo "2. 修改現有DNS區域"
            echo "3. 刪除DNS區域"
            echo "4. 查看所有DNS區域"
            echo "0. 返回上一級菜單"
            echo "------------------------"
            
            read -e -p "請選擇 (輸入0返回): " choice
            case "$choice" in
                1) 
                    add_dns_region
                    echo "新增區域配置:"
                    cat "$DNS_CONFIG_FILE" | tail -n 6
                    ;;
                2) 
                    modify_dns_region
                    echo "修改後的配置:"
                    cat "$DNS_CONFIG_FILE"
                    ;;
                3) delete_dns_region ;;
                4) view_dns_regions ;;
                0) break ;;
                *) echo "無效選項" ;;
            esac
            read -n 1 -s -r -p "按任意鍵繼續..."
        done
    }

    # 修改DNS區域配置
    modify_dns_region() {
        if [ ! -f "$DNS_CONFIG_FILE" ]; then
            echo "錯誤：DNS配置文件不存在"
            return 1
        }

        echo "現有DNS區域："
        local regions=($(get_available_regions))
        local counter=1
        
        # 顯示當前配置
        for region in "${regions[@]}"; do
            local name="${REGION_NAMES[$region]:-$region}"
            local is_default=""
            [[ " ${DEFAULT_REGIONS[@]} " =~ " ${region} " ]] && is_default=" (預設)"
            echo "$counter. $region - $name$is_default"
            ((counter++))
        done
        
        # 選擇區域
        while true; do
            read -p "請輸入要修改的區域編號 (0返回): " choice
            [[ "$choice" == "0" ]] && return 0
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#regions[@]} ]; then
                region="${regions[$((choice-1))]}"
                break
            fi
            echo "錯誤：無效的選擇，請重新輸入"
        done

        # 檢查是否為預設區域
        if [[ " ${DEFAULT_REGIONS[@]} " =~ " ${region} " ]]; then
            echo "警告：您正在修改預設區域 '$region'"
            echo "修改預設區域可能會影響系統穩定性"
            read -p "是否確定要繼續？(yes/no): " confirm
            if [[ ! "$confirm" == "yes" ]]; then
                echo "操作已取消"
                return 1
            fi
        fi

        # 讀取當前配置
        local current_config=$(awk -v region="[$region]" '
            $0 == region {print; in_region=1; next}
            /^\[/ {in_region=0}
            in_region {print}
        ' "$DNS_CONFIG_FILE")
        
        echo "當前配置："
        echo "$current_config"
        echo ""

        # 備份配置
        local backup_file="/tmp/dns_config_backup_$(date +%Y%m%d_%H%M%S)"
        cp "$DNS_CONFIG_FILE" "$backup_file"
        
        # 修改配置
        local temp_file=$(mktemp)
        local modified=false
        
        # 區域描述修改
        read -p "是否修改區域描述？(y/n): " modify_desc
        if [[ "$modify_desc" =~ ^[Yy]$ ]]; then
            while true; do
                read -p "新區域描述: " new_desc
                if validate_region_description "$new_desc"; then
                    modified=true
                    break
                fi
            done
        fi
        
        # DNS服務器修改
        read -p "是否修改DNS服務器配置？(y/n): " modify_dns
        if [[ "$modify_dns" =~ ^[Yy]$ ]]; then
            # IPv4 DNS修改
            while true; do
                echo "請輸入IPv4 DNS地址 (多個地址用空格分隔):"
                read -a new_dns_ipv4_array
                
                # 驗證IPv4地址
                valid_ipv4=()
                for ip in "${new_dns_ipv4_array[@]}"; do
                    if validate_ip "$ip" "ipv4"; then
                        valid_ipv4+=("$ip")
                    fi
                done
                
                if [[ ${#valid_ipv4[@]} -gt 0 ]]; then
                    modified=true
                    break
                else
                    echo "錯誤：至少需要一個有效的IPv4 DNS地址"
                fi
            done
            
            # IPv6 DNS修改
            echo "請輸入IPv6 DNS地址 (多個地址用空格分隔，可選):"
            read -a new_dns_ipv6_array
            valid_ipv6=()
            for ip in "${new_dns_ipv6_array[@]}"; do
                if validate_ip "$ip" "ipv6"; then
                    valid_ipv6+=("$ip")
                    modified=true
                fi
            done
        fi
        
        # 如果沒有修改，直接返回
        if [ "$modified" = false ]; then
            echo "未進行任何修改"
            rm "$temp_file"
            return 0
        fi
        
        # 確認修改
        echo "修改後的配置："
        echo "[$region]"
        [[ -n "$new_desc" ]] && echo "name=$new_desc"
        [[ ${#valid_ipv4[@]} -gt 0 ]] && echo "ipv4_dns=${valid_ipv4[*]}"
        [[ ${#valid_ipv6[@]} -gt 0 ]] && echo "ipv6_dns=${valid_ipv6[*]}"
        
        read -p "確認更新配置？(yes/no): " confirm
        if [[ ! "$confirm" == "yes" ]]; then
            echo "操作已取消"
            rm "$temp_file"
            return 1
        fi

        # 更新配置文件
        awk -v region="[$region]" \
            -v new_desc="$new_desc" \
            -v ipv4_dns="${valid_ipv4[*]}" \
            -v ipv6_dns="${valid_ipv6[*]}" '
        $0 == region {
            print;
            in_region=1;
            next
        }
        /^\[/ {
            if (in_region) {
                if (new_desc != "") print "name=" new_desc;
                if (ipv4_dns != "") print "ipv4_dns=" ipv4_dns;
                if (ipv6_dns != "") print "ipv6_dns=" ipv6_dns;
            }
            in_region=0;
            print;
            next
        }
        !in_region {print}
        ' "$DNS_CONFIG_FILE" > "$temp_file"

        # 驗證新配置
        if ! validate_dns_config "$region"; then
            echo "錯誤：新配置驗證失敗，正在還原..."
            cp "$backup_file" "$DNS_CONFIG_FILE"
            rm "$temp_file"
            return 1
        fi

        # 應用新配置
        mv "$temp_file" "$DNS_CONFIG_FILE"
        echo "配置已成功更新"
        
        # 顯示更新後的配置
        echo "更新後的完整配置:"
        awk -v region="[$region]" '
            $0 == region {print; in_region=1; next}
            /^\[/ {in_region=0}
            in_region {print}
        ' "$DNS_CONFIG_FILE"
        
        return 0
    }

    # 刪除DNS區域
    delete_dns_region() {
        echo "現有DNS區域："
        local regions=($(get_available_regions))
        local counter=1
        for region in "${regions[@]}"; do
            local name="${REGION_NAMES[$region]:-$region}"
            echo "$counter. $region - $name"
            ((counter++))
        done
        
        read -p "請輸入要刪除的區域編號: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#regions[@]} ]; then
            region="${regions[$((choice-1))]}"
        else
            echo "無效選擇"
            return 1
        fi
        
        # 防止刪除預設區域
        if [[ " ${DEFAULT_REGIONS[@]} " =~ " ${region} " ]]; then
            read -p "預設DNS配置項無法刪除, 是否要恢復 $region 區域的預設配置? (y/n): " restore
            if [[ "$restore" =~ ^[Yy]$ ]]; then
                # 臨時文件
                temp_file=$(mktemp)
                # 保存當前配置
                grep -v "^\[$region\]" "$DNS_CONFIG_FILE" > "$temp_file"
                # 只恢復指定區域的預設配置
                create_default_dns_config | awk -v region="[$region]" '
                    $0 == region {print; in_region=1; next}
                    /^\[/ {in_region=0}
                    in_region {print}
                ' >> "$temp_file"
                mv "$temp_file" "$DNS_CONFIG_FILE"
                echo "已恢復 $region 區域的預設配置"
                return 0
            else
                echo "操作已取消"
                return 1
        fi
        # 臨時文件
        temp_file=$(mktemp)
        
        # 刪除指定區域
        awk -v region="[$region]" '
            $0 == region {skip=1; next}
            /^\[.*\]/ {skip=0}
            !skip {print}
        ' "$DNS_CONFIG_FILE" > "$temp_file"
        
        mv "$temp_file" "$DNS_CONFIG_FILE"
        echo "區域已刪除"
    }

    # 查看DNS區域配置
    view_dns_regions() {
        if [ -f "$DNS_CONFIG_FILE" ]; then
            less "$DNS_CONFIG_FILE"
        else
            echo "DNS配置文件不存在"
        fi
    }

    # 顯示DNS信息
    display_dns_info() {
        local region=$1
        echo "  IPv4: $(grep "ipv4_dns" "$DNS_CONFIG_FILE" | grep -A2 "\[$region\]" | head -n1 | cut -d= -f2)"
        echo "  IPv6: $(grep "ipv6_dns" "$DNS_CONFIG_FILE" | grep -A2 "\[$region\]" | head -n1 | cut -d= -f2)"
    }

    # 如果是交互模式，啟動菜單界面
    if [ "$INTERACTIVE" = true ]; then
        show_language_menu
        load_messages
        set_dns_ui
    else
        show_help
    fi

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
}

# 調用主程序
main "$@"