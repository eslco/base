#!/bin/bash

# 版 版本信息

VERSION="1.1.0"



# 全局常量

readonly SCRIPT_PATH=$(readlink -f "$0")

readonly SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

readonly LOG_FILE="/var/log/system_config.log"

readonly BACKUP_DIR="/var/backups/system_config"

readonly SSHD_CONFIG="/etc/ssh/sshd_config"

readonly INSTALL_PATH="/usr/local/bin/system_config"

readonly DEFAULT_PORT_CONFIG="/etc/system_config/default_ports.conf"

readonly PORT_CONFIG_DIR="/etc/system_config"

readonly TEMP_DIR="/tmp/system_config"



# 配置限制

readonly MIN_PORT=1024

readonly MAX_PORT=65535

readonly MAX_SSH_PORTS=5

readonly MIN_PASSWORD_LENGTH=12

readonly MAX_PASSWORD_LENGTH=128

readonly DEFAULT_PASSWORD_LENGTH=32



# 特殊字符集(跨平台兼容)

readonly SPECIAL_CHARS='@#$%^&*()_+=?.'



# 错误代码

declare -r E_NOTROOT=87

declare -r E_NOSYSTEM=86

declare -r E_NOBACKUP=85

declare -r E_NOPERM=84

declare -r E_CONFIG=83

declare -r E_INVALID_INPUT=82

declare -r E_SYSTEM_ERROR=81



# 初始化函数

init() {

    # 创建必要的目录

    mkdir -p "$BACKUP_DIR" "$PORT_CONFIG_DIR" "$TEMP_DIR"

    chmod 700 "$BACKUP_DIR" "$PORT_CONFIG_DIR" "$TEMP_DIR"

    

    # 初始化日志

    init_logging

    

    # 设置umask

    umask 077

    

    # 检查系统环境

    check_environment

}



# 初始化日志函数

init_logging() {

    local log_dir=$(dirname "$LOG_FILE")

    if [ ! -d "$log_dir" ]; then

        mkdir -p "$log_dir"

        chmod 700 "$log_dir"

    fi

    touch "$LOG_FILE"

    chmod 600 "$LOG_FILE"

    

    exec 3>&1 4>&2

    trap 'exec 1>&3 2>&4' 0 1 2 3

    exec 1> >(tee -a "$LOG_FILE") 2>&1

}



# 日志函数

log() {

    local level=$1

    shift

    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"

}



# 错误处理函数

error_exit() {

    log "ERROR" "$1"

    cleanup

    exit "${2:-1}"

}



# 清理函数

cleanup() {

    log "INFO" "执行清理操作..."

    rm -rf "${TEMP_DIR:?}"/*

    exec 1>&3 2>&4

}



# 安全检查函数

security_check() {

    # 检查文件权限

    local files_to_check=(

        "$SSHD_CONFIG"

        "$DEFAULT_PORT_CONFIG"

        "$LOG_FILE"

    )

    for file in "${files_to_check[@]}"; do

        if [ -f "$file" ]; then

            local perms=$(stat -c "%a" "$file")

            if [ "$perms" -gt 600 ]; then

                chmod 600 "$file"

                log "WARNING" "修正了文件权限: $file"

            fi

        fi

    done

    # 检查目录权限

    local dirs_to_check=(

        "$BACKUP_DIR"

        "$PORT_CONFIG_DIR"

        "$TEMP_DIR"

    )

    for dir in "${dirs_to_check[@]}"; do

        if [ -d "$dir" ]; then

            local perms=$(stat -c "%a" "$dir")

            if [ "$perms" -gt 700 ]; then

                chmod 700 "$dir"

                log "WARNING" "修正了目录权限: $dir"

            fi

        fi

    done

}

# 系统环境检查函数

check_environment() {

    log "INFO" "检查系统环境..."

    # 检查操作系统

    if [ ! -f /etc/os-release ]; then

        error_exit "不支持的操作系统" $E_NOSYSTEM

    }

    # 检查必要命令

    local required_commands=(

        "sshd"

        "chpasswd"

        "sed"

        "openssl"

        "netstat"

        "awk"

        "grep"

        "mktemp"

    )

    for cmd in "${required_commands[@]}"; do

        if ! command -v "$cmd" >/dev/null 2>&1; then

            error_exit "缺少必要命令: $cmd" $E_NOSYSTEM

        fi

    done

    # 执行安全检查

    security_check

}
# 生成随机密码函数

generate_password() {

    local length=${1:-$DEFAULT_PASSWORD_LENGTH}

    local password=""

    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789${SPECIAL_CHARS}"

    # 验证长度参数

    if [ "$length" -lt "$MIN_PASSWORD_LENGTH" ] || [ "$length" -gt "$MAX_PASSWORD_LENGTH" ]; then

        error_exit "无效的密码长度: $length" $E_INVALID_INPUT

    fi  

    # 确保至少包含每种类型的字符

    password+=$(echo ${chars:26:26} | fold -w1 | shuf | head -n1)  # 大写字母

    password+=$(echo ${chars:0:26} | fold -w1 | shuf | head -n1)   # 小写字母

    password+=$(echo ${chars:52:10} | fold -w1 | shuf | head -n1)  # 数字

    password+=$(echo ${SPECIAL_CHARS} | fold -w1 | shuf | head -n1) # 特殊字符

  # 生成剩余字符

    local remain=$((length - 4))

    for ((i=0; i<remain; i++)); do

        password+=$(echo $chars | fold -w1 | shuf | head -n1)

    done

    # 使用 openssl 进行额外随机化

    echo $password | fold -w1 | shuf -n$length | tr -d '\n'

}
# 验证密码复杂度

validate_password() {

    local password=$1

    local length=${#password}
    # 检查长度

    if [ $length -lt $MIN_PASSWORD_LENGTH ] || [ $length -gt $MAX_PASSWORD_LENGTH ]; then

        return 1

    fi
    # 检查复杂度

    [[ "$password" =~ [A-Z] ]] && \

    [[ "$password" =~ [a-z] ]] && \

    [[ "$password" =~ [0-9] ]] && \

    [[ "$password" =~ [$SPECIAL_CHARS] ]]

    return $?

}
# 验证端口号函数
validate_port() {
    local port=$1
    
    # 检查是否为数字
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        echo "端口必须是数字"
        return 1
    fi
    
    # 检查范围
    if [ "$port" -lt "$MIN_PORT" ] || [ "$port" -gt "$MAX_PORT" ]; then
        echo "端口必须在 $MIN_PORT 到 $MAX_PORT 之间"
        return 1
    fi
    
    # 检查是否被占用
    if netstat -tuln | grep -q ":$port "; then
        echo "端口 $port 已被占用"
        return 1
    fi
    
    return 0
}

# 生成随机端口
generate_random_ports() {
    local count=$1
    local -a used_ports
    local -a selected_ports
    
    # 验证端口数量
    if [ "$count" -gt "$MAX_SSH_PORTS" ]; then
        error_exit "端口数量超过最大限制 $MAX_SSH_PORTS" $E_INVALID_INPUT
    fi
    
    # 获取已使用的端口
    mapfile -t used_ports < <(netstat -tuln | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)
    
    # 生成随机端口
    local attempts=0
    local max_attempts=100
    
    while [ ${#selected_ports[@]} -lt "$count" ] && [ "$attempts" -lt "$max_attempts" ]; do
        local port=$((RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT))
        
        # 检查端口是否可用
        if [[ ! " ${used_ports[@]} " =~ " ${port} " ]] && \
           [[ ! " ${selected_ports[@]} " =~ " ${port} " ]]; then
            selected_ports+=($port)
        fi
        
        ((attempts++))
    done
    
    if [ ${#selected_ports[@]} -lt "$count" ]; then
        error_exit "无法生成足够的可用端口" $E_SYSTEM_ERROR
    fi
    
    echo "${selected_ports[@]}"
}

# 保存默认端口配置
save_default_ports() {
    local ports=("$@")
    
    # 创建临时文件
    local temp_file=$(mktemp)
    chmod 600 "$temp_file"
    
    # 写入端口配置
    printf "%s\n" "${ports[@]}" > "$temp_file"
    
    # 原子方式更新配置文件
    mv "$temp_file" "$DEFAULT_PORT_CONFIG"
    chmod 600 "$DEFAULT_PORT_CONFIG"
    
    log "INFO" "已保存默认端口配置: ${ports[*]}"
}

# 配置 SSH 端口
configure_ssh_ports() {
    local -a ports
    local port_count
    
    echo "SSH 端口配置"
    echo "1. 手动输入端口"
    echo "2. 生成随机端口"
    echo "3. 使用默认端口"
    read -p "请选择 (1-3): " choice
    
    case $choice in
        1)  # 手动输入
            echo "请输入端口号 (最多 $MAX_SSH_PORTS 个，输入空行结束)"
            while [ ${#ports[@]} -lt $MAX_SSH_PORTS ]; do
                read -p "端口 $((${#ports[@]} + 1)): " port
                
                [ -z "$port" ] && break
                
                if validate_port "$port"; then
                    ports+=($port)
                else
                    echo "无效端口号，请重试"
                fi
            done
            ;;
            
        2)  # 随机生成
            read -p "需要生成几个端口? (1-$MAX_SSH_PORTS): " port_count
            if [[ "$port_count" =~ ^[1-$MAX_SSH_PORTS]$ ]]; then
                ports=($(generate_random_ports $port_count))
                echo "已生成端口: ${ports[*]}"
            else
                error_exit "无效的端口数量" $E_INVALID_INPUT
            fi
            ;;
            
        3)  # 使用默认端口
            if [ -f "$DEFAULT_PORT_CONFIG" ]; then
                mapfile -t ports < "$DEFAULT_PORT_CONFIG"
                echo "使用默认端口: ${ports[*]}"
            else
                ports=(59527 5522)
                echo "使用系统预设端口: ${ports[*]}"
            fi
            ;;
            
        *)
            error_exit "无效选择" $E_INVALID_INPUT
            ;;
    esac
    
    # 询问是否保存为默认配置
    if [ ${#ports[@]} -gt 0 ]; then
        read -p "是否保存为默认配置? (y/n): " save_default
        if [[ $save_default =~ ^[Yy]$ ]]; then
            save_default_ports "${ports[@]}"
        fi
    fi
    
    echo "${ports[@]}"
}

# SSH 配置检查函数
check_sshd_config() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if sshd -t; then
            log "INFO" "SSH 配置检查通过"
            return 0
        else
            log "WARNING" "SSH 配置检查失败 (尝试 $attempt/$max_attempts)"
            read -p "是否查看详细错误信息？(y/n): " choice
            case $choice in
                [Yy]* ) sshd -T;;
                [Nn]* ) 
                    if [ $attempt -lt $max_attempts ]; then
                        read -p "是否继续修改配置？(y/n): " continue_choice
                        if [[ $continue_choice =~ ^[Nn]$ ]]; then
                            return 1
                        fi
                    fi
                    ;;
            esac
            ((attempt++))
        fi
    done
    
    return 1
}

# 修改 SSH 配置函数
configure_ssh() {
    local backup_file="$BACKUP_DIR/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SSHD_CONFIG" "$backup_file" || error_exit "无法备份 SSH 配置文件" $E_BACKUP
    
    log "INFO" "开始配置 SSH..."
    
    # 获取端口配置
    local -a ports=($(configure_ssh_ports))
    
    if [ ${#ports[@]} -eq 0 ]; then
        error_exit "未配置有效端口" $E_CONFIG
    fi
    
    # 创建临时配置文件
    local temp_config=$(mktemp)
    chmod 600 "$temp_config"
    
    # 更新配置
    {
        echo "# Generated by system_config tool v$VERSION"
        echo "# $(date)"
        
        # 添加端口配置
        for port in "${ports[@]}"; do
            echo "Port $port"
        done
        
        # 基本配置
        cat << EOF
ListenAddress 0.0.0.0
ListenAddress ::
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

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
    
    # 检查临时配置
    if SSHD_CONFIG="$temp_config" sshd -t; then
        # 应用新配置
        mv "$temp_config" "$SSHD_CONFIG"
        chmod 600 "$SSHD_CONFIG"
        
        # 重启 SSH 服务
        if service ssh restart; then
            log "INFO" "SSH 配置已更新并重启服务"
        else
            error_exit "SSH 服务重启失败" $E_SYSTEM_ERROR
        fi
    else
        log "ERROR" "新配置无效，还原到备份配置..."
        cp "$backup_file" "$SSHD_CONFIG"
        rm -f "$temp_config"
        service ssh restart
        error_exit "SSH 配置更新失败" $E_CONFIG
    fi
}

# 修改主机名函数
change_hostname() {
    local old_hostname=$(hostname)
    read -p "请输入新的主机名: " new_hostname
    
    if [ -n "$new_hostname" ]; then
        # 验证主机名格式
        if [[ ! $new_hostname =~ ^[a-zA-Z0-9-]+$ ]]; then
            error_exit "无效的主机名格式" $E_INVALID_INPUT
        fi
        
        # 备份配置
        cp /etc/hostname "$BACKUP_DIR/hostname.bak.$(date +%Y%m%d%H%M%S)"
        cp /etc/hosts "$BACKUP_DIR/hosts.bak.$(date +%Y%m%d%H%M%S)"
        
        # 修改主机名
        hostnamectl set-hostname "$new_hostname" || error_exit "无法修改主机名"
        
        # 更新 hosts 文件
        sed -i "s/$old_hostname/$new_hostname/g" /etc/hosts
        
        log "INFO" "主机名已更改: $old_hostname -> $new_hostname"
    else
        log "WARNING" "主机名不能为空"
    fi
}

# 修改 root 密码函数
change_root_password() {
    while true; do
        show_password_menu
        read -p "请选择操作 (1-3): " pwd_choice
        case $pwd_choice in
            1)  # 手动输入密码
                while true; do
                    read -sp "输入新的 root 密码: " root_password
                    echo
                    read -sp "确认新的 root 密码: " confirm_password
                    echo
                    
                    if ! validate_password "$root_password"; then
                        echo "密码不符合复杂度要求:"
                        echo "- 长度必须在 $MIN_PASSWORD_LENGTH 到 $MAX_PASSWORD_LENGTH 之间"
                        echo "- 必须包含大小写字母、数字和特殊字符"
                        continue
                    fi
                    
                    if [ "$root_password" == "$confirm_password" ]; then
                        echo "root:$root_password" | chpasswd
                        log "INFO" "root 密码已修改"
                        break 2
                    else
                        echo "密码不匹配，请重试"
                    fi
                done
                ;;
            2)  # 生成随机密码
                read -p "请输入密码长度 [$MIN_PASSWORD_LENGTH-$MAX_PASSWORD_LENGTH] (默认 $DEFAULT_PASSWORD_LENGTH): " length
                length=${length:-$DEFAULT_PASSWORD_LENGTH}
                
                if [[ ! $length =~ ^[0-9]+$ ]] || [ "$length" -lt "$MIN_PASSWORD_LENGTH" ] || [ "$length" -gt "$MAX_PASSWORD_LENGTH" ]; then
                    error_exit "无效的密码长度" $E_INVALID_INPUT
                fi
                
                root_password=$(generate_password "$length")
                echo "root:$root_password" | chpasswd
                log "INFO" "root 密码已更新为随机密码"
                echo "请务必保存以下密码："
                echo "========================================"
                echo "$root_password"
                echo "========================================"
                read -p "请确认已保存密码 (按 Enter 继续...)"
                break
                ;;
            3)  # 返回主菜单
                break
                ;;
            *)
                echo "无效选择，请重试"
                ;;
        esac
    done
}

# 主菜单函数
show_menu() {
    clear
    echo "=== 系统配置工具 v$VERSION ==="
    echo "1. 修改 root 密码"
    echo "2. 修改主机名"
    echo "3. 配置 SSH 设置"
    echo "4. 查看系统日志"
    echo "5. 退出"
    echo "=========================="
}

# 密码修改子菜单
show_password_menu() {
    clear
    echo "=== 密码修改选项 ==="
    echo "1. 手动输入密码"
    echo "2. 生成随机密码"
    echo "3. 返回主菜单"
    echo "===================="
}

# 查看日志函数
view_logs() {
    if [ -f "$LOG_FILE" ]; then
        less "$LOG_FILE"
    else
        echo "日志文件不存在"
    fi
}

# 主程序
main() {
    # 检查 root 权限
    if [ "$(id -u)" -ne 0 ]; then
        error_exit "必须以 root 身份运行此脚本" $E_NOTROOT
    }
    
    # 初始化
    init
    
    # 主循环
    while true; do
        show_menu
        read -p "请选择操作 (1-5): " choice
        case $choice in
            1) change_root_password ;;
            2) change_hostname ;;
            3) configure_ssh ;;
            4) view_logs ;;
            5) log "INFO" "程序退出"; exit 0 ;;
            *) echo "无效选择，请重试" ;;
        esac
        read -p "按 Enter 键继续..."
    done
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi