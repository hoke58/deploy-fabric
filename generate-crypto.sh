#!/bin/bash

##### prohibition modify ######
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message
ABS_PATH="$( cd -P "$( dirname $0 )" && pwd )"
export PATH=${ABS_PATH}/bin:${ABS_PATH}:$PATH
export FABRIC_CFG_PATH=${ABS_PATH}
VENDOR="CTFU"
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
  read -p "请输入本机构域名（如 ctfu-saas.china-cba.net）：" DOMAIN
  read -p "请输入所在省（如 Beijing）：" PROVINCE 
  read -p "请输入所在城市（如 Beijing）" LOCALITY
  read -p "请输入机构名（如 china-cba）：" ORG

  : ${DOMAIN:=ctfu-saas.china-cba.net}
  : ${PROVINCE:=Beijing}
  : ${LOCALITY:=Beijing}
  : ${ORG:=china-cba}

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
    Domain: ord.${DOMAIN}
    EnableNodeOUs: false
    CA:
      Hostname: ca
      Country: CN
      Province: ${PROVINCE}
      Locality: ${LOCALITY}
      OrganizationalUnit: ${ORG}
    Template:
      Count: 1
PeerOrgs:
  - Name: Peer
    Domain: org.${DOMAIN}
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
    colorEcho ${YELLOW} "WARN: The crypto-config directory already exists."
    colorEcho ${YELLOW} "WARN: Input 'Y' if you want to continue to generate certs, or input 'N' to abort it."
    askProceed
    rm -Rf crypto-config
  fi
  getInfo
  generateYaml
  cryptogen generate --config=./crypto-config.yaml
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: Failed to generate certificates..."
    exit 1
  fi
}


function keylist() {
type="$1"
 : ${type:=ec}

prifile=pri.pem
pubfile=pub.pem

CRYPTO_DIR=${ABS_PATH}/crypto-config/peerOrganizations/org.${DOMAIN}/crypto

mkdir -p $CRYPTO_DIR && cd $CRYPTO_DIR

if [ "$type" == "sm2" ]; then
    echo "Generating sm2 key pair"
    openssl ecparam -name SM2 -genkey -noout -out $prifile.tmp
    openssl ec -in $prifile.tmp -pubout -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
elif [ "$type" == "rsa" ]; then
    echo "Generating rsa key pair"
    openssl genrsa -out $prifile.tmp 2048
    openssl rsa -pubout -in $prifile.tmp -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
elif [ "$type" == "ec" ]; then
    echo "generating ec key pair"
    openssl ecparam -name prime256v1 -genkey -noout -out $prifile.tmp
    openssl ec -in $prifile.tmp -pubout -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
else
    colorEcho ${YELLOW} "Unrecognized type!"
    exit 0
fi

rm $prifile.tmp
}

generateCerts
keylist

cd $ABS_PATH && mkdir -p ${DOMAIN}
mv crypto-config ${DOMAIN}
tar zcf ${DOMAIN}.tgz ${DOMAIN}