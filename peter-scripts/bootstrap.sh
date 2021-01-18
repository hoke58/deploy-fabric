cd test-network
export PATH=$PWD/bin:$PATH # suppose fabric binaries in $PWD/bin; change as necessary
./scripts/network.sh up
./scripts/createChannel.sh mychannel   # create a channel named mychannel
. ./scripts/cc.sh                      # import chaincode op utilities
setCC mychannel asset 1.0.0 OR         # channel name, cc name, cc version, policy 
showCC                                 # show contents of setCC
deploy init                            # instantiate; or deploy upgrade when upgrade
invokeCC '"getKeys"' 1                 # invoke getKeys for org1
invokeCC '"getKeys"' 2                 # invoke getKeys for org3
invokeCC '"getKeys"' 2                 # invoke getKeys for org3

# optionally you can
queryCC '"getKeys"' 1     # query to peer0 org1
queryCC '"checkLive"' 1   # check if cc works fine
