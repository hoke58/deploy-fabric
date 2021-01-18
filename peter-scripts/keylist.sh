#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Syntax:"
    echo "    ./keylist.sh org#..."
    echo
    echo "Example:"
    echo "    ./keylist.sh 1 2 3"
    echo
    exit 1
fi

# On using openssl 1.1.1+ or 3.0.0 Alpha
#   openssl dgst sm3 -sign $privkey -out sign.bin $msg
#   openssl enc -base64 -in sign.bin 

orgs="$@"

. ./scripts/cc.sh
setCC channelfft /root/fft 2.1.8

for org in $orgs; do
    echo "org=$org"
    setGlobals $org

    # Query on a specific org (any peer of the org should do the work)
    queryCC '"getKey"' $org
    keylist=$(cat log.txt)
    #keylist=$(echo $keylist | sed "s/[][]//g")    # remove enclosing brackets

    sig=$(./scripts/sign sign pri.pem "[$keylist]")
    #sig=MEQCIGbwij1k75YCPcWumKKplPmZjgdRf7QR0EG6DEk91fiRAiB3WjavK/5QYjYMZvcyz1KHRlN2xp00YJ5VsYaaGTGpUA==
    echo "***Signature: $sig"

    keylist=${keylist//\"/\\\"}   # replace " with \"
    keylist=${keylist//$'\\n'/\\\\n} 
    keylist="[$keylist]"
    echo "---------------------- KEYLIST --------------"
    echo $keylist 
 
    # Invoke on enough number of peers of orgs that satisfying endorsement policy
    invokeCC "\"putKey\",\"$keylist\",\"$sig\"" $orgs
    sleep 3
done

# Verify if it successed
setGlobals 1   # org 1, other orgs are also ok
queryCC '"getKeys"' 1


## upgrade cc 

"{\"Args\":[$1]}"
peer chaincode query -C channelfft -n fft -c "{\"Args\":[\"getKey\"]}" $PEER_CONN_PARMS

peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C channelfft -n fft --peerAddresses --tlsRootCertFiles --peerAddresses --tlsRootCertFiles -c


 peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer0.ord1.finblockchain.cn --tls true --cafile /root/fft/organizations/ordererOrganizations/ord1.finblockchain.cn/msp/tlscacerts/tlsca.ord1.finblockchain.cn-cert.pem -C channelfft -n fft --peerAddresses peer0.org1.finblockchain.cn:7051 --tlsRootCertFiles /root/fft/organizations/peerOrganizations/org1.finblockchain.cn/peers/peer0.org1.finblockchain.cn/tls/ca.crt -c '{"Args":["putKey","[[\"Org1MSP\",\"-----BEGIN PUBLIC KEY-----\\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEFnpXsWmSzgC/aMW4JW8Br/DmSc6f\\nvmNj2PbM8yDSm8Vek2ZTa9mzvBFvvyn60wJvGoUGgfnlbGeJo192UQsJjQ==\\n-----END PUBLIC KEY-----\\n\"]]","MEQCIBQVIZSVmHQA6nXEJzwGXmWWpU6IN8ACDcnsyXHkGiTbAiAoKOoHPHOL3o+q4BBnnXQi2Js045eUass27sW3dIi2Wg=="]}'
