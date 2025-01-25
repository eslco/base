#!/bin/bash
# -*- coding: utf-8 -*-

# Function Definitions

# Check for necessary utilities
check_utilities() {
    for util in lsof ps kill sudo ln rm; do
        if ! command -v "$util" >/dev/null 2>&1; then
            echo "Error: Missing required tool '$util'. Please install it to proceed." >&2
            exit 1
        fi
    done
}

# Check for sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo "Warning: Sudo privileges are required for some operations. Please ensure you have the permission or enter sudo password when prompted." >&2
    fi
}

# Select menu language
select_language() {
    echo "Select menu language:"
    echo "1. English"
    echo "2. 简体中文"
    echo "3. 繁體中文"
    read -p "Enter choice (1-3): " Lang
    case $Lang in
        1)
            LANGUAGE=en
            ;;
        2)
            LANGUAGE=zh_cn
            ;;
        3)
            LANGUAGE=zh_tw
            ;;
        *)
            echo "Invalid choice. Defaulting to English."
            LANGUAGE=en
            ;;
    esac
}

# Set language texts
set_language_texts() {
    case $LANGUAGE in
        en)
            MENU_1="1. Check processes by port"
            MENU_2="2. Terminate processes by PID"
            MENU_3="3. List all listening ports"
            MENU_4="4. Create soft link"
            MENU_5="5. Delete soft link"
            MENU_6="6. Exit"
            MENU_HELP="7. Help"
            CREATE_LINK="Soft Link created from %s to %s. You can use `%s` to run the script."
            DELETE_LINK="Soft link %s deleted."
            ;;
        zh_cn)
            MENU_1="1. 按端口查看进程"
            MENU_2="2. 按进程ID终止进程"
            MENU_3="3. 列出所有监听端口"
            MENU_4="4. 创建软链接"
            MENU_5="5. 删除软链接"
            MENU_6="6. 退出"
            MENU_HELP="7. 帮助"
            CREATE_LINK="软链接创建成功，从 %s 到 %s。你可以使用rivile来运行脚本。"
            DELETE_LINK="软链接 %s 已删除。"
            ;;
        zh_tw)
            MENU_1="1. 按端口查看進程"
            MENU_2="2. 按進程ID終止進程"
            MENU_3="3. 列出所有監聽端口"
            MENU_4="4. 創建軟連結"
            MENU_5="5. 刪除軟連結"
            MENU_6="6. 退出"
            MENU_HELP="7. 幫助"
            CREATE_LINK="軟連結建立成功，從 %s 到 %s。你可以使用
}

# 來執行腳本。"
            DELETE_LINK="軟連結 %s 已刪除。"
            ;;
    esac
}

# Custom parameter parsing
parse_parameters() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                shift
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    PORTS+=("$1")
                else
                    echo "Warning: Invalid port number '$1'. Skipping."
                fi
                shift
                ;;
            -k|--kill)
                shift
                if [[ $1 =~ ^[0-9]+$ ]]; then
                    PIDS_TO_KILL+=("$1")
                else
                    echo "Warning: Invalid PID '$1'. Skipping."
                fi
                shift
                ;;
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -menu)
                INTERACTIVE=true
                shift
                ;;
            -info)
                show_help
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Warning: Unknown option '$1'. Skipping."
                shift
                ;;
        esac
    done
}

# Create soft link
create_soft_link() {
    read -p "Enter target path: " target
    if [ ! -e "$target" ]; then
        echo "Target does not exist."
        return
    fi
    read -p "Enter link path: " link
    if [ -e "$link" ]; then
        if [ -L "$link" ]; then
            read -p "Link exists. Overwrite? (y/n): " confirm
            if [ "$confirm" != "y" ]; then
                echo "Link creation canceled."
                return
            fi
        else
            echo "Destination exists and is not a symlink."
            return
        fi
    fi
    ln -s "$target" "$link" && \

echo "$(printf "$CREATE_LINK" "$target" "$link" "$(basename "$link")")" || \
        echo "Failed to create soft link."
}

# Delete soft link
delete_soft_link() {
    read -p "Enter link path: " link
    if [ -L "$link" ]; then
        read -p "Are you sure to delete $link? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            rm "$link" && \
                echo "$(printf "$DELETE_LINK" "$link")" || \
                echo "Failed to delete soft link."
        else
            echo "Deletion canceled."
        fi
    else
        echo "Not a valid soft link."
    fi
}

# Interactive menu
interactive_menu() {
    while true; do
        clear
        echo "Interactive Menu:"
        echo "$MENU_1"
        echo "$MENU_2"
        echo "$MENU_3"
        echo "$MENU_4"
        echo "$MENU_5"
        echo "$MENU_6"
        echo "$MENU_HELP"
        read -p "Enter choice (1-7): " choice
        case $choice in
            4)
                create_soft_link
                ;;
            5)
                delete_soft_link
                ;;
            7)
                show_help_submenu
                ;;
            6)
                echo "Exiting interactive menu."
                break
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
        read -p "Press Enter to continue..." dummy
    done
}

# Show help submenu
show_help_submenu() {
    while true; do
        clear
        echo "Help Menu:"
        echo "1. Basic Usage"
        echo "2. Advanced Options"
        echo "3. Examples"
        echo "4. Troubleshooting"
        echo "5. Return to Main Menu"
        read -p "Enter choice (1-5): " help_choice
        case $help_choice in
            1)
                show_basic_usage
                ;;
            2)
                show_advanced_options
                ;;
            3)
                show_examples
                ;;
            4)
                show_troubleshooting
                ;;
            5)
                break
                ;;
            *)
                echo "Invalid choice, please try again."
                ;;
        esac
        read -p "Press Enter to continue..." dummy
    done
}

# Show basic usage
show_basic_usage() {
    case $LANGUAGE in
        en)
            echo "Basic Usage:"
            echo "  $0 [options]"
            echo "Options:"
            echo "  -p, --port <port number>    Specify the port number to check"
            echo "  -k, --kill <PID>            Specify the PID to terminate"
            echo "  -i, --interactive           Start interactive menu mode"
            echo "  -menu                       Launch interactive menu directly"
            echo "  -info                       Display help information"
            echo "  -h, --help                  Show help information"
            ;;
        zh_cn)
            echo "基本用法:"
            echo "  $0 [选项]"
            echo "选项："
            echo "  -p, --port <端口号>      指定要查找的端口号"
            echo "  -k, --kill <进程ID>      指定要终止的进程ID"
            echo "  -i, --interactive        启动交互菜单模式"
            echo "  -menu                   直接启动交互菜单"
            echo "  -info                   显示帮助信息"
            echo "  -h, --help               显示帮助信息"
            ;;
        zh_tw)
            echo "基本用法:"
            echo "  $0 [選項]"
            echo "選項："
            echo "  -p, --port <端口号>      指定要查找的端口号"
            echo "  -k, --kill <進程ID>      指定要終止的進程ID"
            echo "  -i, --interactive        啟動交互菜單模式"
            echo "  -menu                   直接啟動交互菜單"
            echo "  -info                   顯示幫助信息"
            echo "  -h, --help               顯示幫助信息"
            ;;
    esac
}

# Show advanced options
show_advanced_options() {
    case $LANGUAGE in
        en)
            echo "Advanced Options:"
            echo "  -menu: Directly launch the interactive menu without other options."
            echo "  -info: Display detailed help information."
            ;;
        zh_cn)

echo "高级选项:"
            echo "  -menu: 直接启动交互菜单，无需其他选项。"
            echo "  -info: 显示详细帮助信息。"
            ;;
        zh_tw)
            echo "進階選項:"
            echo "  -menu: 直接啟動交互菜單，無需其他選項。"
            echo "  -info: 顯示詳細幫助信息。"
            ;;
    esac
}

# Show examples
show_examples() {
    case $LANGUAGE in
        en)
            echo "Examples:"
            echo "  Terminate processes on port 80: $0 -p 80 -k PID --signal TERM"
            echo "  Create soft link: ln -s /original/file /link/file"
            echo "  Delete soft link: rm /link/file"
            ;;
        zh_cn)
            echo "示例："
            echo "  终止占用80端口的进程: $0 -p 80 -k 进程ID --signal TERM"
            echo "  创建软链接: ln -s /原始文件 /链接文件"
            echo "  删除软链接: rm /链接文件"
            ;;
        zh_tw)
            echo "範例："
            echo "  終止占用80端口的進程: $0 -p 80 -k 進程ID --signal TERM"
            echo "  創建軟連結: ln -s /原始檔案 /連結檔案"
            echo "  刪除軟連結: rm /連結檔案"
            ;;
    esac
}

# Show troubleshooting
show_troubleshooting() {
    case $LANGUAGE in
        en)
            echo "Troubleshooting:"
            echo "  - Ensure all required tools are installed."
            echo "  - Check for sudo permissions if operations require elevated privileges."
            ;;
        zh_cn)
            echo "故障排除："
            echo "  - 确保所有必要的工具已安装。"
            echo "  - 检查sudo权限，如果操作需要提升权限。"
            ;;
        zh_tw)
            echo "故障排除："
            echo "  - 確保所有必要的工具已安裝。"
            echo "  - 檢查sudo權限，如果操作需要提升權限。"
            ;;
    esac
}

# Main Execution

# Check for necessary utilities and sudo privileges
check_utilities
check_sudo

# Custom parameter parsing
parse_parameters "$@"

# If interactive mode is enabled or no specific options are provided, select language and enter interactive menu
if [ "$INTERACTIVE" = true ] || [ ${#PORTS[@]} -eq 0 ] && [ ${#PIDS_TO_KILL[@]} -eq 0 ]; then
    select_language
    set_language_texts
    interactive_menu
fi

# Handle specified ports and PIDs (if any)
for port in "${PORTS[@]}"; do
    # Handle port-related operations
    echo "Checking port $port..."
done

for pid in "${PIDS_TO_KILL[@]}"; do
    # Handle PID termination operations
    echo "Terminating PID $pid..."
done



            -i|--interactive|-menu)
                INTERACTIVE=true
                shift
                ;;
            -h|--help|-info)
                show_help
                exit 0
                ;;
            *)

            echo "  -i, --interactive, -menu         直接啟動交互菜單"
            echo " -h, --help  -info                   顯示幫助信息"