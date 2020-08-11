#!/bin/bash

ACTION="$1"
COUNTER=1
MAX_RETRY=10
CHAINCODE_NAME="$2"
DELAY="$3"
VENDOR="$4"
CHANNEL_NAME="channel$CHAINCODE_NAME"
CCVERSION="$5"
CCPACKAGE="${CHAINCODE_NAME}-${CCVERSION}.out"
: ${CHAINCODE_NAME:="fft"}
: ${CHANNEL_NAME:="channel$CHAINCODE_NAME"}
: ${DELAY:="3"}
: ${VENDOR:="Runchain"}
: ${CCVERSION:="2.1.0"}

printSatrt () {
  echo
  echo " ____    _____      _      ____    _____ "
  echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
  echo "\___ \    | |     / _ \   | |_) |   | |  "
  echo " ___) |   | |    / ___ \  |  _ <    | |  "
  echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
  echo
  echo "Join $CHANNEL_NAME of $VENDOR blockchain"
  echo
}

verifyResult () {
	if [ $1 -ne 0 ] ; then
        echo "================== ERROR: "$2" =================="
		echo
   		exit 1
	fi
}

joinChannelWithRetry() {
  set -x
  peer channel join -b channel-artifacts/$CHANNEL_NAME.block >&channel-artifacts/join-$CHANNEL_NAME.log
  res=$?
  set +x
  cat channel-artifacts/join-$CHANNEL_NAME.log
  if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
    COUNTER=$(expr $COUNTER + 1)
    echo "peer failed to join the channel, Retry after $DELAY seconds"
    sleep $DELAY
    joinChannelWithRetry
  else
    COUNTER=1
  fi
  verifyResult $res "After $MAX_RETRY attempts, peer has failed to join channel '$CHANNEL_NAME' "
  echo "===================== peer joined channel '$CHANNEL_NAME' ===================== "
}

installChaincode() {
  set -x
  peer chaincode install bin/${CCPACKAGE} >&channel-artifacts/install-cc.log
  res=$?
  set +x
  cat channel-artifacts/install-cc.log
  verifyResult $res "Chaincode installation on peer has failed"
  echo "===================== Chaincode is installed on peer ===================== "
  echo
}

fetch () {
  echo "Fetching channel config block from orderer..."
  set -x
  peer channel fetch 0 channel-artifacts/$CHANNEL_NAME.block -o $ORDERER_ADDRESS -c $CHANNEL_NAME --tls --cafile $ORDERER_CA >&channel-artifacts/fetch.log
  res=$?
  set +x
  cat channel-artifacts/fetch.log
  verifyResult $res "Fetching config block from orderer has Failed"
}

printEnd () {
echo
echo "========= All GOOD, join channel execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo

exit 0
}

case $ACTION in
  join|0x01)
  printSatrt
  fetch
  joinChannelWithRetry
  printEnd
  ;;
  install|0x02)
  printSatrt
  installChaincode
  printEnd
  ;;
esac