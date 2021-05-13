#!/bin/bash
#author by hoke
#Adding an Org to a Channel, this script will leverage cli-peer0.org1 container, make sure the container is RUNNING PLS.

dockersh="docker exec fabric-client-V1_4 bash -c"
container_path=/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/add-zhongchu-peer
host_path=/home/ap/blockchain/peer0/conf/scripts/add-zhongchu-peer
export ORDERER_ADDRESS=orderer0.blockchain.ccb.com:7050
export ORDERER_CA=/etc/hyperledger/fabric/crypto-config/ordererOrganizations/blockchain.ccb.com/orderers/orderer0.blockchain.ccb.com/msp/tlscacerts/tlsca.blockchain.ccb.com-cert.pem

# - CORE_PEER_ID=cli-peer0.org1
# - CORE_PEER_LOCALMSPID=Org1MSP
# - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/crypto-config/peerOrganizations/blockchain.ccb.com/users/Admin@blockchain.ccb.com/msp
# - CORE_PEER_ADDRESS=peer0.org1.blockchain.ccb.com:7051
# - CORE_PEER_TLS_ENABLED=true
# - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/crypto-config/peerOrganizations/blockchain.ccb.com/peers/peer0.blockchain.ccb.com/tls/server.crt
# - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/crypto-config/peerOrganizations/blockchain.ccb.com/peers/peer0.blockchain.ccb.com/tls/server.key
# - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/crypto-config/peerOrganizations/blockchain.ccb.com/peers/peer0.blockchain.ccb.com/tls/ca.crt
# - ORDERER_ADDRESS=orderer0.blockchain.ccb.com:7001
# - ORDERER_CA=/etc/hyperledger/fabric/crypto-config/ordererOrganizations/blockchain.ccb.com/orderers/orderer0.blockchain.ccb.com/msp/tlscacerts/tlsca.blockchain.ccb.com-cert.pem

function ORGMSP () {
###########################################peer#############################################
# print out the Org zhongchu.blockchain.ccb.com-specific configuration material in JSON
$dockersh "configtxgen -printOrg zhongchu.blockchain.ccb.com -configPath $container_path > $container_path/org-1.json"

jq '.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "peer0.zhongchu.blockchain.ccb.com","port": 7051}]},"version": "0"}}' $host_path/org-1.json > $host_path/org.json

# fetch block
$dockersh "peer channel fetch config $container_path/config_block.pb -o $ORDERER_ADDRESS -c channelwarehouse --tls --cafile \$ORDERER_CA"

# decode block
$dockersh "configtxlator proto_decode --input $container_path/config_block.pb --type common.Block | jq .data.data[0].payload.data.config > $container_path/config.json"

# Add the Org Org10.blockchain.ccb.com Crypto Material
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups":{"Org10MSP":.[1]}}}}}' $host_path/config.json $host_path/org.json > $host_path/modified_config.json

# encode json to pb
$dockersh "configtxlator proto_encode --input $container_path/config.json --type common.Config --output $container_path/config.pb"
$dockersh "configtxlator proto_encode --input $container_path/modified_config.json --type common.Config --output $container_path/modified_config.pb"

# calculate the delta between these two config protobufs
$dockersh "configtxlator compute_update --channel_id channelwarehouse --original $container_path/config.pb --updated $container_path/modified_config.pb --output $container_path/org_update.pb"

# decode pb to json
$dockersh "configtxlator proto_decode --input $container_path/org_update.pb --type common.ConfigUpdate | jq . > $container_path/org_update.json"

# wrap in an envelope message
echo '{"payload":{"header":{"channel_header":{"channel_id":"channelwarehouse", "type":2}},"data":{"config_update":'$(cat $host_path/org_update.json)'}}}' | jq . > $host_path/org_update_in_envelope.json

# convert final update object into the fully fledged protobuf format that Fabric requires
$dockersh "configtxlator proto_encode --input $container_path/org_update_in_envelope.json --type common.Envelope --output $container_path/org_update_in_envelope.pb"

# Sign the Config Update
#docker exec cli-orderer0.ord1 bash -c "peer channel signconfigtx -f /opt/gopath/src/github.com/hyperledger/fabric/peer/artifacts/org_update_in_envelope.pb"

# Submit the Config Update
$dockersh "peer channel update -f $container_path/org_update_in_envelope.pb -c channelwarehouse -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA"
}

ORGMSP