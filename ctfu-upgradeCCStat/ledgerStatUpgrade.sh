#!/bin/bash
###################### comments ###########################
# 功  能： upgrade to ledger stat                         #
# 作  者： Hoke                                           #
###########################################################

ACTION="$1"
CHAINCODE_NAME="$2"
: ${CHAINCODE_NAME:="fft"}
CHANNEL_NAME="channel$CHAINCODE_NAME"
: ${CHANNEL_NAME:="channel$CHAINCODE_NAME"}
CCVERSION="$3"
: ${CCVERSION:="2.4.1"}
CCPACKAGE="${CHAINCODE_NAME}-${CCVERSION}.out"
CHAINCODE_LANG=node
UPGRADE_ARGS="{\"Args\":[\"init\", \"MFkwEwYHKoZIzj0CAQYIKoEcz1UBgi0DQgAEoYb6H8NqpdL2LSBf1tYZfSiAJ2hqNQAVu+bvkhTKu3lqeIRjPmNRqu8b8m/NvnUZoTsiPQ+7PslWfklb76rqKg==\"]}"
CHAINCODE_POLICY="AND('Org1MSP.member',OR('Org10MSP.member','Org11MSP.member','Org12MSP.member','Org13MSP.member','Org14MSP.member','Org15MSP.member','Org16MSP.member','Org17MSP.member','Org18MSP.member','Org19MSP.member','Org20MSP.member'))"

Org1MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEdQqxhMXpOmK5L+gAVlLprdJU/jf4\nost/RO5cb5zSk4WAvQ5oGhp8fiqpNAGyOQT2br09Q8L6dWt0DJb+0P46+A=='
Org10MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE9ZzQ70LlmxPXZgVrBj9QPOTd4xtW\nQnm6qwh9z2kw63ix/znuSRunv9CDHfk8pOKnqtUl9DEXO0Ko/MfXanY9Aw=='
Org11MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEba3kZ8kWG6+l0c8kswkOTrpkZiTY\niGtKlNFBN5vOMyIi1SWGGUKL98uiv81FNFbnZd0D/CvSu+msm1l6cupHtA=='
Org12MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEPU+JdDlDrDfnwDFeChxUNeBmTFwR\n2lfY8iKPV7gMuZA/yglmNBr8LdtBkBSb7yYE0jNctjVp27apZHJEArB54w=='
Org13MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAENPqfjhjB4hK4TeuvJl8OZ1Q9lOXO\n3rRYrY6zHFGbBkAj81JyhXKL0tsHJVzjFJSFSHEa++n9FoC91uXXau4LjQ=='
Org14MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEEv7W+EtPc+SDROO3zIHLM/h6E/5q\n57gr80iAANnDrPq2kD5G2JbY4Yn7GU8Ug4flyIslSrsVBp4msCow/qEMsA=='
Org15MSP='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/+k/0zLpxkiPm3cokX36L47tW/Fw\nuZXsF40/vn3Tg3Jxcidhqoz51nUl9sll0MHXuixVSJMtiHW8vnsVHTdXTg=='

export ORG10_PEER_ADDRESS=peer0.org.ctfu-saas.china-cba.net:7651
export ORG10_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/crypto-config/peerOrganizations/org.ctfu-saas.china-cba.net/peers/peer0.org.ctfu-saas.china-cba.net/tls/ca.crt

org1=peer0.org.ctfu.china-cba.net:7051
org10=peer0.org.ctfu-saas.china-cba.net:7651
org12=peer0.org.ctfu.boc.cn:7251

CCInstall() {
    peer chaincode install $CCPACKAGE
}

CCUpgrade() {
    peer chaincode upgrade \
    -n $CHAINCODE_NAME -l $CHAINCODE_LANG -v $CCVERSION -c "$UPGRADE_ARGS" -P "$CHAINCODE_POLICY" \
    -C $CHANNEL_NAME -o $ORDERER_ADDRESS  --tls --cafile $ORDERER_CA
}

Keylist() {
    local KEYLIST="[\"Org1MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org1MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org10MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org10MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org11MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org11MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org12MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org12MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org13MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org13MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org14MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org14MSP}\n-----END PUBLIC KEY-----\n\"],[\"Org15MSP\",\"-----BEGIN PUBLIC KEY-----\n${Org15MSP}\n-----END PUBLIC KEY-----\n\"]"

    local SIG=$(/home/sign sign sm2-for-add-crypto/pri.pem "[$KEYLIST]")
    
    echo "***Signature: $SIG"

    local KEYLIST=${KEYLIST//\"/\\\"}   # replace 
    local KEYLIST=${KEYLIST//$'\\n'/\\\\n} 
    local KEYLIST="[$KEYLIST]"
    echo "---------------------- KEYLIST --------------"
    echo $KEYLIST

    local ARGS="{\"Args\":[\"putKeys\",\"$KEYLIST\",\"$SIG\"]}"
    set -x
    peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE --peerAddresses $ORG10_PEER_ADDRESS --tlsRootCertFiles $ORG10_PEER_TLS_ROOTCERT_FILE -c "$ARGS"
    set +x
}    
getKeys(){
    set -x
    peer chaincode query -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -c "{\"Args\":[\"getKeys\"]}" --tls --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE
    set +x
}

addRegulators(){
    local addRegulators=[["MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEQi2Ua44O/s6iFImtZuCgbgNNmmHh\n2NxqMCDG99mQS70+Ikw8V+l/FIhvL72gjWEzEsz+JUNpxqfbXMseIhpgUA==","CTFU",0]]
    local SIG=$(./sign sign sm2-for-add-crypto/pri.pem "$addRegulators")
    echo -e "***Signature:\n $SIG"
    local addRegulators='[[\"MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEQi2Ua44O/s6iFImtZuCgbgNNmmHh\\n2NxqMCDG99mQS70+Ikw8V+l/FIhvL72gjWEzEsz+JUNpxqfbXMseIhpgUA==\",\"CTFU\",0]]'
    local ARGS="{\"Args\":[\"addRegulators\",\"$addRegulators\",\"$SIG\"]}"

    peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CHAINCODE_NAME --peerAddresses $CORE_PEER_ADDRESS --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE --peerAddresses $ORG10_PEER_ADDRESS --tlsRootCertFiles $ORG10_PEER_TLS_ROOTCERT_FILE -c "$ARGS"
}

case $ACTION in
  upgrade)
  CCInstall
  CCUpgrade
  ;;
  keylist)
  Keylist
  ;;
  getkeys)
  getKeys
  ;;
esac