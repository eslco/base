#!/bin/bash
# 一键恢复Linux官方镜像源脚本（跨发行版兼容）

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

# 检测发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    elif type lsb_release >/dev/null 2>&1; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        CODENAME=$(lsb_release -sc)
    else
        echo -e "${RED}无法检测Linux发行版！${RESET}"
        exit 1
    fi
}

# 备份原有配置
backup_sources() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    case $DISTRO in
        ubuntu|debian)
            sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$timestamp"
            sudo mkdir -p "/etc/apt/sources.list.d.bak.$timestamp"
            sudo cp -r /etc/apt/sources.list.d/* "/etc/apt/sources.list.d.bak.$timestamp/"
            ;;
        centos|rhel|fedora)
            sudo mkdir -p "/etc/yum.repos.d.bak.$timestamp"
            sudo cp -r /etc/yum.repos.d/* "/etc/yum.repos.d.bak.$timestamp/"
            ;;
        opensuse*)
            sudo mkdir -p "/etc/zypp/repos.d.bak.$timestamp"
            sudo cp -r /etc/zypp/repos.d/* "/etc/zypp/repos.d.bak.$timestamp/"
            ;;
    esac
}

# 生成官方源配置
generate_official_sources() {
    case $DISTRO in
        ubuntu)
            sudo tee /etc/apt/sources.list >/dev/null <<EOF
# Ubuntu官方源 (${CODENAME})
deb http://archive.ubuntu.com/ubuntu ${CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-backports main restricted universe multiverse
EOF
            sudo rm -rf /etc/apt/sources.list.d/*  # 清理第三方源
            ;;
        debian)
            sudo tee /etc/apt/sources.list >/dev/null <<EOF
# Debian官方源 (${CODENAME})
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free
EOF
            sudo rm -rf /etc/apt/sources.list.d/*
            ;;
        centos|rhel)
            sudo rm -rf /etc/yum.repos.d/*
            sudo tee /etc/yum.repos.d/CentOS-Base.repo >/dev/null <<EOF
# CentOS官方源
[base]
name=CentOS-\$releasever - Base
baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[updates]
name=CentOS-\$releasever - Updates
baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

[extras]
name=CentOS-\$releasever - Extras
baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
            ;;
        fedora)
            sudo rm -rf /etc/yum.repos.d/*
            sudo tee /etc/yum.repos.d/fedora.repo >/dev/null <<EOF
# Fedora官方源
[fedora]
name=Fedora \$releasever - \$basearch
baseurl=https://download.fedoraproject.org/pub/fedora/linux/releases/\$releasever/Everything/\$basearch/os/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
EOF
            ;;
        opensuse*)
            sudo zypper removerepo --all
            sudo zypper addrepo "https://download.opensuse.org/distribution/leap/${VERSION}/repo/oss/" oss
            sudo zypper addrepo "https://download.opensuse.org/update/leap/${VERSION}/oss/" updates
            ;;
        *)
            echo -e "${RED}不支持的发行版: ${DISTRO}${RESET}"
            exit 1
            ;;
    esac
}

# 清理缓存并更新
refresh_package_cache() {
    case $DISTRO in
        ubuntu|debian)
            sudo apt clean
            sudo rm -rf /var/lib/apt/lists/*
            sudo apt update -y
            ;;
        centos|rhel|fedora)
            sudo yum clean all
            sudo rm -rf /var/cache/yum
            sudo yum makecache
            ;;
        opensuse*)
            sudo zypper clean --all
            sudo zypper refresh
            ;;
    esac
}

# 主执行流程
main() {
    echo -e "${BLUE}正在检测Linux发行版...${RESET}"
    detect_distro
    echo -e "${GREEN}检测到系统: ${DISTRO} ${VERSION} (${CODENAME})${RESET}"

    echo -e "${BLUE}正在备份现有源配置...${RESET}"
    backup_sources

    echo -e "${BLUE}正在生成官方源配置...${RESET}"
    generate_official_sources

    echo -e "${BLUE}正在清理缓存并更新...${RESET}"
    refresh_package_cache

    echo -e "${GREEN}源恢复完成！验证输出信息确认无错误。${RESET}"
}

# 执行主函数
main

# Repo URL: https://raw.github.com/eslco/base/main/script/linux/restore-apt.sh