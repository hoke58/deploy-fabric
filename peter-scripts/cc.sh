#!/bin/bash

. scripts/envs-stats.sh

setCC() {  # $1: channel name, $2: cc_path, $3: cc_version, $4: AND/OR for policy
    if [ $# -eq 0 ]; then
	echo "Usage:"
        echo "    setCC channel_name cc_src_path [cc_version] [AND|OR]"
	echo
        echo "    - cc_version default to 1.0.0"
        echo "    - AND|OR default to OR"
	      return 1
    fi

    CHANNEL_NAME="$1"
    CC_SRC_PATH="$2/prd"
    CC_VERSION="$3"
    POLICY="$4"
    : ${CC_VERSION:="1.0.0"}
    : ${POLICY:=OR}

    LANGUAGE=node
    CC_NAME=$(basename $2)
    CC_PACKAGE_NAME=${CC_NAME}-${CC_VERSION}.cds

    POLICY=$POLICY\(\"Org1MSP.member\",\"Org2MSP.member\",\"Org3MSP.member\"\)
    INIT_ARGS="{\"Args\":[\"init\", \"MFkwEwYHKoZIzj0CAQYIKoEcz1UBgi0DQgAEkOKaDpvNl5YFAgf6/LTrZVKXiWErvUIIXeHz3AS+9qauI4a5m44+mw5Jeo4B5SoxHl9gRVkzzJWmKso5ptEpQQ==\"]}"
    UPGRADE_ARGS="{\"Args\":[\"init\"]}"

    export CHANNEL_NAME CC_SRC_PATH CC_VERSION CC_NAME CC_PACKAGE_NAME \
           LANGUAGE POLICY INIT_ARGS UPGRADE_ARGS

    showCC
}

showCC() {
    echo "CHANNEL_NAME    = $CHANNEL_NAME"
    echo "CC_NAME         = $CC_NAME"
    echo "CC_VERSION      = $CC_VERSION"
    echo "CC_SRC_PATH     = $CC_SRC_PATH"
    echo "CC_PACKAGE_NAME = $CC_PACKAGE_NAME"
    echo "POLICY          = $POLICY"
    echo "INIT_ARGS       = $INIT_ARGS"
    echo "UPGRADE_ARGS    = $UPGRADE_ARGS"
    echo
}

packCC() {
	set -x
	peer chaincode package -n $CC_NAME -v $CC_VERSION -l ${LANGUAGE} -p $CC_SRC_PATH $CC_PACKAGE_NAME >&log.txt
	res=$?
	set +x
	verifyResult $res "Chaincode $CC_NAME@$CC_VERSION in $CC_SRC_PATH packaged as $CC_PACKAGE_NAME"
}

installCC() {
	set -x
	peer chaincode install $CC_PACKAGE_NAME >&log.txt
	res=$?
	set +x
	verifyResult $res "Installing $CC_PACKAGE_NAME on $CORE_PEER_ADDRESS of $CORE_PEER_LOCALMSPID"
}

instantiateCC() {
	set -x
	peer chaincode instantiate $ORDERER_CONNECTION_FLAGS -C $CHANNEL_NAME -n $CC_NAME -l $LANGUAGE -v $CC_VERSION \
      -c "${INIT_ARGS}" -P "${POLICY}" >&log.txt ###--collections-config $PWD/scripts/collections_config.json >&log.txt
	res=$?
	set +x
	verifyResult $res "Instantiation of $CC_NAME@$CC_VERSION on $CHANNEL_NAME via $CORE_PEER_ADDRESS of $CORE_PEER_LOCALMSPID"
}

upgradeCC() {
	set -x
  peer chaincode upgrade $ORDERER_CONNECTION_FLAGS -C $CHANNEL_NAME -l $LANGUAGE -n $CC_NAME -v $CC_VERSION \
      -c "${UPGRADE_ARGS}" -P "${POLICY}" >&log.txt ####--collections-config $PWD/scripts/collections_config.json >&log.txt
	res=$?
	set +x
	verifyResult $res "Upgrade of $CC_NAME@$CC_VERSION on $CHANNLE_NAME via $CORE_PEER_ADDRESS of $CORE_PEER_LOCALMSPID"
}

listCh () {
    set -x
    peer channel list >&log.txt
    res=$?
    set +x
    verifyResult $res "List Channels the peer joined in"
}

listCC () {
    set -x
    peer chaincode list --installed >&log.txt
    res=$?
    set +x
    verifyResult $res "List Chaincodes Installed"

    set -x
    peer chaincode list --instantiated -C $CHANNEL_NAME >&log.txt
    res=$?
    set +x
    verifyResult $res "List Chaincode Instanitiated"
}


invokeCC() {  # parameters like args, 1, 2, 3 which represent org1, org2, org3, etc.
  args="{\"Args\":[$1]}"
  echo "ARGS: $args"
  shift
  parsePeerConnectionParameters $@ >&log.txt
  res=$?
  verifyResult $res "parsePeerConnectionParameters"
  set -x
  peer chaincode invoke $ORDERER_CONNECTION_FLAGS -C $CHANNEL_NAME -n $CC_NAME $PEER_CONN_PARMS -c "$args" >&log.txt
  res=$?
  set +x
  verifyResult $res "Invoke execution on $PEERS"
  echo
}

queryCC() { # $1: args (quoted string), $2: org no.
  args="{\"Args\":[$1]}"
  echo "ARGS: $args"
  ORG=$2
  setGlobals $ORG
  parsePeerConnectionParameters $ORG >&log.txt
  set -x
  peer chaincode query -C $CHANNEL_NAME -n ${CC_NAME} -c $args $PEER_CONN_PARMS >&log.txt # we want keep the result shown
  res=$?
  set +x
  verifyResult $res "queryCC in Org${ORG}"
}

deploy() {
  setGlobals 1
  packCC $CC_NAME $CC_VERSION $CC_SRC_PATH $CC_PACKAGE_NAME

  installCC $CC_PACKAGE_NAME

#  setGlobals 2
#  installCC $CC_PACKAGE_NAME

#  setGlobals 3
#  installCC $CC_PACKAGE_NAME

  if [ "$1" == "upgrade" ]; then
      upgradeCC
  else
      instantiateCC
  fi
}

setGlobals 1
setCC mychannel /home/pliu/neo-cc/chaincodes/asset 1.0.0
