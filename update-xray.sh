#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cd /usr/local/v2-ui/bin

updateGeoIP(){
    echo -e "Updating Geoip database"
    mv /usr/local/v2-ui/bin/geoip.dat /usr/local/v2-ui/bin/geoip.datD
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
    sleep 2
}

last_version=$(curl -Ls "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ ! -n "$last_version" ]]; then
    echo -e "Failed to detect latest version"
    exit 1
fi

echo -e "Updating XRay to version ${last_version}"
wget -q -O xray.zip https://github.com/XTLS/Xray-core/releases/download/${last_version}/Xray-linux-64.zip
unzip -q xray.zip -d temp
rm xray-v2-ui geosite.dat -f

mv temp/xray ./xray-v2-ui
mv temp/geosite.dat ./
sleep 2

updateGeoIP
chmod +x xray-v2-ui
rm temp xray.zip -rf

echo -e "XRay updated to version ${last_version} succeeded"
