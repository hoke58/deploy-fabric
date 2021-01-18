#!/bin/bash
######################脚本注释#############################
# 功  能： 区块链底层部署脚本（联盟机构）                   #
# 作  者： Hoke                                           #
# 时  间： 20200225                                       #
# 更  新： 20201211                                       #
###########################################################

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

##### permission modify ######
GENESIS_DOMAIN="ctfu.china-cba.net"   # 创世机构域名, 如 fabric.finrunchain.com
GENESIS_ORDERER_ADDRESS="orderer0.ord.${GENESIS_DOMAIN}:7050" # 创世机构 orderer 地址, 格式：orderer0.fabric.finrunchain.com:7050
GENESIS_ORDERER_MSP="Orderer1MSP"   # 创世机构 orderer MSPID
GENESIS_PEER0_ADDRESS="peer0.org.${GENESIS_DOMAIN}:7051" # 创世机构 peer0 地址, 格式：peer0.fabric.finrunchain.com:7051
GENESIS_PEER1_ADDRESS="peer1.org.${GENESIS_DOMAIN}:7751" # 创世机构 peer1 地址, 格式：peer0.fabric.finrunchain.com:7051
GENESIS_ORDADDRESS=$(echo $GENESIS_ORDERER_ADDRESS |awk -F ':' '{print $1}')
GENESIS_PEER0ADDRESS=$(echo $GENESIS_PEER0_ADDRESS |awk -F ':' '{print $1}')
GENESIS_PEER0PORT=$(echo $GENESIS_PEER0_ADDRESS |awk -F ':' '{print $2}')
GENESIS_PEER1ADDRESS=$(echo $GENESIS_PEER1_ADDRESS |awk -F ':' '{print $1}')
GENESIS_PEER1PORT=$(echo $GENESIS_PEER1_ADDRESS |awk -F ':' '{print $2}')
CHAINCODE_NAME=""        # chaincode 名称，默认 fft ，一般不需要修改，修改前请先确认
CCVERSION="2.3.2"
KAFKA_ADDRESS=(
"broker.finblockchain.cn: 10.10.255.55"
)  # Kafka 连连地址，仅部署本地 orderer 使用，一个连接地址一行，并用双引用括起， 格式："broker.finblockchain.cn: 10.10.255.55" 

#-------------- 分割线以上银协运维填写，分割线以下为入盟银行填写 -----------------------------------------
GENESIS_ORDERER_IP="128.196.75.23"    # 创世机构 orderer IP, 格式：xxx.xxx.xxx.xxx
GENESIS_PEER0_IP="128.196.75.24"       # 创世机构 peer0 IP, 格式：xxx.xxx.xxx.xxx
GENESIS_PEER1_IP="128.196.75.25"       # 创世机构 peer1 IP, 格式：xxx.xxx.xxx.xxx
MYORD_IP="128.196.74.188"    # 本机构 Orderer IP, 格式：xxx.xxx.xxx.xxx
MYPEER0_IP="128.196.74.189"    # 本机构 Peer0 IP, 格式：xxx.xxx.xxx.xxx
MYPEER1_IP="128.196.74.190"    # 本机构 Peer1 IP, 格式：xxx.xxx.xxx.xxx
MSPID=12
DELAY="3"  # join channel 超时时间，如果网络延时大，可适当调大该值
MOUNT_PATH="" # 容器外挂数据路径, 默认当前目录下 ./mount-data
RABBITMQ_IP=(128.196.74.191 128.196.74.192)   # rabbitmq IP 地址，2个IP间空格分开，样例：RABBITMQ_IP=(1.1.1.1) 或 RABBITMQ_IP=(1.1.1.1 2.2.2.2)
#----------------------------------------------------------------------------------------------------- 
############## prohibition modify ###############
: ${MOUNT_PATH:="$ABS_PATH/mount-data"}
: ${CHAINCODE_NAME:="fft"}
: ${GENESIS_ORDERER_MSP:=$GENESIS_DOMAIN}
: ${GENESIS_PEER_IP:=$GENESIS_ORDERER_IP}
: ${GENESIS_PEER_MSP:=$GENESIS_PEER_DOMAIN}

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

function apiUp() {
  [[ -n `docker ps -aq -f name=^/api${FABRICNODE}` ]] && colorEcho ${RED} "ERROR: api 容器已存在!" && exit 1
  colorEcho ${BLUE} "INFO: 开始安装 api$FABRICNODE"
  \cp -rf base/api-template.yaml docker-compose-api.yaml
  sed -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${ORDERER_IP}/$MYORD_IP/g" \
  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${PEER0_IP}/$MYPEER0_IP/g" \
  -e "s/\${PEER1_IP}/$MYPEER1_IP/g" \
  -e "s#\${MOUNT_DATA}#$MOUNT_PATH#g" \
  -e "s#\${ENDORSE_PEER0_IP}#$GENESIS_PEER0_IP#g" \
  -e "s#\${ENDORSE_PEER1_IP}#$GENESIS_PEER1_IP#g" \
  -i docker-compose-api.yaml

  \cp -rf base/apiconfig-template.yml apiconfig/application-localmsp.yml
  sed -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${CCNAME}/$CHAINCODE_NAME/g" \
  -e "s/\${ORDERER_MSP}/$MYORD_MSP/g" \
  -e "s/\${PEER_MSP}/$MYPEER_MSP/g" \
  -e "s/\${MQ_ADDRESSES}/$RABBITMQ_ADDRESSES/g" \
  -e "s#\${MYORDERER_7050}#$MYORDERER_7050#g" \
  -e "s#\${PEER_7051}#$MYPEER_7051#g" \
  -e "s#\${ENDORSER}#$ENDORSER#g" \
  -e "s#\${ENDORSER_7051}#$ENDORSER_7051#g" -i apiconfig/application-localmsp.yml
  if [ -z "$MODE" ]; then
    echo 2 > apiconfig/current.info
  fi
  docker-compose -p api -f docker-compose-api.yaml up -d 2>&1
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 不能启动 api$FABRICNODE 容器"
    exit 1
  fi
  colorEcho ${BLUE} "INFO: 等待 api$FABRICNODE 启动..."
  docker-compose -p api -f docker-compose-api.yaml ps
  sleep 30
  apiCurlWithRetry
}

apiCurlWithRetry() {
  for (( i = 1; i <= 5; i++ )); do
    statusCode=`curl -i http://127.0.0.1:8888/assetTradingPlatform/KeepAlive 2>&1 | grep 200 | wc -l`
    if [ $statusCode -eq 1 ]; then
      colorEcho ${GREEN} "INFO: api$FABRICNODE has installed successfully"
      break
    fi
    colorEcho ${YELLOW} "WARN: api$FABRICNODE failed to curl test, Retry after $DELAY seconds"
    sleep $DELAY
    if [ $i -eq  5 ]; then
      colorEcho ${YELLOW} "WARN: After 5 attempts, api$FABRICNODE has failed to curl test, please check it manually"
      exit 1
    fi
  done
}

function fabricDown() {
  local CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    echo "---- No containers available for deletion ----"
  else
    docker rm -f $CONTAINER_IDS
  fi
  COMPOSE_FILE=`ls docker-compose*.yaml`
  for i in ${COMPOSE_FILE[@]}; do
    if [ $i == "docker-compose-api.yaml" ]; then 
      docker-compose -p api -f $i down --volumes --remove-orphans
    else
      docker-compose down --volumes --remove-orphans
    fi
  done
  if [ "$MODE" == "rebuild" ]; then
    local DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
    if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
      echo "---- No images available for deletion ----"
    else
      docker rmi -f $DOCKER_IMAGE_IDS
    fi
    rm -rf mount-data/cli[0-1] mount-data/peer[0-1] mount-data/api[0-1] mount-data/orderer $COMPOSE_FILE apiconfig/application-localmsp.yml
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
  for i in $GENESIS_ORDERER_IP $GENESIS_PEER_IP ${RABBITMQ_IP[@]}; do
    checkIP $i
  done
  colorEcho ${GREEN} "INFO: IP 校验正确"
  if [ ${#RABBITMQ_IP[@]} -eq 2 ]; then
    RABBITMQ_ADDRESSES=`echo ${RABBITMQ_IP[@]} | sed 's/ /:5672,/' | sed 's/$/&:5672/'`
  elif [ ${#RABBITMQ_IP[@]} -eq 1 ]; then
    RABBITMQ_ADDRESSES=`echo ${RABBITMQ_IP[@]} | sed 's/$/&:5672/'`
  else
    colorEcho ${RED} "Error: RABBITMQ_IP 值错误，样例：RABBITMQ_IP=(1.1.1.1) 或 RABBITMQ_IP=(1.1.1.1 2.2.2.2)"
    exit 1
  fi
  if [ $MSPID -eq 10 ]; then
    MYORDERER_7050="7650"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7651"
      MYPEER_7052="7652"
      ENDORSER=1
      ENDORSER_7051="8651"
    else
      MYPEER_7051="8651"
      MYPEER_7052="8652"
      ENDORSER=0
      ENDORSER_7051="7651"
    fi
  elif [ $MSPID -eq 11 ]; then
    MYORDERER_7050="7150"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7151"
      MYPEER_7052="7152"
      ENDORSER=1
      ENDORSER_7051="8151"      
    else
      MYPEER_7051="8151"
      MYPEER_7052="8152"
      ENDORSER=0
      ENDORSER_7051="7151"
    fi
  elif [ $MSPID -eq 12 ]; then
    MYORDERER_7050="7250"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7251"
      MYPEER_7052="7252"
      ENDORSER=1
      ENDORSER_7051="8251"         
    else
      MYPEER_7051="8251"
      MYPEER_7052="8252"
      ENDORSER=0
      ENDORSER_7051="7251"      
    fi
  elif [ $MSPID -eq 13 ]; then
    MYORDERER_7050="7350"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7351"
      MYPEER_7052="7352"
      ENDORSER=1
      ENDORSER_7051="8351"
    else
      MYPEER_7051="8351"
      MYPEER_7052="8352"
      ENDORSER=0
      ENDORSER_7051="7351"       
    fi
  elif [ $MSPID -eq 14 ]; then
    MYORDERER_7050="7450"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7451"
      MYPEER_7052="7452"
      ENDORSER=1
      ENDORSER_7051="8451"
    else
      MYPEER_7051="8451"
      MYPEER_7052="8452"
      ENDORSER=0
      ENDORSER_7051="7451"
    fi
  elif [ $MSPID -eq 15 ]; then
    MYORDERER_7050="7550"
    if [ $FABRICNODE -eq 0 ]; then
      MYPEER_7051="7551"
      MYPEER_7052="7552"
      ENDORSER=1
      ENDORSER_7051="8551"
    else
      MYPEER_7051="8551"
      MYPEER_7052="8552"
      ENDORSER=0
      ENDORSER_7051="7551"
    fi
  fi         
  fabricUp
  apiUp
}

function fabricUp() {
  [[ -n `docker ps -aq -f name=^/peer${FABRICNODE}` ]] && colorEcho ${RED} "ERROR: peer 容器已存在!" && exit 1
  if [ ! -f "crypto-config.yaml" ] || [ ! -d "crypto-config/peerOrganizations/$LOCAL_DOMAIN" ]; then
    colorEcho ${RED} "ERROR: crypto-config 未发现，请先上传证书"
  fi
  colorEcho ${BLUE} "INFO: 开始安装区块链服务"
  \cp -rf base/peer-template.yaml docker-compose.yaml
  MYORD_DOMAIN=`awk '/Domain: /{print $2}' crypto-config.yaml | grep ord`
  MYPEER_DOMAIN=`awk '/Domain: /{print $2}' crypto-config.yaml | grep org`
  MYPEER_IP=$(getIP)
  MYORD_MSP=Orderer${MSPID}MSP
  MYPEER_MSP=Org${MSPID}MSP

  sed  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${PEER_MSP}/$MYPEER_MSP/g" \
  -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${ORDERER_IP}/$MYORD_IP/g" \
  -e "s/\${GENESIS_ORD_ADDRESS}/$GENESIS_ORDADDRESS/g" \
  -e "s/\${GENESIS_ORD_IP}/$GENESIS_ORDERER_IP/g" \
  -e "s#\${MOUNT_DATA}#$MOUNT_PATH#g" \
  -e "s/\${MYORDERER_7050}/$MYORDERER_7050/g" \
  -e "s/\${PEER_7051}/$MYPEER_7051/g" \
  -e "s/\${PEER_7052}/$MYPEER_7052/g" -i docker-compose.yaml

  docker-compose -f docker-compose.yaml up -d 2>&1
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 不能启动区块链容器"
    exit 1
  fi
  colorEcho ${BLUE} "INFO: 等待区块链服务启动..."
  docker-compose -f docker-compose.yaml ps

  if [ ! -f mount-data/peer[0-1]/chaincodes/${CHAINCODE_NAME}.${CCVERSION} ]; then
    sleep 15
    docker exec cli${FABRICNODE} bash bin/joinchannel.sh install $CHAINCODE_NAME $DELAY $VENDOR $CCVERSION
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "ERROR: peer$FABRICNODE install $CHAINCODE_NAME 失败"
      exit 1
    fi
  fi
  if [ ! -d mount-data/peer[0-1]/ledgersData/chains/chains/channel$CHAINCODE_NAME ]; then
    sleep 15
    docker exec cli${FABRICNODE} bash bin/joinchannel.sh join $CHAINCODE_NAME $DELAY $VENDOR $CCVERSION
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "ERROR: peer$FABRICNODE join channel$CHAINCODE_NAME 失败"
      exit 1
    fi
  fi  
  colorEcho ${GREEN} "INFO: 区块链服务运行成功"
}

cd $ABS_PATH
main
