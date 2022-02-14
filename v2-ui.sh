#!/bin/bash

#======================================================
#   System Required: CentOS 7+ / Debian 8+ / Ubuntu 16+
#   Description: Manage v2-ui
#   Author: sprov
#   Blog: https://blog.sprov.xyz
#   Github - v2-ui: https://github.com/OoHerbethoO/V2RAY-UI
#======================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

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
        echo -e "${red}Please use CentOS 7 or higher!！${plain}\n" && exit 1
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

confirm_restart() {
    confirm "Whether to restart the panel, restarting the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/OoHerbethoO/V2RAY-UI/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force the latest version to be reinstalled, and the data will not be lost. Do you want to continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}Cancelled${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/OoHerbethoO/V2RAY-UI/master/install.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete, the panel has been automatically restarted${plain}"
        exit
#        if [[ $# == 0 ]]; then
#            restart
#        else
#            restart 0
#        fi
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall panel, xray will also uninstall?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop v2-ui
    systemctl disable v2-ui
    rm /etc/systemd/system/v2-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/v2-ui/ -rf
    rm /usr/local/v2-ui/ -rf

    echo ""
    echo -e "The uninstallation is successful, if you want to delete this script, run ${green}rm -rf /usr/bin/v2-ui${plain} after exiting the script to delete"
    echo ""
    # echo -e "Telegram 群组: ${green}https://t.me/sprov_blog${plain}"
    echo -e "Github issues: ${green}https://github.com/OoHerbethoO/V2RAY-UI/issues${plain}"
    echo -e "Github Repo: ${green}https://github.com/OoHerbethoO/V2RAY-UI${plain}"

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset username and password to admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/bin/python3 /usr/local/v2-ui/v2-ui.py resetuser
    echo -e "Username and password have been reset to ${green}admin${plain}, please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings, account data will not be lost, username and password will not be changed" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/bin/python3 /usr/local/v2-ui/v2-ui.py resetconfig
    echo -e "All panels have been reset to default, now reboot the panels and use the default ${green}65432${plain} port to access the panels"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Enter the port number [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Cancelled${plain}"
        before_show_menu
    else
        /usr/bin/python3 /usr/local/v2-ui/v2-ui.py setport ${port}
        echo -e "You are done setting the port, now restart the panel and use the newly set port ${green}${port}${plain} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}The panel is already running, no need to restart, if you want to restart, please select restart${plain}"
    else
        systemctl start v2-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2-ui started successfully${plain}"
        else
            echo -e "${red}The panel failed to start, maybe because the startup time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green}Panel has stopped, no need to stop again${plain}"
    else
        systemctl stop v2-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}v2-ui and xray stop successfully${plain}"
        else
            echo -e "${red}The panel failed to stop, maybe because the stop time exceeded two seconds, please check the log information later${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart v2-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Panel v2-ui and xray restarted successfully${plain}"
    else
        echo -e "${red}The panel failed to restart, maybe because the startup time exceeded two seconds, please check the log information later${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status v2-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui set the boot to start successfully${plain}"
    else
        echo -e "${red}v2-ui failed to set auto-start at boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui cancel the boot self-start successfully${plain}"
    else
        echo -e "${red}v2-ui failed to cancel the boot self-start${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo && echo -n -e "During the use of the panel, many WARNING logs may be output. If there is no problem with the use of the panel, there is no problem. Press Enter to continue: " && read temp
    tail -500f /etc/v2-ui/v2-ui.log
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}successfully installed bbr${plain}"
    else
        echo ""
        echo -e "${red}Failed to download bbr installation script, please check if your computer can connect to Github${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/v2-ui -N --no-check-certificate https://github.com/OoHerbethoO/V2RAY-UI/raw/master/v2-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Failed to download the script, please check whether the machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/v2-ui
        echo -e "${green}The upgrade script was successful, please rerun the script${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/v2-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status v2-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled v2-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}The panel is already installed, please do not install it again${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install the panel first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Panel Status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Panel Status: ${yellow}Not Running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Panel Status: ${red}Not Installed${plain}"
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start automatically: ${green}yes${plain}"
    else
        echo -e "是否开机自启: ${red}no${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-v2-ui" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}running${plain}"
    else
        echo -e "xray status: ${red}not running${plain}"
    fi
}

show_usage() {
    echo "How to use the v2-ui management script: "
    echo "------------------------------------------"
    echo "v2-ui              - Show management menu (more functions)"
    echo "v2-ui start        - Start the v2-ui panel"
    echo "v2-ui stop         - Stop v2-ui panel"
    echo "v2-ui restart      - Restart the v2-ui panel"
    echo "v2-ui status       - View v2-ui status"
    echo "v2-ui enable       - Set v2-ui to start automatically at boot"
    echo "v2-ui disable      - Cancel v2-ui boot auto-start"
    echo "v2-ui log          - View v2-ui logs"
    echo "v2-ui update       - Update v2-ui panel"
    echo "v2-ui install      - Install the v2-ui panel"
    echo "v2-ui uninstall    - Uninstall the v2-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}v2-ui panel management script${plain}
--- https://github.com/OoHerbethoO/V2RAY-UI ---
  ${green}0.${plain} exit script
————————————————
  ${green}1.${plain} Install v2-ui
  ${green}2.${plain} Update v2-ui
  ${green}3.${plain} Uninstall v2-ui
————————————————
  ${green}4.${plain} Reset username and password
  ${green}5.${plain} Reset panel settings
  ${green}6.${plain} Set up panel ports
————————————————
  ${green}7.${plain} Start v2-ui
  ${green}8.${plain} Stop v2-ui
  ${green}9.${plain} Restart v2-ui
 ${green}10.${plain} View v2-ui status
 ${green}11.${plain} View v2-ui logs
————————————————
 ${green}12.${plain} Set v2-ui to start automatically at boot
 ${green}13.${plain} Cancel v2-ui boot auto-start
————————————————
 ${green}14.${plain} 一Key install bbr (latest kernel)
 "
    show_status
    echo && read -p "Please enter a selection [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
