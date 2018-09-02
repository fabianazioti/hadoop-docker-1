#!/bin/bash

source hadoop.docker.sh

if [ $# -lt 3 ]; then
  echo "usage: $0 CLUSTER_NAME HDFS_BASE_PATH N_NODES"
  exit 1
fi

CLUSTER_NAME=$1
HDFS_BASE_PATH=$2
N_NODES=$3

# check if N_NODES is a valid integer
re='^[0-9]+$'
if ! [[ $N_NODES =~ $re ]] ; then
   echo "ERROR: '$N_NODES' is not a valid number"
   exit 1
fi

# check if CLUSTER_NAME is a valid world
re='^[a-zA-Z][a-zA-Z0-9]+$'
if ! [[ $CLUSTER_NAME =~ $re ]] ; then
   echo "ERROR: '$CLUSTER_NAME' is not CLUSTER NAME"
   exit 1
fi


if [ ! -d $HDFS_BASE_PATH ]; then
    echo "'$HDFS_BASE_PATH' not found."
    exit 1
fi

CLUSTER_PATH=$HDFS_BASE_PATH/$CLUSTER_NAME
WORKERS_FILE="$CLUSTER_PATH/config/workers"

if [ -d "$CLUSTER_PATH" ]; then
    echo "Folder '$CLUSTER_PATH' already exists. Using it."
else
    echo "Creating cluster data and configuration folder '$CLUSTER_PATH'"
    create_folder $CLUSTER_PATH
    create_folder "$CLUSTER_PATH/config"

    echo "Creating a folder for namenode ..."
    create_folder "$CLUSTER_PATH/namenode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}"

    echo "Creating a folder for each datanode ..."
    create_folder "$CLUSTER_PATH/datanode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}"
    for i in $(seq 1 $N_NODES); do
        create_folder "$CLUSTER_PATH/datanode/${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-$i/"
    done

    echo "Creating workers file"
    
    rm -rf $WORKERS_FILE
    echo "${CLUSTER_NAME}-${HADDOP_MASTER_NAME}" >> $WORKERS_FILE

    echo "Creating core-site.xml file"
    cp config/core-site.xml $CLUSTER_PATH/config
    sed -i "s/hadoop-master/${CLUSTER_NAME}-hadoop-master/g" $CLUSTER_PATH/config/core-site.xml

    echo "Creating mapred-site.xml file"
    cp config/mapred-site.xml $CLUSTER_PATH/config
    sed -i "s/hadoop-master/${CLUSTER_NAME}-hadoop-master/g" $CLUSTER_PATH/config/mapred-site.xml
    
    echo "Creating dfs.exclude file"
    cp config/dfs.exclude $CLUSTER_PATH/config
    
    echo "Creating hdfs-site.xml file"
    cp config/hdfs-site.xml $CLUSTER_PATH/config

fi

NETWORK="${CLUSTER_NAME}-hadoop-net"
echo "Creating network $NETWORK"
docker network create $NETWORK

echo "Starting ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}"
docker run -itd \
    --name "${CLUSTER_NAME}-${HADDOP_MASTER_NAME}" \
    --hostname "${CLUSTER_NAME}-${HADDOP_MASTER_NAME}" \
    --volume "$CLUSTER_PATH/datanode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}":/home/hadoopuser/hdfs/datanode \
    --volume "$CLUSTER_PATH/namenode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}":/home/hadoopuser/hdfs/namenode \
    --net=$NETWORK \
    vconrado/hadoop_cluster:3.1.1


docker cp files/docker-add-worker.sh ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/home/hadoopuser
docker cp files/docker-rm-worker.sh ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/home/hadoopuser

docker cp $WORKERS_FILE ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
docker cp $CLUSTER_PATH/config/core-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
docker cp $CLUSTER_PATH/config/mapred-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
docker cp $CLUSTER_PATH/config/hdfs-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
docker cp $CLUSTER_PATH/config/dfs.exclude ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/


docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} hdfs namenode -format
echo "Sleeping"
sleep 5
docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} start-dfs.sh
docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} start-yarn.sh

for i in $(seq 1 $N_NODES); do
    add_datanode ${CLUSTER_NAME} $CLUSTER_PATH
done

            

