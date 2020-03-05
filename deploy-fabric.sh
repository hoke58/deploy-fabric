#!/bin/bash
######################脚本注释#############################
# 功  能： 区块链底层部署脚本（联盟机构）                   #
# 作  者： Hoke                                           #
# 时  间： 20200225                                       #
###########################################################

##### prohibition modify ######
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message 
export PATH=${PWD}/bin:${PWD}:$PATH
export FABRIC_CFG_PATH=${PWD}
VENDOR="CTFU"
: ${VENDOR:="Runchain"}
################################

##### permission modify ######
DELAY="3"  # join channel 超时时间，如果网络延时大，可适当调大该值
MOUNT_PATH="" # 容器外挂数据路径, 默认当前目录下 ./mount-data
GENESIS_DOMAIN="ctfutest.china-cba.net"   # 创世机构域名, 如 fabric.finrunchain.com
GENESIS_ORDERER_ADDRESS="orderer0.ctfutest.china-cba.net:7050" # 创世机构 orderer 地址, 格式：orderer0.fabric.finrunchain.com:7050
GENESIS_ORDERER_IP="10.10.255.55"       # 创世机构 orderer IP, 格式：xxx.xxx.xxx.xxx
GENESIS_ORDERER_MSP="Orderer1MSP"   # 创世机构 orderer MSPID
GENESIS_PEER_DOMAIN=""   # 创世机构 peer 域名, 如 fabric.finrunchain.com
GENESIS_PEER_IP=""       # 创世机构 peer IP, 格式：xxx.xxx.xxx.xxx
GENESIS_PEER_MSP="Org1MSP"      # 创世机构 peer MSPID
CHAINCODE_NAME=""        # chaincode 名称，默认 fft ，一般不需要修改，修改前请先确认
ORDERER_CONF=""  # orderer 配置目录，默认值：orderconf ，一般不需要修改，修改前请先确认
RABBITMQ_IP=(10.10.255.55)   # rabbitmq IP 地址，2个IP间空格分开，样例：RABBITMQ_IP=(1.1.1.1) 或 RABBITMQ_IP=(1.1.1.1 2.2.2.2)
KAFKA_ADDRESS=(
"broker.finblockchain.cn: 10.10.255.55"
)  # Kafka 连连地址，仅部署本地 orderer 使用，一个连接地址一行，并用双引用括起， 格式："broker.finblockchain.cn: 10.10.255.55" 
################################
: ${MOUNT_PATH:="$PWD/mount-data"}
: ${CHAINCODE_NAME:="fft"}
: ${GENESIS_ORDERER_MSP:=$GENESIS_DOMAIN}
: ${GENESIS_PEER_DOMAIN:=$GENESIS_DOMAIN}
: ${GENESIS_PEER_IP:=$GENESIS_ORDERER_IP}
: ${GENESIS_PEER_MSP:=$GENESIS_PEER_DOMAIN}
: ${ORDERER_CONF:="ordererconf"}

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
  CLI_CONTAINER=$(docker ps -aq -f name=^/cli)
  if [ $CLI_CONTAINER ]; then
    colorEcho ${BLUE} "INFO: 通过 peer 查询区块高度"
    echo "---------------------------"
    docker exec $CLI_CONTAINER  peer channel getinfo -c channel$CHAINCODE_NAME
    echo "---------------------------"
    echo
  elif [ $(docker ps -aq -f name=^/api) ]; then
    colorEcho ${BLUE} "INFO: 通过 SDK 查询区块高度"
    echo "---------------------------"
    curl http://127.0.0.1:5555/assetTradingPlatform/queryBlockchainInfo
    echo
    echo "---------------------------"
    echo
  else
    colorEcho ${YELLOW} "未安装区块链服务"
  fi
}

function main() {
  local AStr="生成区块链底层证书"
  local BStr="运行区块链应用服务"
  local CStr="停止区块链应用服务"
  local DStr="停止并清数区块链"
  local EStr="查询区块高度"
  local QStr="按 Q 键退出"

  clear
  echo "+------------------ ${VENDOR}区块链自动部署脚本 -------------------+"
  echo ""
  echo "      A：${AStr}"
  echo "      B：${BStr}"
  echo "      C：${CStr}"
  echo "      D：${DStr}"
  echo "      E：${EStr}"
  echo "      Q：${QStr}"
  echo ""
  echo "+--------------------------------------------------------------+"

  while true; do
    read -n1 -p "请输入[A-E]选项:" option
    flag=$(echo $option|egrep "[A-Ea-e,Qq]" |wc -l)
    [ $flag -eq 1 ] && break
  done
	echo -e "\n你输入的选项是：\033[${BLUE}${option}\033[0m"
  sleep 1

  case $option in
	A|a)
		generateCerts
    ;;
  B|b)
		infrastructureMode
    prerequisites
    ;;
  C|c)
		fabricDown
    ;;
  D|d)
    colorEcho ${YELLOW} "WARN: 即将停止区块链服务并清除有关配置"
    askProceed
    MODE="rebuild"
		fabricDown
    ;;
  E|e)
    getBlockInfo
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

function generateCerts() {
  which cryptogen &>/dev/null
  if [ "$?" -ne 0 ]; then
    colorEcho ${RED} "ERROR: cryptogen tool not found. exiting"
    exit 1
  fi

  if [ -d "crypto-config" ]; then
    colorEcho ${YELLOW} "WARN: The crypto-config directory already exists."
    colorEcho ${BLUE} "INFO: Input 'Y' if you want to continue to generate certs, or input 'N' to abort it."
    askProceed
    rm -Rf crypto-config
  fi
  echo -e "请输入本机构域名，用以生成区块链证书:"
  read -p "(eg.：fabric.example.com):" IN_DOMAIN
  [ -z "${IN_DOMAIN}" ] && IN_DOMAIN="fabric.example.com"
  echo
  echo "---------------------------------------------"
  echo "本机构域名 = ${IN_DOMAIN}"
  echo "---------------------------------------------"
  echo
  askProceed
  echo "$(sed -e "s#\${DOMAIN}#$IN_DOMAIN#" base/crypto-config-template.yaml)" > crypto-config.yaml
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"
  set -x
  cryptogen generate --config=./crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    colorEcho ${RED} "ERROR: Failed to generate certificates..."
    exit 1
  fi
  colorEcho ${GREEN} "INFO: 生成区块链证书成功，记得回传至${VENDOR}"
}

function apiUp() {
  [[ -n `docker ps -aq -f name=^/api` ]] && colorEcho ${RED} "ERROR: api 容器已存在!" && exit 1
  colorEcho ${BLUE} "INFO: 开始安装 api$FABRICNODE"
  \cp -rf base/api-template.yaml docker-compose-api.yaml
  sed -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORD_ADDRESS}/$MYORD_ADDRESS/g" \
  -e "s/\${ORDERER_IP}/$MYORD_IP/g" \
  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${PEER_IP}/$MYPEER_IP/g" \
  -e "s#\${MOUNT_DATA}#/$MOUNT_PATH#g" \
  -i docker-compose-api.yaml

  \cp -rf base/apiconfig-template.yml apiconfig/application-localmsp.yml
  sed -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${ORD_ADDRESS}/$MYORD_ADDRESS/g" \
  -e "s/\${ORD_ADDRESS_PORT}/$MYORD_ADDRESS_PORT/g" \
  -e "s/\${PEER_DOMAIN}/$MYPEER_DOMAIN/g" \
  -e "s/\${CCNAME}/$CHAINCODE_NAME/g" \
  -e "s/\${ORDERER_MSP}/$MYORD_MSP/g" \
  -e "s/\${PEER_MSP}/$MYPEER_MSP/g" \
  -e "s/\${MQ_ADDRESSES}/$RABBITMQ_ADDRESSES/g" \
  -i apiconfig/application-localmsp.yml
  if [ -d "apiconfig/current.info" ]; then
    rm -rf apiconfig/current.info
  fi
  echo 2 > apiconfig/current.info
  docker-compose -p api -f docker-compose-api.yaml up -d 2>&1
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 不能启动 api$FABRICNODE 容器"
    exit 1
  fi
  colorEcho ${BLUE} "INFO: 等待 api$FABRICNODE 启动..."
  docker-compose -p api -f docker-compose-api.yaml ps
  sleep 15
  statusCode=`curl -i http://127.0.0.1:5555/factor/keepaliveQuery 2>&1 | grep 200 | wc -l`
  if [ $statusCode -eq 2 ]; then
    colorEcho ${GREEN} "INFO: api$FABRICNODE 运行成功"
  else
    colorEcho ${RED} "ERROR: api$FABRICNODE 运行失败"
    exit 1
  fi
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
  local MODES=("peer + SDK"
  "orderer + peer + SDK"
  "SDK"
  )
  while true; do
    echo -e "请选择以下接入模式部署:"
    for ((i=1;i<=${#MODES[@]};i++ )); do
      hint="${MODES[$i-1]}"
      echo -e "${i}) ${hint}"
    done
  read -p "请选择接入模式（默认: ${MODES[0]}）:" mode
  [ -z "$mode" ] && mode=1
  expr ${mode} + 1 &>/dev/null
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "Error: 输入错误，请重新输入一个数字"
    continue
  fi
  if [[ "$mode" -lt 1 || "$mode" -gt ${#MODES[@]} ]]; then
    colorEcho ${RED} "Error: 输入错误，请输入 1 至 ${#MODES[@]}"
    continue
  fi
  FABRICMODE=${MODES[$mode-1]}
  break
  done

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

  if [[ ${FABRICMODE[*]} == "orderer + peer + SDK" ]]; then
  local IS_ORDERER=(true false)
    while true; do
      echo -e "请选择该节点是否安装 orderer"
      for ((i=1;i<=${#IS_ORDERER[@]};i++ )); do
        hint="${IS_ORDERER[$i-1]}"
        echo -e "${i}) ${hint}"
      done
    read -p "请选择该节点是否安装 orderer（默认: ${IS_ORDERER[0]}）:" option
    [ -z "$option" ] && option=1
    expr ${option} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "Error: 输入错误，请重新输入一个数字"
      continue
    fi
    if [[ "$option" -lt 1 || "$option" -gt ${#IS_ORDERER[@]} ]]; then
      colorEcho ${RED} "Error: 输入错误，请输入 1 至 ${#IS_ORDERER[@]}"
      continue
    fi
    LOCAL_ORDERER=${IS_ORDERER[$option-1]}
    break
    done
  fi
  echo
  echo "---------------------------"
  echo "接入模式 = ${FABRICMODE}"
  echo "节 点 号 = ${FABRICNODE}"
  if [[ ${FABRICMODE[*]} == "orderer + peer + SDK" ]]; then
  echo "是否 orderer 节点 = ${LOCAL_ORDERER}"  
  fi
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
  GENESIS_ORDADDRESS=$(echo $GENESIS_ORDERER_ADDRESS |awk -F ':' '{print $1}')
  if [[ ${FABRICMODE[*]} == "peer + SDK" ]]; then
    [ ! -d "crypto-config/ordererOrganizations/$GENESIS_DOMAIN" ] && colorEcho ${RED} "ERROR: crypto-config 未发现创世机构 Orderer 证书，请先上传证书至$PWD" && exit 1
    fabricUp
    apiUp
  elif [[ ${FABRICMODE[*]} == "SDK" ]]; then
    if [ ! -d "crypto-config/ordererOrganizations/$GENESIS_DOMAIN" ] || [ ! -d "crypto-config/peerOrganizations/$GENESIS_DOMAIN" ]; then
      colorEcho ${RED} "ERROR: crypto-config 未发现创世机构 Orderer 或 Peer 证书，请先上传证书至$PWD"
      exit 1
    fi
    MYORD_DOMAIN=$GENESIS_DOMAIN
    MYORD_ADDRESS_PORT=$GENESIS_ORDERER_ADDRESS
    MYORD_ADDRESS=$GENESIS_ORDADDRESS
    MYORD_IP=$GENESIS_ORDERER_IP
    MYPEER_DOMAIN=$GENESIS_PEER_DOMAIN
    MYPEER_IP=$GENESIS_PEER_IP
    MYORD_MSP=$GENESIS_ORDERER_MSP
    MYPEER_MSP=$GENESIS_PEER_MSP
    apiUp
  else
    [[ -z $KAFKA_ADDRESS ]] && colorEcho ${RED} "ERROR: KAFKA_ADDRESS 空值" && exit 1
    [[ -n `docker ps -aq -f name=^/orderer` ]] && colorEcho ${RED} "ERROR: orderer 容器已存在!" && exit 1
    if [ ! -d "$ORDERER_CONF/kafkaTLSclient" ] || [ ! -f "$ORDERER_CONF/genesis.block" ]; then
      colorEcho ${RED} "ERROR: $ORDERER_CONF 未发现，请先上传 orderer 配置目录至$PWD"
      exit 1
    fi
    fabricUp
    apiUp
  fi
}

function fabricUp() {
  [[ -n `docker ps -aq -f name=^/peer` ]] && colorEcho ${RED} "ERROR: peer 容器已存在!" && exit 1
  if [ ! -f "crypto-config.yaml" ] || [ ! -d "crypto-config/peerOrganizations/$LOCAL_DOMAIN" ]; then
    colorEcho ${RED} "ERROR: crypto-config 未发现，请先执行 $0 选择 A 生成证书"
  fi
  LOCAL_DOMAIN=`awk '/Domain: /{print $2}' crypto-config.yaml|awk 'NR==1'`
  colorEcho ${BLUE} "INFO: 开始安装区块链服务"
  \cp -rf base/peer-template.yaml docker-compose.yaml
  if [[ ${FABRICMODE[*]} == "orderer + peer + SDK" ]]; then
    MYORD_DOMAIN=$LOCAL_DOMAIN
    MYORD_ADDRESS=orderer$FABRICNODE.$LOCAL_DOMAIN
    MYORD_ADDRESS_PORT=orderer$FABRICNODE.$LOCAL_DOMAIN:7050
    MYORD_IP=$(getIP)
    MYPEER_DOMAIN=$LOCAL_DOMAIN
    MYPEER_IP=$(getIP)
    MYORD_MSP=$LOCAL_DOMAIN
    MYPEER_MSP=$LOCAL_DOMAIN
    if [ $LOCAL_ORDERER == "true" ]; then
      cat base/orderer-template.yaml >> docker-compose.yaml
      for ((i=0;i<${#KAFKA_ADDRESS[@]};i++ )); do
        sed -i "/extra_hosts: # kafka/a\      ${KAFKA_ADDRESS[$i]}" docker-compose.yaml
      done
      sed -e "s/\${CFG_PATH}/$ORDERER_CONF/g" -i docker-compose.yaml
    fi
  else
    MYORD_DOMAIN=$GENESIS_DOMAIN
    MYORD_ADDRESS=$GENESIS_ORDADDRESS
    MYORD_ADDRESS_PORT=$GENESIS_ORDERER_ADDRESS
    MYORD_IP=$GENESIS_ORDERER_IP
    MYPEER_DOMAIN=$LOCAL_DOMAIN
    MYPEER_IP=$(getIP)
    MYORD_MSP=$LOCAL_DOMAIN
    MYPEER_MSP=$LOCAL_DOMAIN
  fi

  sed -e "s/\${DOMAIN}/$LOCAL_DOMAIN/g" \
  -e "s/\${NUM}/$FABRICNODE/g" \
  -e "s/\${ORDERER_DOMAIN}/$MYORD_DOMAIN/g" \
  -e "s/\${ORD_ADDRESS_PORT}/$MYORD_ADDRESS_PORT/g" \
  -e "s/\${ORD_ADDRESS}/$MYORD_ADDRESS/g" \
  -e "s/\${GENESIS_ORD_ADDRESS}/$GENESIS_ORDADDRESS/g" \
  -e "s/\${GENESIS_ORD_IP}/$GENESIS_ORDERER_IP/g" \
  -e "s#\${MOUNT_DATA}#$MOUNT_PATH#g" \
  -i docker-compose.yaml

  docker-compose -f docker-compose.yaml up -d 2>&1
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: 不能启动区块链容器"
    exit 1
  fi
  colorEcho ${BLUE} "INFO: 等待区块链服务启动..."
  docker-compose -f docker-compose.yaml ps

  if [[ ${FABRICMODE[*]} == "orderer + peer + SDK" ]] && [ $LOCAL_ORDERER == "true" ]; then
    local COUNTER=1
    local MAX_RETRY=10
    while [ $COUNTER -le $MAX_RETRY ]; do
      let COUNTER++
      LOG_STDOUT=$(docker-compose logs $MYORD_ADDRESS |grep "It's a connect message - ignoring" |wc -l)
      if [ $LOG_STDOUT -ne 0 ]; then
        break
      fi
      colorEcho ${YELLOW} "WARN: orderer 日志检查失败, $DELAY秒后重试"
      sleep $DELAY
    done
    if [ $COUNTER -ge $MAX_RETRY ]; then
      colorEcho ${YELLOW} "WARN: orderer 日志经$MAX_RETRY次反复检查依旧失败，请分析错误日志"
      docker-compose logs orderer.$LOCAL_DOMAIN|grep ERROR
    fi
  fi
  sleep 15

  docker exec cli${FABRICNODE} bash bin/joinchannel.sh $CHAINCODE_NAME $DELAY $VENDOR
  if [ $? -ne 0 ]; then
    colorEcho ${RED} "ERROR: peer$FABRICNODE join channel$CHAINCODE_NAME 失败"
    exit 1
  fi
  colorEcho ${GREEN} "INFO: 区块链服务运行成功"
}

main