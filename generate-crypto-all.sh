#!/bin/bash

##### prohibition modify ######
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message 
export PATH=${PWD}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
VENDOR=""
: ${VENDOR:="Runchain"}
################################

function colorEcho(){
  COLOR=$1
  echo -e "\033[${COLOR}${@:2}\033[0m"
}

function askProceed() {
  read -p "继续? [Y/n] " ans
  case "$ans" in
  y | Y | "")
    echo "开始..."
    ;;
  n | N)
    echo "退出..."
    exit 0
    ;;
  *)
    colorEcho ${YELLOW} "输入值无效"
    askProceed
    ;;
  esac
}

function getInfo() {
  echo "本脚本用于生成机构的 Hyperledger Fabric 证书，包括 Orderer 和 Peer 组件"
  echo 
  read -p "请输入本机构域名（如 finrunchain.com）：" DOMAIN
  read -p "请输入所在省（如 Jiangsu）：" PROVINCE 
  read -p "请输入所在城市（如 Nanjing）：" LOCALITY
  read -p "请输入机构名（如 Nanjing Runchain Technology）：" ORG

  : ${DOMAIN:=finrunchain.com}
  : ${PROVINCE:=Jiangsu}
  : ${LOCALITY:=Nanjing}
  : ${ORG:=Nanjing Runchain Technology}

  echo 
  echo "请确认输入项是否正确："
  echo "------------------------------------------"
  echo "域名：${DOMAIN}"
  echo "省：${PROVINCE}"
  echo "城市：${LOCALITY}"
  echo "机构名：${ORG}"
  echo "------------------------------------------"
  echo "继续请输入 Y；否则请输入 N"
  askProceed
}

function generateYaml() {
  cat > crypto-config.yaml <<-EOFEOF
OrdererOrgs:
  - Name: Orderer
    Domain: ${DOMAIN}
    EnableNodeOUs: false
    CA:
      Hostname: ca
      Country: CN
      Province: ${PROVINCE}
      Locality: ${LOCALITY}
      OrganizationalUnit: ${ORG}
    Template:
      Count: 2
PeerOrgs:
  - Name: Peer
    Domain: ${DOMAIN}
    EnableNodeOUs: false
    CA:
      Hostname: ca
      Country: CN
      Province: ${PROVINCE}
      Locality: ${LOCALITY}
      OrganizationalUnit: ${ORG}
    Template:
      Count: 2
    Users:
      Count: 1
EOFEOF
}

function generateCerts() {
  if [ -d "crypto-config" ]; then
    colorEcho ${YELLOW} "WARN: 证书生成目录 crypto-config 已存在！"
    colorEcho ${YELLOW} "WARN: 输入 Y 删除原目录并开始生成新的证书；输入 N 终止"
    askProceed
    rm -Rf crypto-config certs certs-*.tar.gz
  fi
  getInfo
  generateYaml
  cryptogen generate --config=./crypto-config.yaml
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 生成证书失败"
  else
    mkdir -p certs/peerOrganizations/${DOMAIN}/
    cp -r crypto-config/peerOrganizations/${DOMAIN}/msp certs/peerOrganizations/${DOMAIN}/
    mkdir -p certs/ordererOrganizations/${DOMAIN}/
    cp -r crypto-config/ordererOrganizations/${DOMAIN}/msp certs/ordererOrganizations/${DOMAIN}/
    mkdir -p certs/ordererOrganizations/${DOMAIN}/orderers/orderer0.${DOMAIN}/tls/
    cp -r crypto-config/ordererOrganizations/${DOMAIN}/orderers/orderer0.${DOMAIN}/tls/server.crt certs/ordererOrganizations/${DOMAIN}/orderers/orderer0.${DOMAIN}/tls/
    mkdir -p certs/ordererOrganizations/${DOMAIN}/orderers/orderer1.${DOMAIN}/tls/
    cp -r crypto-config/ordererOrganizations/${DOMAIN}/orderers/orderer1.${DOMAIN}/tls/server.crt certs/ordererOrganizations/${DOMAIN}/orderers/orderer1.${DOMAIN}/tls/
    tar zcf certs-${DOMAIN}.tar.gz certs
    [ $? -eq 0 ] && colorEcho ${GREEN} "生成证书成功。请将压缩包 certs-${DOMAIN}.tar.gz 发送到单一窗口。" || colorEcho ${RED} "ERROR: 生成证书失败"
  fi
}

generateCerts
