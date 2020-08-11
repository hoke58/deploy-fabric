# deploy-fabric
This is the automated shell script for hyperledger-fabric, it will deploy the addition of a new organization, and the join to the application channel

# How to use
```sh
bash deploy-fabric.sh
```

# 2020814 version
NFT Deploy
1. 解压版本覆盖至原部署目录

2. 按提示修改 deploy-fabric.sh 脚本
```sh
GENESIS_ORDERER_IP="128.196.75.23"    # 创世机构 orderer IP, 格式：xxx.xxx.xxx.xxx
GENESIS_PEER0_IP="128.196.75.24"       # 创世机构 peer0 IP, 格式：xxx.xxx.xxx.xxx
GENESIS_PEER1_IP="128.196.75.25"       # 创世机构 peer1 IP, 格式：xxx.xxx.xxx.xxx
MYORD_IP="128.196.74.188"    # 本机构 Orderer IP, 格式：xxx.xxx.xxx.xxx
MYPEER0_IP="128.196.74.189"    # 本机构 Peer0 IP, 格式：xxx.xxx.xxx.xxx
MYPEER1_IP="128.196.74.190"    # 本机构 Peer1 IP, 格式：xxx.xxx.xxx.xxx
MSPID=12
RABBITMQ_IP=(10.10.255.25)   # rabbitmq IP 地址，2个IP间空格分开，样例：RABBITMQ_IP=(1.1.1.1) 或 RABBITMQ_IP=(1.1.1.1 2.2.2.2)
```
3. 运行 `bash deploy-fabric.sh`
4. 根据提示交互式界面输入 U 升级版本，一步步按提示确认操作