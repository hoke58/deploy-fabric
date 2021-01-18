#!/bin/bash

# These envs may need be changed  depending on your settings
CRYPTO_CFG_PATH=${PWD}/organizations  # maybe ${PWD}/crypto_config
FABRIC_CFG_PATH=${PWD}/config         # location where core.yaml is
#ORG_DOMAIN=example.com
#ORDERER_ORG_DOMAIN=example.com
ORG_DOMAIN=org1.finblockchain.cn
ORDERER_ORG_DOMAIN=ord1.finblockchain.cn

if [ $# -lt 3 ]; then
    echo "Syntax:"
    echo "    ./keylist.sh <channel_name> <cc_name> org#..."
    echo
    echo "Example:"
    echo "    ./keylist.sh mychannel crosschain 1 2 3"
    echo
    exit 1
fi

channelname=$1
ccname=$2
shift
shift
orgs="$@"

peer_ca_path() { # e.g., peer_ca_path 1, for peer0 of org1
    echo "${CRYPTO_CFG_PATH}/peerOrganizations/org$1.$ORG_DOMAIN/peers/peer0.org$1.$ORG_DOMAIN/tls/ca.crt"
}

orderer_ca_path() {  # no args needed
    echo ${CRYPTO_CFG_PATH}/ordererOrganizations/$ORG_DOMAIN/orderers/orderer.$ORDERER_ORG_DOMAIN/msp/tlscacerts/tlsca.${ORDERER_ORG_DOMAIN}-cert.pem
}

peer_msp_path() {
     echo "${CRYPTO_CFG_PATH}/peerOrganizations/org$1.$ORG_DOMAIN/users/Admin@org$1.$ORG_DOMAIN/msp"
}

peer_address() {
    if [ "$1" == "1" ]; then   # org1
        echo "localhost:7051"
    elif [ "$1" == "2" ]; then
        echo "localhost:9051"
    elif [ "$1" == "3" ]; then
        echo "localhost:11051"
    fi
}

setGlobals() {
    local USING_ORG=$1
    echo "Using organization ${USING_ORG}"
    export CORE_PEER_LOCALMSPID="Org${USING_ORG}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$(peer_ca_path $1)
    export CORE_PEER_MSPCONFIGPATH=$(peer_msp_path $1)
    export CORE_PEER_ADDRESS=$(peer_address $1)
}

echo "ORGS=$orgs"

for org in $orgs; do
    echo "org=$org"
    setGlobals $org

    # Query on a specific org (any peer of the org should do the work)
    res=$(peer chaincode query -C $channelname -n $ccname -c '{"Args":["getKey"]}')
    #res=$(echo $res | sed "s/[][]//g")    # remove enclosing brackets

    openssl 
    # Invoke on enough number of peers of orgs that satisfying endorsement policy
    args={\"Args\":[\"putKey\",$res]}
    peer chaincode invoke -o localhost:7050 --tls true --cafile $(orderer_ca_path) \
      -C $channelname -n $ccname \
      -c "$args" \
      --peerAddresses localhost:7051 --tlsRootCertFiles $(peer_ca_path 1)  # may need more --peerAddresses depending on EP

    sleep 3
done


# Verify if it successed
setGlobals 1   # org 1, other orgs are also ok
peer chaincode query -C $channelname -n $ccname -c '{"Args":["getKeys"]}'
