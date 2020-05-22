#!/bin/bash
# author by Hoke
# 探活脚本

clear
echo -e "\e[1;32m+----------------- channelfft 5555 探活结果 ------------------+"
curl -I http://127.0.0.1:8888/assetTradingPlatform/KeepAlive
echo
echo -e "+------------------------- \033[41;37m探活结束\033[0m\e[1;32m ----------------------------+\033[0m"
