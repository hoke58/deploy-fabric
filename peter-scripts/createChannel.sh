#!/bin/bash

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="2"}
: ${MAX_RETRY:="5"}

# import utils
. scripts/envs.sh

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
fi

createChannelTx() {
	set -x
	configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME >&log.txt
	res=$?
	set +x
	verifyResult $res "Generating channel configuration transaction"
	if [ $res -ne 0 ]; then exit $res; fi
}

createAncorPeerTx() {
	for orgmsp in Org1MSP Org2MSP Org3MSP; do
		set -x
		configtxgen -profile ThreeOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${orgmsp}anchors.tx -channelID $CHANNEL_NAME -asOrg ${orgmsp} >&log.txt
		res=$?
		set +x
		verifyResult $res "Generating anchor peer update for ${orgmsp}"
		if [ $res -ne 0 ]; then exit $res; fi
	done
}

createChannel() {
	setGlobals 1

	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel create $ORDERER_CONNECTION_FLAGS -c $CHANNEL_NAME -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	verifyResult $res "Creating channel $CHANNEL_NAME"
	if [ $res -ne 0 ]; then exit $res; fi
}

# queryCommitted ORG
joinChannel() {
    ORG=$1
    setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block >&log.txt
		res=$?
		set +x
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	verifyResult $res "Joining peer0.org${ORG} to channel $CHANNEL_NAME"
    if [ $res -ne 0 ]; then exit $res; fi
}

updateAnchorPeers() {
    ORG=$1
    setGlobals $ORG
	set -x
	peer channel update $ORDERER_CONNECTION_FLAGS -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	res=$?
	set +x
    verifyResult $res "Updating anchor peers for org '$CORE_PEER_LOCALMSPID' on channel $CHANNEL_NAME"
    sleep $DELAY
	if [ $res -ne 0 ]; then exit $res; fi
}

## Create channeltx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createChannelTx

## Create anchorpeertx
echo "### Generating channel configuration transaction '${CHANNEL_NAME}.tx' ###"
createAncorPeerTx

## Create channel
echo "Creating channel "$CHANNEL_NAME
createChannel

## Join all the peers to the channel
echo "Join Org1 peers to the channel..."
joinChannel 1
# echo "Join Org2 peers to the channel..."
# joinChannel 2
# echo "Join Org3 peers to the channel..."
# joinChannel 3

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
updateAnchorPeers 1
# echo "Updating anchor peers for org2..."
# updateAnchorPeers 2
# echo "Updating anchor peers for org3..."
# updateAnchorPeers 3

if [ $? -eq 0 ]; then 
	echo
	echo "========= Channel successfully joined =========== "
	echo
fi
