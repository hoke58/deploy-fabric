./scripts/network.sh down
./scripts/network.sh up
./scripts/createChannel.sh kech
./scripts/createChannel.sh mychannel
. ./scripts/cc.sh

setCC kech /home/pliu/neo-cc/chaincodes/keyer 1.0.0 OR
deploy init
invokeCC '"genKey"' 1
invokeCC '"genKey"' 2
invokeCC '"genKey"' 3

setCC mychannel /home/pliu/neo-cc/chaincodes/asset 1.0.0 AND
deploy init
# Testing
invokeCC '"getKeys"' 1
invokeCC '"getKeys"' 2
invokeCC '"getKeys"' 3

