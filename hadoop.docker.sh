
HADDOP_SLAVE_NAME="hadoop-slave"
HADDOP_MASTER_NAME="hadoop-master"
HADOOP_DOCKER_IMG="vconrado/hadoop_cluster:3.1.1"


function get_online_master(){
    local CLUSTER_NAME=$1
    local MASTER_NAME="${CLUSTER_NAME}-${HADDOP_MASTER_NAME}"
    local RES=$(docker ps --format '{{.Names}}' | grep ^"$MASTER_NAME")
    echo $RES
}

function create_folder() {
    FOLDER=$1
    mkdir -p $FOLDER
    if [ $? -ne 0 ]; then
        echo "ERROR: Was not possible to create the folder '$FOLDER'."
        exit 1
    fi
}

function add_datanode(){
    local CLUSTER_NAME=$1
    local CLUSTER_PATH=$2
    
    if [ ! -d "$CLUSTER_PATH" ]; then
        echo "Cluster folder '$CLUSTER_PATH' not found."
        exit 1
    fi
    
    local NETWORK="${CLUSTER_NAME}-hadoop-net"
    local MASTER=$(get_online_master $CLUSTER_NAME)
    
    if [[ $MASTER == "" ]]; then
        echo "Master node is not online. Please, it must be started to add new datanode."
        exit 1
    fi
    
    local DATANODE_ID="1"
    if [ -f "$CLUSTER_PATH/next.datanode" ]; then
        local DATANODE_ID=$(cat $CLUSTER_PATH/next.datanode)
        # check if DATANODE_ID is a valid integer
        re='^[0-9]+$'
        if ! [[ $DATANODE_ID =~ $re ]] ; then
           echo "ERROR: Next datanode id ('$DATANODE_ID') is not a valid number"
           exit 1
        fi
    fi
    
    create_folder "$CLUSTER_PATH/datanode/${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-$DATANODE_ID/"
    
    local DOCKER_DATANODE_NAME="${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-${DATANODE_ID}"
    echo "Starting ${DOCKER_DATANODE_NAME}"
    docker run -itd \
        --name "${DOCKER_DATANODE_NAME}" \
        --hostname "${DOCKER_DATANODE_NAME}" \
        --volume "$CLUSTER_PATH/datanode/${DOCKER_DATANODE_NAME}":/home/hadoopuser/hdfs/datanode \
        --net=$NETWORK \
        $HADOOP_DOCKER_IMG

    docker cp $CLUSTER_PATH/config/core-site.xml ${DOCKER_DATANODE_NAME}:/usr/local/hadoop/etc/hadoop/
    docker cp $CLUSTER_PATH/config/mapred-site.xml ${DOCKER_DATANODE_NAME}:/usr/local/hadoop/etc/hadoop/
    
    docker exec $MASTER /home/hadoopuser/docker-add-worker.sh "${DOCKER_DATANODE_NAME}"
    
    docker exec ${DOCKER_DATANODE_NAME} hdfs --daemon start datanode

    local DATANODE_ID=$((DATANODE_ID+1))
    echo $DATANODE_ID > $CLUSTER_PATH/next.datanode
}


function rm_datanode(){
    local CLUSTER_NAME=$1
    local CLUSTER_PATH=$2
    local DOCKER_DATANODE_ID=$3
    local DOCKER_DATANODE_NAME="${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-${DOCKER_DATANODE_ID}"
    
    if [ ! -d "$CLUSTER_PATH" ]; then
        echo "Cluster folder '$CLUSTER_PATH' not found."
        exit 1
    fi
    
    local MASTER=$(get_online_master $CLUSTER_NAME)
    
    if [[ $MASTER == "" ]]; then
        echo "Master node is not online. Please, it must be started to remove datanode."
        exit 1
    fi
    
    echo "Removing ${DOCKER_DATANODE_NAME}"
    docker exec $MASTER /home/hadoopuser/docker-rm-worker.sh "${DOCKER_DATANODE_NAME}"
}
