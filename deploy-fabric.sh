#!/bin/bash
######################脚本注释#############################
# 功  能： 区块链底层部署脚本（入盟机构）                   #
# 作  者： Hoke                                           #
# 时  间： 20210118                                       #
###########################################################

##### prohibition modify ######
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message
ABS_PATH="$( cd -P "$( dirname $0 )" && pwd )"
export PATH=${ABS_PATH}/bin:${ABS_PATH}:$PATH
export FABRIC_CFG_PATH=${ABS_PATH}
VENDOR="CCB"
: ${VENDOR:="Runchain"}
USER_UID=`id -u`
GROUP_GID=`id -g`
################################

##### permission modify ######
GENESIS_DOMAIN="blockchain.ccb.com"   # 创世机构域名
GENESIS_ORDERER1_ADDRESS="orderer1.${GENESIS_DOMAIN}:7002"
GENESIS_ORDERER2_ADDRESS="orderer2.${GENESIS_DOMAIN}:7003"
GENESIS_ORDERER_MSP="Orderer1MSP"   # 创世机构 orderer MSPID
GENESIS_ORDADDRESS1=$(echo $GENESIS_ORDERER1_ADDRESS |awk -F ':' '{print $1}')
GENESIS_ORDADDRESS2=$(echo $GENESIS_ORDERER2_ADDRESS |awk -F ':' '{print $1}')
CHAINCODE_NAME=""
MYPEER_DOMAIN="zhongchu.blockchain.ccb.com"
source ${ABS_PATH}/zhongchu.cfg
############## prohibition modify ###############
: ${MOUNT_PATH:="."}
: ${CHAINCODE_NAME:="warehouse"}
: ${GENESIS_ORDERER_MSP:=$GENESIS_DOMAIN}

function colorEcho(){
  COLOR=$1
  echo -e "\033[${COLOR}${@:2}\033[0m"
}

function askProceed() {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
  y | Y | "")
    echo "Starting..."
    ;;
  n | N)
    echo "Exiting..."
    exit 0
    ;;
  *)
    colorEcho ${YELLOW} "Invalid input"
    askProceed
    ;;
  esac
}

function checkIP() {
  local IPADDR=$1
  VALID_CHECK=$(echo $IPADDR|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "true"}')
  if echo $IPADDR|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" &>/dev/null; then
    if [ $VALID_CHECK == "true" ]; then
      # colorEcho ${BLUE} "INFO: IP $IPADDR available!"
      return 0
    else
      colorEcho ${YELLOW} "WARN: IP $IPADDR not available!"
      exit 1
    fi
  else
    colorEcho ${RED} "ERROR: IP format error!"
    exit 1
  fi
}

function getIP(){
  local IPADDR=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^127\.|^255\.|^0\." | head -n 1 )
  [ ! -z ${IPADDR} ] && echo ${IPADDR} || echo
}

function getBlockInfo(){
  CLI_CONTAINER=$(docker ps -aq -f name=^/cli${FABRICNODE})
  API_CONTAINER=$(docker ps -aq -f name=^/api${FABRICNODE})
  if [[ -z $CLI_CONTAINER ]] && [[ -z $API_CONTAINER ]]; then
    colorEcho ${YELLOW} "未安装区块链服务"
  else
    if [ $CLI_CONTAINER ]; then
      colorEcho ${BLUE} "INFO: 通过 peer 查询区块高度"
      echo "---------------------------"
      docker exec $CLI_CONTAINER peer channel getinfo -c channel$CHAINCODE_NAME
      echo "---------------------------"
      echo
    fi
    if [ $API_CONTAINER ]; then
      colorEcho ${BLUE} "INFO: 通过 SDK 查询区块高度"
      echo "---------------------------"
      curl http://127.0.0.1:8888/assetTradingPlatform/queryBlockchainInfo
      echo
      echo "---------------------------"
      echo 
    fi
  fi
}

function main() {
  local AStr="运行区块链应用服务"
  local BStr="停止区块链应用服务"
  local CStr="停止并清数区块链"
  local DStr="查询区块高度"
  local UStr="升级版本"
  local QStr="按 Q 键退出"

  clear
  echo "+------------------ ${VENDOR}区块链自动部署脚本 -------------------+"
  echo ""
  echo "      A：${AStr}"
  echo "      B：${BStr}"
  echo "      C：${CStr}"
  echo "      D：${DStr}"
  echo "      U：${UStr}"
  echo "      Q：${QStr}"
  echo ""
  echo "+--------------------------------------------------------------+"

  while true; do
    read -n1 -p "请输入[A-E]选项:" option
    flag=$(echo $option|egrep "[A-Ea-e,Qq,Uu]" |wc -l)
    [ $flag -eq 1 ] && break
  done
	echo -e "\n你输入的选项是：\033[${BLUE}${option}\033[0m"
  sleep 1

  case $option in
    A|a)
      infrastructureMode
      prerequisites
    ;;
    B|b)
      fabricDown
    ;;
    C|c)
      colorEcho ${YELLOW} "WARN: 即将停止区块链服务并清除有关配置"
      askProceed
      MODE="rebuild"
      fabricDown
    ;;
    D|d)
      getBlockInfo
    ;;
    U|u)
      colorEcho ${YELLOW} "WARN: 即将升级区块链版本请提前做好备份"
      askProceed
      MODE="upgrade"
      fabricDown
      infrastructureMode
      prerequisites
    ;;      
    Q|q)
      echo -e "退出..."
      exit 0
    ;;
    *)
      colorEcho ${YELLOW} "输入值无效"
      sleep 1
      main
    ;;
  esac
}

function fabricDown() {
  if [ $EUID -ne 0 ]; then
    [[ -n `docker ps -aq -f name=^/peer` ]] && docker exec -i $(docker ps -aq -f name=^/peer) chown -R $USER_UID:$GROUP_GID /var/hyperledger/production
    [[ -n `docker ps -aq -f name=^/cli` ]] && docker exec -i $(docker ps -aq -f name=^/cli) chown -R $USER_UID:$GROUP_GID /opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts
  fi  
  local CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f $CONTAINER_IDS
  fi
  docker-compose down --volumes --remove-orphans
  if [ "$MODE" == "rebuild" ]; then
    local DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
    if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
      echo "---- No images available for deletion ----"
    else
      docker rmi -f $DOCKER_IMAGE_IDS
    fi
    rm -rf $MOUNT_PATH/cli[0-1] $MOUNT_PATH/peer[0-1] docker-compose.yaml
  fi
}

function infrastructureMode() {
  local NODES=(0 1)
  while true; do
    echo -e "请选择以下节点号:"
    for ((i=1;i<=${#NODES[@]};i++ )); do
      hint="${NODES[$i-1]}"
      echo -e "${i}) 节点${hint}"
    done
  read -p "请选择部署的节点（默认: 节点${NODES[0]}）:" node
  [ -z "$node" ] && node=1
  expr ${node} + 1 &>/dev/null
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "Error: 输入错误，请重新输入一个数字"
    continue
  fi
  if [[ "$node" -lt 1 || "$node" -gt ${#NODES[@]} ]]; then
    colorEcho ${RED} "Error: 输入错误，请输入 1 至 ${#NODES[@]}"
    continue
  fi
  FABRICNODE=${NODES[$node-1]}
  break
  done

  echo
  echo "---------------------------"
  echo "节 点 号 = ${FABRICNODE}"
  echo "---------------------------"
  echo
  askProceed
}

function prerequisites () {
  colorEcho ${BLUE} "INFO: 校验 IP..."
  for i in $GENESIS_ORDERER1_IP $GENESIS_ORDERER2_IP; do
    checkIP $i
  done
  colorEcho ${GREEN} "INFO: IP 校验正确"
  LoadImages
  fabricUp
}

function fabricUp() {
  [[ -n `docker ps -aq -f name=^/peer${FABRICNODE}` ]] && colorEcho ${RED} "ERROR: peer${FABRICNODE} 容器已存在!" && exit 1
  if [ ! -d "crypto-config/peerOrganizations/$LOCAL_DOMAIN" ]; then
    colorEcho ${RED} "ERROR: crypto-config not found."
  fi
  colorEcho ${BLUE} "INFO: 开始安装区块链服务"
  mkdir -p $MOUNT_PATH
  \cp -rf base/peer-template.yaml docker-compose.yaml
  MYORD_DOMAIN=$GENESIS_DOMAIN
  MYPEER_IP=$(getIP)
  MYORD_MSP=$GENESIS_ORDERER_MSP
  MYPEER_MSP=Org${MSPID}MSP

  sed  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${PEER_MSP}/$MYPEER_MSP/g" \
  -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${ORDERER_IP}/$MYORD_IP/g" \
  -e "s/\${GENESIS_ORD_ADDRESS1}/$GENESIS_ORDADDRESS1/g" \
  -e "s/\${GENESIS_ORD_ADDRESS2}/$GENESIS_ORDADDRESS2/g" \
  -e "s/\${GENESIS_ORDERER1_IP}/$GENESIS_ORDERER1_IP/g" \
  -e "s/\${GENESIS_ORDERER2_IP}/$GENESIS_ORDERER2_IP/g" \
  -e "s#\${MOUNT_DATA}#$MOUNT_PATH#g" \
  -i docker-compose.yaml

  docker-compose -f docker-compose.yaml up -d 2>&1
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 不能启动区块链容器"
    exit 1
  fi
  colorEcho ${BLUE} "INFO: 等待区块链服务启动..."
  docker-compose -f docker-compose.yaml ps

  if [ ! -f $MOUNT_PATH/peer[0-1]/chaincodes/${CHAINCODE_NAME}.${CCVERSION} ]; then
    sleep 15
    docker exec cli${FABRICNODE} bash bin/joinchannel.sh install $CHAINCODE_NAME $DELAY $VENDOR $CCVERSION
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "ERROR: peer$FABRICNODE install $CHAINCODE_NAME 失败"
      exit 1
    fi
  fi
  if [ ! -d $MOUNT_PATH/peer[0-1]/ledgersData/chains/chains/channel$CHAINCODE_NAME ]; then
    sleep 15
    docker exec cli${FABRICNODE} bash bin/joinchannel.sh join $CHAINCODE_NAME $DELAY $VENDOR $CCVERSION
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "ERROR: peer$FABRICNODE join channel$CHAINCODE_NAME 失败"
      exit 1
    fi
  fi  
  colorEcho ${GREEN} "INFO: 区块链服务运行成功"
}

function LoadImages() {
  IMAGES_PATH=$ABS_PATH/images
  IMAGEFILES=`ls $IMAGES_PATH/*.tar`
  if [ $? -eq 0 ]; then
    for i in $IMAGEFILES; do
      docker load -i $i
    done
  fi
}

cd $ABS_PATH
main
