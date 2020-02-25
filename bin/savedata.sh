#/bin/bash
PLATFORM_IP=127.0.0.1
PLATFORM_PORT=5555


echo "==================================================================="
echo "Init AssetType to Blockchain"
curl -i -X POST http://$PLATFORM_IP:$PLATFORM_PORT/factor/saveData \
  -H "Content-type: application/json;charset=UTF-8" \
  -H "Accept: application/json" \
  -H "command: {\"uri\":\"/factor/saveData\",\"action\":\"POST\"}" \
  --data-binary "@data.txt"
