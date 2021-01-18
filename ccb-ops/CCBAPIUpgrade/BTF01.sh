#!/bin/bash                                                                                                                                                   
######################脚本注释#############################
# 文件名： BTFO1_API_UPGRADE.sh                            # 
# 功  能： API版本升级至1.4.4                               #
# 作  者： Hoke                                           #
# 时  间： 20201013                                       #
# 单  元： BTFO1_AP                                       #
###########################################################
ABS_PATH="$( cd -P "$( dirname $0 )" && pwd )"
DATETIME=`date +%Y%m%d`
BACK_PATH=$HOME/app-pkg/_backup/fabric1.0.4-$DATETIME
WORK_HOME=/home/ap/blockchain
API_DIRECTORY=`basename $WORK_HOME/api[0-2]`
. $ABS_PATH/deploy-api.sh
###########################################################

verifyResult () {
	if [ $1 -ne 0 ] ; then
        colorEcho ${RED} "================== ERROR: "$2" =================="
		echo
   		exit 1
	fi
}

StopBackup() {
    docker stop `docker ps -aq -f name=apiserver` && docker rm `docker ps -aq -f name=apiserver`
    res=$?
    verifyResult $res "apiserver container has failed to remove"
    docker stop `docker ps -aq -f name=event` && docker rm `docker ps -aq -f name=event`
    res=$?
    verifyResult $res "eventserver container has failed to remove"
    echo "y" | docker network prune
    res=$?
    verifyResult $res "docker network has failed to prune"
    echo "y" | docker volume prune
    res=$?
    verifyResult $res "docker volume has failed to prune"    
    if [ -d "${BACK_PATH}/$API_DIRECTORY" ]; then
        colorEcho ${YELLOW} "================== WARN:[`hostname`][`date +%Y-%m-%d_%H:%M:%S`]"$i"已存在备份文件 =================="
        echo
    else
        mkdir -p $BACK_PATH
        mv $WORK_HOME/$API_DIRECTORY $BACK_PATH/
    fi    
}

Rollback() {
    for i in ${CHAINCODE_NAME[@]}; do
        container=`docker ps -q -f name=$i`
        docker exec -i $container rm -rf /opt/ApiServer/logs/*
        docker-compose -f $WORK_HOME/$API_DIRECTORY/${i}/docker-compose.yaml down
    done
    rm -rf $WORK_HOME/$API_DIRECTORY
    mv $BACK_PATH/$API_DIRECTORY $WORK_HOME/
    for i in ${CHAINCODE_NAME[@]}; do
        if [ $i == "factor" ]; then
            ccdir=baoli
        else
            ccdir=$i
        fi
        docker-compose -f $WORK_HOME/$API_DIRECTORY/${ccdir}/${ccdir}api/docker-compose.yml up -d
        docker-compose -f $WORK_HOME/$API_DIRECTORY/${ccdir}/${ccdir}event/docker-compose.yml up -d
    done
}

LoadImage() {
    docker load -i runchainapi-1.2.010.RELEASE.tar
}

case $1 in
    1|upgrade)
    StopBackup
    LoadImage
    ApiDeploy
    ;;
    2|rollback)
    Rollback
    ;;
    *)
    echo "API版本升级: $0 1"
    echo "API版本回退: $0 2"
esac
