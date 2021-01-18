#!/bin/bash
######################脚本注释#############################
# 功  能： 区块链API版本脚本                                #
# 作  者： Hoke                                           #
###########################################################

##### prohibition modify ######
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message
FABRICNODE=`echo $API_DIRECTORY | tr -cd "[0-9]"`
################################

##### permission modify ######
DELAY=10
CHAINCODE_NAME=(fft factor warehouse atp)  # chaincode 名称，默认 fft ，一般不需要修改，修改前请先确认
FFT_PORT=5555
BAOLI_PORT=5556
WAREHOUSE_PORT=25556
ATP_PORT=15556
F5_IP="11.168.216.64"
RABBITMQ_IP=(11.160.162.25 11.160.162.26 11.160.162.27)   # rabbitmq IP 地址，2个IP间空格分开，样例：RABBITMQ_IP=(1.1.1.1) 或 RABBITMQ_IP=(1.1.1.1 2.2.2.2)
RABBITMQ_ADDRESSES=`echo ${RABBITMQ_IP[@]} | sed 's/ /:5672,/' | sed 's/ /:5672,/' | sed 's/$/&:5672/'`
#############################

function colorEcho(){
  COLOR=$1
  echo -e "\033[${COLOR}${@:2}\033[0m"
}

function ApiDeploy() {
  for i in ${CHAINCODE_NAME[@]}; do
    if [ $i == "fft" ]; then
      CCNAME_port=$FFT_PORT
    elif [ $i == "warehouse" ]; then
      CCNAME_port=$WAREHOUSE_PORT
    elif [ $i == "factor" ]; then
      CCNAME_port=$BAOLI_PORT
    elif [ $i == "atp" ]; then
      CCNAME_port=$ATP_PORT
    fi
    if [ $i == "factor" ]; then
      ccdir=baoli
    else
      ccdir=$i
    fi
    [[ -n `docker ps -aq -f name=^/api${FABRICNODE}.$i` ]] && colorEcho ${RED} "ERROR: api 容器已存在!" && exit 1
    colorEcho ${BLUE} "INFO: 开始安装 api$FABRICNODE.$i"
    mkdir -p $WORK_HOME/api${FABRICNODE}/$i/logs
    cd $ABS_PATH
    cp -a api/config api/curl_scripts $WORK_HOME/api${FABRICNODE}/$i
    cp -a ${BACK_PATH}/$API_DIRECTORY/crypto-config $WORK_HOME/api${FABRICNODE}/
    \cp -rf api/docker-compose.yaml $WORK_HOME/api${FABRICNODE}/$i/docker-compose.yaml
    sed -e "s/\${NUM}/$FABRICNODE/g" \
    -e "s/\${CCNAME}/${i}/g" \
    -e "s/\${LB_IP}/$F5_IP/g" \
    -e "s/\${API_PORT}/$CCNAME_port/g" \
    -i $WORK_HOME/api${FABRICNODE}/$i/docker-compose.yaml

    sed -e "s/\${NUM}/$FABRICNODE/g" \
    -e "s/\${CCNAME}/$i/g" \
    -e "s/\${MQ_ADDRESSES}/$RABBITMQ_ADDRESSES/g" \
    -e "s#\${MYORDERER_7050}#$(expr 7001 + $FABRICNODE)#g" \
    -e "s/\${CHANNELNAME}/channel${ccdir}/g" \
    -e "s/\${ExchangeName}/${ccdir}Queue/g" \
    -e "s#\${PEER_7051}#$(expr 7 + $FABRICNODE)051#g" \
    -i $WORK_HOME/api${FABRICNODE}/$i/config/application-localmsp.yml

    current_nu=`cat ${BACK_PATH}/$API_DIRECTORY/${ccdir}/${ccdir}event/current.info | awk -F , '{print $1}' | tr -cd "[0-9]"`
    echo $current_nu > $WORK_HOME/api${FABRICNODE}/$i/current.info
      
    docker-compose -f $WORK_HOME/api${FABRICNODE}/$i/docker-compose.yaml up -d 2>&1
    if [ $? -ne 0 ]; then
      colorEcho ${RED} "ERROR: 不能启动 api$FABRICNODE.$i 容器"
      exit 1
    fi
    colorEcho ${BLUE} "INFO: 等待 api$FABRICNODE.$i 启动..."
    docker-compose -f $WORK_HOME/api${FABRICNODE}/$i/docker-compose.yaml ps
    sleep 30
  done  
    apiCurlWithRetry
}

apiCurlWithRetry() {
  for port in $FFT_PORT $BAOLI_PORT $WAREHOUSE_PORT $ATP_PORT; do
    for (( i = 1; i <= 5; i++ )); do
      statusCode=`curl -i http://127.0.0.1:$port/assetTradingPlatform/KeepAlive 2>&1 | grep 200 | wc -l`
      if [ $statusCode -eq 1 ]; then
        colorEcho ${GREEN} "INFO: api$FABRICNODE-$port is ok"
        break
      fi
      colorEcho ${YELLOW} "WARN: api$FABRICNODE-$port failed to curl test, Retry after $DELAY seconds"
      sleep $DELAY
      if [ $i -eq  5 ]; then
        colorEcho ${YELLOW} "WARN: After 5 attempts, api$FABRICNODE-$port has failed to curl test, please check it manually"
        exit 1
      fi
    done
  done
}
