#!/bin/bash

# 全域變數
VERSION="2.0.0"
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/etc/ssh/backup"
LOG_FILE="/var/log/rootsetup.log"
TEMP_FILES=()
ORIGINAL_CONFIG=""
DEFAULT_SSH_PORT=22
SSH_PORTS=()

# 使用者輸入記錄
USER_PASSWORD=""
USER_PORTS=""
COMMAND_EXAMPLE=""

# 錯誤代碼
E_ROOT=1
E_BACKUP=2
E_CONFIG=3
E_SYSTEM_ERROR=4
E_UNSUPPORTED=5
E_COMMAND_NOT_FOUND=6
E_PERMISSION=7
E_PASSWORD=8
E_NETWORK=9
E_SERVICE=10

# 密碼要求
MIN_PASSWORD_LENGTH=8
MAX_PASSWORD_LENGTH=32

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日誌函數
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[$timestamp] [$level] $message${NC}" >&2
    fi
}

# 清理函數
cleanup() {
    local exit_code=$?
    log "INFO" "開始清理操作..."
    
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log "INFO" "清理臨時檔案: $temp_file"
        fi
    done
    
    if [[ $exit_code -ne 0 ]] && [[ -n "$ORIGINAL_CONFIG" ]]; then
        log "WARN" "檢測到錯誤，正在恢復原始配置..."
        echo "$ORIGINAL_CONFIG" > "$SSHD_CONFIG"
        chmod 600 "$SSHD_CONFIG"
        service ssh restart || systemctl restart sshd
    fi
    
    exit $exit_code
}

# 錯誤處理函數
error_exit() {
    local message="$1"
    local code="${2:-1}"
    log "ERROR" "$message (錯誤代碼: $code)"
    exit "$code"
}

# 生成隨機密碼
generate_random_password() {
    local length=18
    local chars='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789@#$%^&*()?_+'
    local password=""
    
    password+="${chars:$((RANDOM % 26)):1}"
    password+="${chars:$((26 + RANDOM % 24)):1}"
    password+="${chars:$((50 + RANDOM % 9)):1}"
    password+="${chars:$((59 + RANDOM % 12)):1}"
    
    while [[ ${#password} -lt $length ]]; do
        password+="${chars:$((RANDOM % ${#chars})):1}"
    done
    
    echo "$(echo "$password" | fold -w1 | shuf | tr -d '\n')"
}

# 生成隨機端口
generate_random_port() {
    local min_port=10000
    local max_port=65000
    local port
    
    while true; do
        port=$((RANDOM % (max_port - min_port + 1) + min_port))
        if ! netstat -tuln | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
}

# 驗證端口
validate_port() {
    local port=$1
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ "$port" -lt 1024 || "$port" -gt 65535 ]]; then
        return 1
    fi
    
    if netstat -tuln | grep -q ":$port "; then
        return 1
    fi
    
    return 0
}

# 驗證密碼
validate_password() {
    local password="$1"
    
    if [[ ${#password} -lt $MIN_PASSWORD_LENGTH ]]; then
        error_exit "密碼長度不能小於 $MIN_PASSWORD_LENGTH 個字符" $E_PASSWORD
    fi
    
    if [[ ${#password} -gt $MAX_PASSWORD_LENGTH ]]; then
        error_exit "密碼長度不能大於 $MAX_PASSWORD_LENGTH 個字符" $E_PASSWORD
    fi
    
    if ! echo "$password" | grep -q "[A-Z]"; then
        error_exit "密碼必須包含至少一個大寫字母" $E_PASSWORD
    fi
    
    if ! echo "$password" | grep -q "[a-z]"; then
        error_exit "密碼必須包含至少一個小寫字母" $E_PASSWORD
    fi
    
    if ! echo "$password" | grep -q "[0-9]"; then
        error_exit "密碼必須包含至少一個數字" $E_PASSWORD
    fi
    
    if ! echo "$password" | grep -q "[!@#$%^&*()_+]"; then
        error_exit "密碼必須包含至少一個特殊字符" $E_PASSWORD
    fi
}

# 生成命令示例
generate_command_example() {
    local password="$1"
    local ports="$2"
    
    password=$(printf '%q' "$password")
    
    COMMAND_EXAMPLE="sudo ./rootsetup.sh -p \"$password\" -P \"$ports\""
    
    echo -e "\n${GREEN}=== 一鍵執行指令示例 ===${NC}"
    echo "# 您可以使用以下命令直接執行相同的配置："
    echo -e "${YELLOW}$COMMAND_EXAMPLE${NC}"
    echo -e "\n# 或者使用以下命令在其他伺服器上執行相同的配置："
    echo -e "${YELLOW}wget -O rootsetup.sh https://raw.githubusercontent.com/eslco/base/main/rootsetup.sh"
    echo "chmod +x rootsetup.sh"
    echo -e "$COMMAND_EXAMPLE${NC}"
    echo -e "\n${RED}注意：請確保在使用一鍵指令前備份重要數據。${NC}"
}

# 顯示使用說明
show_usage() {
    echo -e "\n${GREEN}=== 使用說明 ===${NC}"
    echo "本腳本支持以下參數："
    echo "-p, --password    指定 ROOT 密碼"
    echo "-P, --ports      指定 SSH 端口（多個端口用逗號分隔）"
    echo "-h, --help       顯示此幫助信息"
    echo
    echo "示例："
    echo -e "${YELLOW}1. 指定單個端口：   $0 -p \"密碼\" -P 2222"
    echo "2. 指定多個端口：   $0 -p \"密碼\" -P \"2222,3333,4444\""
    echo "3. 使用隨機密碼：   $0 -p \"\$(openssl rand -base64 18)\" -P 2222"
    echo -e "4. 交互式配置：   $0${NC}\n"
}

# 顯示菜單
show_menu() {
    clear
    echo -e "${GREEN}=== SSH 配置工具 v$VERSION ===${NC}"
    echo "1. 手動指定 ROOT 密碼"
    echo "2. 生成隨機 ROOT 密碼"
    echo "3. 指定 SSH 端口"
    echo "4. 使用隨機 SSH 端口"
    echo "5. 顯示使用說明"
    echo "6. 開始配置"
    echo "7. 退出"
    echo -e "${YELLOW}======================="
    echo -e "當前配置:"
    [[ -n "$USER_PASSWORD" ]] && echo "密碼: *****(已設置)" || echo "密碼: 未設置"
    [[ -n "$USER_PORTS" ]] && echo "端口: $USER_PORTS" || echo "端口: 未設置"
    echo -e "=======================${NC}"
}

# 處理端口輸入
handle_ports_input() {
    local ports_input=$1
    local -a new_ports=()
    
    IFS=', ' read -r -a port_array <<< "$ports_input"
    
    for port in "${port_array[@]}"; do
        if validate_port "$port"; then
            new_ports+=("$port")
        else
            error_exit "無效的端口: $port" $E_CONFIG
        fi
    done
    
    if [[ ${#new_ports[@]} -eq 0 ]]; then
        error_exit "未提供有效端口" $E_CONFIG
    fi
    
    SSH_PORTS=("${new_ports[@]}")
}

# 系統檢測函數
check_system() {
    if [[ ! -f /etc/os-release ]]; then
        error_exit "無法檢測操作系統類型" $E_UNSUPPORTED
    fi
    
    . /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            log "INFO" "檢測到 Debian 系統: $ID $VERSION_ID"
            ;;
        centos|rhel|fedora)
            log "INFO" "檢測到 RedHat 系統: $ID $VERSION_ID"
            ;;
        *)
            error_exit "不支持的操作系統: $ID" $E_UNSUPPORTED
            ;;
    esac
}

# 配置 SSH
configure_ssh() {
    local backup_file="$BACKUP_DIR/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    
    mkdir -p "$BACKUP_DIR" || error_exit "無法創建備份目錄" $E_BACKUP
    chmod 700 "$BACKUP_DIR"
    
    cp "$SSHD_CONFIG" "$backup_file" || error_exit "無法備份 SSH 配置文件" $E_BACKUP
    chmod 600 "$backup_file"
    
    local temp_config=$(mktemp)
    TEMP_FILES+=("$temp_config")
    chmod 600 "$temp_config"
    
    {
        echo "# Generated by rootsetup.sh v$VERSION"
        echo "# $(date)"
        
        for port in "${SSH_PORTS[@]}"; do
            echo "Port $port"
        done
        
        cat << EOF
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
UsePAM yes
X11Forwarding yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 120
ClientAliveCountMax 3
MaxAuthTries 6
PermitEmptyPasswords no
Protocol 2

Match Group root
    AllowAgentForwarding yes
    AllowTcpForwarding yes
    X11Forwarding yes
    PermitTTY yes
    
Match all
    AllowAgentForwarding no
    AllowTcpForwarding no
    X11Forwarding no
EOF
    } > "$temp_config"

    if [[ "$ID" == "ubuntu" ]]; then
        echo "ChallengeResponseAuthentication yes" >> "$temp_config"
    fi

    if ! sshd -t -f "$temp_config"; then
        error_exit "SSH 配置驗證失敗" $E_CONFIG
    fi

    mv "$temp_config" "$SSHD_CONFIG" || error_exit "無法更新 SSH 配置" $E_CONFIG
    chmod 600 "$SSHD_CONFIG"

    case "$ID" in
        ubuntu|debian)
            service ssh restart || error_exit "SSH 服務重啟失敗" $E_SERVICE
            ;;
        centos|rhel|fedora)
            systemctl restart sshd || error_exit "SSH 服務重啟失敗" $E_SERVICE
            ;;
    esac

    log "INFO" "SSH 配置更新成功"
}

# 主程序
main() {
    trap cleanup EXIT
    
    if [[ "$(id -u)" -ne 0 ]]; then
        error_exit "必須以 root 身份運行此腳本" $E_ROOT
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--password)
                USER_PASSWORD="$2"
                shift 2
                ;;
            -P|--ports)
                USER_PORTS="$2"
                handle_ports_input "$USER_PORTS"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error_exit "未知參數: $1"
                ;;
        esac
    done

    if [[ -z "$USER_PASSWORD" || -z "$USER_PORTS" ]]; then
        while true; do
            show_menu
            read -p "請選擇操作 [1-7]: " choice
            
            case $choice in
                1)
                    read -sp "請輸入新的 ROOT 密碼: " USER_PASSWORD
                    echo
                    ;;
                2)
                    USER_PASSWORD=$(generate_random_password)
                    echo -e "${GREEN}生成的隨機密碼: $USER_PASSWORD${NC}"
                    read -p "按回車繼續..."
                    ;;
                3)
                    read -p "請輸入 SSH 端口(多個端口用逗號分隔): " USER_PORTS
                    handle_ports_input "$USER_PORTS"
                    ;;
                4)
                    port=$(generate_random_port)
                    USER_PORTS="$port"
                    SSH_PORTS=("$port")
                    echo -e "${GREEN}生成的隨機端口: $port${NC}"
                    read -p "按回車繼續..."
                    ;;
                5)
                    show_usage
                    read -p "按回車繼續..."
                    ;;
                6)
                    if [[ -n "$USER_PASSWORD" && -n "$USER_PORTS" ]]; then
                        break
                    else
                        echo -e "${RED}錯誤: 請先設置密碼和端口${NC}"
                        read -p "按回車繼續..."
                    fi
                    ;;
                7)
                    exit 0
                    ;;
                *)
                    echo -e "${RED}無效的選擇${NC}"
                    read -p "按回車繼續..."
                    ;;
            esac
        done
    fi

    pre_check
    check_system
    validate_password "$USER_PASSWORD"

    echo -e "${YELLOW}即將進行以下配置：${NC}"
    echo "1. 修改 ROOT 密碼"
    echo "2. 配置 SSH 端口: ${SSH_PORTS[*]}"
    echo -e "${RED}警告：此操作將修改系統配置，請確保數據已備份${NC}"
    read -p "是否繼續？[y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

    log "INFO" "開始修改 root 密碼..."
    if ! echo "root:$USER_PASSWORD" | chpasswd; then
        error_exit "修改密碼失敗" $E_SYSTEM_ERROR
    fi
    log "INFO" "root 密碼修改成功"

    log "INFO" "開始更新 SSH 配置..."
    configure_ssh

    generate_command_example "$USER_PASSWORD" "$USER_PORTS"

    echo -e "\n${GREEN}=== 配置完成 ===${NC}"
    echo "ROOT 密碼已更新"
    echo "SSH 端口: ${SSH_PORTS[*]}"
    log "INFO" "腳本執行完成"
    
    log "INFO" "已配置端口: ${SSH_PORTS[*]}"
    log "INFO" "命令示例已生成"
}

# 執行主程序
main "$@"