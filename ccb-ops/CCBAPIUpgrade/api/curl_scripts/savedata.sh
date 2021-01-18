#!/bin/bash
# author by hoke
# this script is fabric savedata test
PORT=$1
DELAYTIME=2

clear
for((i=1;i<=$1;i++));  
do
	echo ""
	echo "---------- $i ----------"
	curl -H  "Content-Type: application/json" -X POST  --data '[ {"createBy":"chain","createTime":1500612707,"sender":"chain","receiver":["ALL"],"txData":"test1234","lastUpdateTime":0,"lastUpdateBy":"","cryptoFlag":0,"cryptoAlgorithm":"","docType":"","fabricTxId":"","businessNo":"'$i'" ,"expand1":"test_expand21","expand2":"test_expand22"}]' http://127.0.0.1:$PORT/factor/saveData
    sleep $DELAYTIME
done