#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

# This is a collection of bash functions used by different scripts
export PATH=$PWD/bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config  # for core.yaml which included with fabric-binary, and configtx.yaml we provided

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/ord1.finblockchain.cn/msp/tlscacerts/tlsca.ord1.finblockchain.cn-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.finblockchain.cn/peers/peer0.org1.finblockchain.cn/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.finblockchain.cn/peers/peer0.org2.finblockchain.cn/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/organizations/peerOrganizations/org3.finblockchain.cn/peers/peer0.org3.finblockchain.cn/tls/ca.crt

if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
  export ORDERER_CONNECTION_FLAGS="-o localhost:7050 --ordererTLSHostnameOverride orderer0.ord1.finblockchain.cn"
else
  export ORDERER_CONNECTION_FLAGS="-o localhost:7050 --ordererTLSHostnameOverride orderer0.ord1.finblockchain.cn --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA"
fi

# Set OrdererOrg.Admin globals
setOrdererGlobals() {
  export CORE_PEER_LOCALMSPID="OrdererMSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/ordererOrganizations/finblockchain.cn/orderers/orderer.finblockchain.cn/msp/tlscacerts/tlsca.finblockchain.cn-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/ordererOrganizations/finblockchain.cn/users/Admin@finblockchain.cn/msp
}

# Set environment variables for the peer org
setGlobals() {
  local USING_ORG=$1
  echo "Using organization ${USING_ORG}"
  if [ $USING_ORG -eq 1 ]; then
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.finblockchain.cn/users/Admin@org1.finblockchain.cn/msp
    export CORE_PEER_ADDRESS=peer0.org1.finblockchain.cn:7051
  elif [ $USING_ORG -eq 2 ]; then
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.finblockchain.cn/users/Admin@org2.finblockchain.cn/msp
    export CORE_PEER_ADDRESS=localhost:9051

  elif [ $USING_ORG -eq 3 ]; then
    export CORE_PEER_LOCALMSPID="Org3MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG3_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.finblockchain.cn/users/Admin@org3.finblockchain.cn/msp
    export CORE_PEER_ADDRESS=localhost:11051
  else
    echo "================== ERROR !!! ORG Unknown =================="
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

# parsePeerConnectionParameters $@
# Helper function that takes the parameters from a chaincode operation
# (e.g. invoke, query, instantiate) and checks for an even number of
# peers and associated org, then sets $PEER_CONN_PARMS and $PEERS
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.org$1"
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "true" ]; then
      TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_ORG$1_CA")
      PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    fi
    # shift by two to get the next pair of peer/org parameters
    shift
  done
  # remove leading space for output
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}

verifyResult() {
  cat log.txt
  echo
  if [ $1 -ne 0 ]; then
    echo "!!! $2 Failed !!!"
    echo
  else
    echo "=== $2 Succeeded! ==="
    echo
  fi
}
