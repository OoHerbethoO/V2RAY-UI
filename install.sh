#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

[[ -z $(echo $SHELL|grep zsh) ]] && ENV_FILE=".bashrc" || ENV_FILE=".zshrc"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root user！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}Failed to detect schema, use default schema: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ] ; then
    echo "This software does not support 32-bit system (x86), please use 64-bit system (x86_64), if the detection is wrong, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher！${plain}\n" && exit 1
    fi
fi

checkSys() {
    [ $(id -u) != "0" ] && { colorEcho ${RED} "Error: You must be root to run this script"; exit 1; }

    if [[ `command -v apt-get` ]];then
        PACKAGE_MANAGER='apt-get'
    elif [[ `command -v dnf` ]];then
        PACKAGE_MANAGER='dnf'
    elif [[ `command -v yum` ]];then
        PACKAGE_MANAGER='yum'
    else
        colorEcho $RED "Not support OS!"
        exit 1
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar unzip -y
    else
        apt install wget curl tar unzip -y
    fi
}

uninstall_old_v2ray() {
    if [[ -f /usr/bin/v2ray/v2ray ]]; then
        confirm "Detected an old version of v2ray, uninstall it or not, it will be deleted /usr/bin/v2ray/ and /etc/systemd/system/v2ray.service" "Y"
        if [[ $? != 0 ]]; then
            echo "Can't install without uninstalling v2-ui"
            exit 1
        fi
        echo -e "${green}Uninstall older version of v2ray${plain}"
        systemctl stop v2ray
        rm /usr/bin/v2ray/ -rf
        rm /etc/systemd/system/v2ray.service -f
        systemctl daemon-reload
    fi
    if [[ -f /usr/local/bin/v2ray ]]; then
        confirm "Detected v2ray installed in other ways, whether to uninstall, v2-ui comes with the official xray kernel, in order to prevent conflicts with its port, it is recommended to uninstall" "Y"
        if [[ $? != 0 ]]; then
            echo -e "${red}If you choose not to uninstall, please ensure that v2ray and v2-ui are installed by other scripts ${green}Comes with the official xray kernel${red}No port conflicts${plain}"
        else
            echo -e "${green}Start uninstalling v2ray installed by other means${plain}"
            systemctl stop v2ray
            bash <(curl https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
            systemctl daemon-reload
        fi
    fi
}

#close_firewall() {
#    if [[ x"${release}" == x"centos" ]]; then
#        systemctl stop firewalld
#        systemctl disable firewalld
#    elif [[ x"${release}" == x"ubuntu" ]]; then
#        ufw disable
#    elif [[ x"${release}" == x"debian" ]]; then
#        iptables -P INPUT ACCEPT
#        iptables -P OUTPUT ACCEPT
#        iptables -P FORWARD ACCEPT
#        iptables -F
#    fi
#}

installDependent(){
    if [[ ${PACKAGE_MANAGER} == 'dnf' || ${PACKAGE_MANAGER} == 'yum' ]];then
        ${PACKAGE_MANAGER} install socat crontabs bash-completion which -y
    else
        ${PACKAGE_MANAGER} update
        ${PACKAGE_MANAGER} install socat cron bash-completion ntpdate -y
    fi

    #install python3 & pip
    source <(curl -sL https://python3.netlify.app/install.sh)
    pip3 install -r /usr/local/v2-ui/requirements.txt
}

updateGeoIP(){
    cd /usr/local/v2-ui/bin
    echo -e "Updating Geoip database"
    if [[ -e /usr/local/v2-ui/bin/geoip.dat ]]; then
        mv /usr/local/v2-ui/bin/geoip.dat /usr/local/v2-ui/bin/geoip.datD
    fi

    wget -q -N --no-check-certificate https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip.dat
    sleep 2
    if [[ $? -ne 0 ]]; then
        if [[ -e /usr/local/v2-ui/bin/geoip.datD ]]; then
            mv /usr/local/v2-ui/bin/geoip.datD /usr/local/v2-ui/bin/geoip.dat
        fi
        echo -e "${red}Failed to download Geoip database.${plain}"
    else
        if [[ -e /usr/local/v2-ui/bin/geoip.datD ]]; then
            rm -rf /usr/local/v2-ui/bin/geoip.datD
        fi
    fi

    chmod +x /usr/local/v2-ui/bin/geoip.dat
    chmod +x /usr/local/v2-ui/bin/geosite.dat
    echo -e "${green}Geoip database updated.${plain}"
    cd /usr/local/v2-ui/
    sleep 2
}

timeSync() {
    if [[ ${INSTALL_WAY} == 0 ]];then
        echo -e "${Info} Time Synchronizing.. ${Font}"
        if [[ `command -v ntpdate` ]];then
            ntpdate pool.ntp.org
        elif [[ `command -v chronyc` ]];then
            chronyc -a makestep
        fi

        if [[ $? -eq 0 ]];then 
            echo -e "${OK} Time Sync Success ${Font}"
            echo -e "${OK} now: `date -R`${Font}"
        fi
    fi
}

closeSELinux() {
    #disable SELinux
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

profileInit() {
    #Solve the problem of Chinese display in Python3
    [[ -z $(grep PYTHONIOENCODING=utf-8 ~/$ENV_FILE) ]] && echo "export PYTHONIOENCODING=utf-8" >> ~/$ENV_FILE && source ~/$ENV_FILE

    echo ""
}

install_v2_ui() {
    checkSys

    systemctl stop v2-ui
    mkdir -p /var/log/v2ray/
    mkdir -p /etc/v2-ui/
    
    cd /usr/local/
    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/OoHerbethoO/V2RAY-UI/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect the v2-ui version, it may be that the Github API limit is exceeded, please try again later, or manually specify the v2-ui version to install${plain}"
            exit 1
        else
            if [[ -e /usr/local/v2-ui/ ]]; then
                rm /usr/local/v2-ui/ -rf
            fi
        fi
        echo -e "v2-ui latest version detected： ${last_version}，start installation"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux-${arch}.tar.gz https://github.com/OoHerbethoO/V2RAY-UI/releases/download/${last_version}/v2-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download v2-ui, please make sure your server can download Github files${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/OoHerbethoO/V2RAY-UI/releases/download/${last_version}/v2-ui-linux-${arch}.tar.gz"
        echo -e "Start installing v2-ui v$1"
        wget -N --no-check-certificate -O /usr/local/v2-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download v2-ui v$1, please make sure this version exists${plain}"
            exit 1
        fi
    fi

    tar zxvf v2-ui-linux-${arch}.tar.gz
    rm v2-ui-linux-${arch}.tar.gz -f
    cd v2-ui
    installDependent
    closeSELinux
    timeSync
    profileInit
    updateGeoIP

    chmod +x bin/xray-v2-ui-linux-${arch}
    cp -f v2-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable v2-ui
    systemctl start v2-ui
    echo -e "${green}v2-ui v${last_version}${plain} installation is complete, the panel has been launched."
    echo -e ""
    echo -e "If it is a fresh installation, the default web port is ${green}65432${plain}, and the username and password default to ${green}admin${plain}"
    echo -e "Please make sure that this port is not occupied by other programs, ${yellow}and make sure that port 65432 is released${plain}"
    echo -e "If you want to modify 65432 to another port, enter the v2-ui command to modify it, and also make sure that the port you modify is also released"
    echo -e ""
    echo -e "If it's an update panel, access the panel as you did before"
    echo -e ""
    curl -o /usr/bin/v2-ui -Ls https://raw.githubusercontent.com/OoHerbethoO/V2RAY-UI/main/v2-ui.sh
    chmod +x /usr/bin/v2-ui
    echo -e "How to use the v2-ui management script: "
    echo -e "----------------------------------------------"
    echo -e "v2-ui              - Show management menu (more functions)"
    echo -e "v2-ui start        - Start the v2-ui panel"
    echo -e "v2-ui stop         - Stop v2-ui panel"
    echo -e "v2-ui restart      - Restart the v2-ui panel"
    echo -e "v2-ui status       - View v2-ui status"
    echo -e "v2-ui enable       - Set v2-ui to start automatically at boot"
    echo -e "v2-ui disable      - Cancel v2-ui boot auto-start"
    echo -e "v2-ui log          - View v2-ui logs"
    echo -e "v2-ui update       - Update v2-ui panel"
    echo -e "v2-ui install      - Install the v2-ui panel"
    echo -e "v2-ui uninstall    - Uninstall the v2-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}Start installation${plain}"
install_base
uninstall_old_v2ray
#close_firewall
install_v2_ui $1
