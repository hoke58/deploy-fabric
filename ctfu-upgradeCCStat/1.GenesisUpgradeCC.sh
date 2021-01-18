#!/bin/bash
###################### comments ###########################
# 功  能： upgrade to ledger stat                         #
# 作  者： Hoke                                           #
###########################################################

PEER_COMPOSE_FILE=/home/ap/blockchain/peer0.org1/conf/docker-compose.yaml
NODEENV_IMAGE=hub.finrunchain.com/fabric-guomi/runchain/fabric-nodeenv:1.4.4sm
NODEENV_IMAGE_TAR=fabric-nodeenv-1.4.4sm.tar
CLI_CONTAINER=$(docker ps -aq -f name=^/cli)

PeerUpdate() {
    docker load -i $NODEENV_IMAGE_TAR
    \cp -rf $PEER_COMPOSE_FILE $PEER_COMPOSE_FILE.$(date +%Y%m%d)
    sed -e "s#local/fabric-guomi/runchain/fabric-ccenv:1.4.4-pa#$NODEENV_IMAGE#g" \
    -i $PEER_COMPOSE_FILE
    docker-compose -f $PEER_COMPOSE_FILE up -d
}

prerequisites() {  
    docker cp sm2-for-add-crypto $CLI_CONTAINER:/home
    docker cp ledgerStatUpgrade.sh $CLI_CONTAINER:/home
    docker cp sign $CLI_CONTAINER:/home
}


case $1 in
  upgrade)
  PeerUpdate
  docker exec $CLI_CONTAINER bash /home/ledgerStatUpgrade.sh upgrade fft
  ;;
  keylist)
  prerequisites
  docker exec $CLI_CONTAINER bash /home/ledgerStatUpgrade.sh keylist
  ;;
  getkeys)
  prerequisites
  docker exec $CLI_CONTAINER bash /home/ledgerStatUpgrade.sh getkeys
  ;;  
esac