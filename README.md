# deploy-fabric
This is the automated shell script for hyperledger-fabric, it will deploy the addition of a new organization, and the join to the application channel



# How to install

## a. Install Docker and Docker Compose

You will need the following installed on the platform on which you will be operating, or developing-testing on (or for), Hyperledger Fabric:

> Docker Docker version 17.06.2-ce or greater is required.

You can check the version of Docker you have installed with the following command from a terminal prompt:

```sh
docker --version
```

Installing Docker will also install Docker Compose. If you already had Docker installed, you should check that you have Docker Compose version 1.14.0 or greater installed. If not, we recommend that you install a more recent version of Docker.

You can check the version of Docker Compose you have installed with the following command from a terminal prompt:

```sh
docker-compose --version
```

## b. Set the configure

Set the configure by modifying the `zhongchu.conf` file, e.g.

```sh
#-------------- 以下为入盟机构填写 -----------------------------------------
GENESIS_ORDERER1_IP="128.196.4.27"    # 创世机构 orderer IP, 格式：xxx.xxx.xxx.xxx
GENESIS_ORDERER2_IP="128.196.4.27"    # 创世机构 orderer IP, 格式：xxx.xxx.xxx.xxx
MSPID=10
DELAY="5"  # join channel 超时时间，如果网络延时大，可适当调大该值
MOUNT_PATH="" # 容器外挂数据路径, 默认当前目录下
CCVERSION="2.0.0"
#----------------------------------------------------------------------------------------------------- 
```

## c. Run the deploy-fabric

Execute the following command:

```sh
./deploy-fabric.sh
```

You will see a brief description as to what will occur, along with some command line prompts, respond with `a` to install fabric. 

Then you will be prompted as to which node you wish to deploy, respond with a `1` or `2`.

Last, you will be prompted to continue, respond with a `y` or hit the `Enter` key:

```sh
+------------------ CCB区块链自动部署脚本 -------------------+

      A：运行区块链应用服务
      B：停止区块链应用服务
      C：停止并清数区块链
      D：查询区块高度
      U：升级版本
      Q：按 Q 键退出

+--------------------------------------------------------------+
请输入[A-E]选项:a
你输入的选项是：a
请选择以下节点号:
1) 节点0
2) 节点1
请选择部署的节点（默认: 节点0）:1

---------------------------
节 点 号 = 0
---------------------------

Continue? [Y/n] 
```