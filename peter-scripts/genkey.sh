type="$1"
 : ${type:=ec}

prifile=pri.pem
pubfile=pub.pem

if [ "$type" == "sm2" ]; then
    echo "Generating sm2 key pair"
    openssl ecparam -name SM2 -genkey -noout -out $prifile.tmp
    openssl ec -in $prifile.tmp -pubout -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
elif [ "$type" == "rsa" ]; then
    echo "Generating rsa key pair"
    openssl genrsa -out $prifile.tmp 2048
    openssl rsa -pubout -in $prifile.tmp -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
elif [ "$type" == "ec" ]; then
    echo "generating ec key pair"
    openssl ecparam -name prime256v1 -genkey -noout -out $prifile.tmp
    openssl ec -in $prifile.tmp -pubout -out $pubfile
    openssl pkcs8 -in $prifile.tmp -topk8 -nocrypt -out $prifile
else
    echo "Unrecognized type!"
    exit 0
fi

rm $prifile.tmp