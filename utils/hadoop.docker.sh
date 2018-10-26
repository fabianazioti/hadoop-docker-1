# Fontes: 
# - http://gaurav3ansal.blogspot.com/2017/08/installing-hadoop-300-alpha-4-multi.html
# - https://hadoop.apache.org/docs/r2.4.1/hadoop-project-dist/hadoop-hdfs/hdfs-default.xml
# - https://pravinchavan.wordpress.com/2013/06/03/removing-node-from-hadoop-cluster/
# - https://www.guru99.com/learn-hdfs-a-beginners-guide.html

HADDOP_SLAVE_NAME="hadoop-slave"
HADDOP_MASTER_NAME="hadoop-master"
HADOOP_DOCKER_IMG="hadoop_cluster:3.1.1"
HADOOP_DOCKER_BASE_PATH="/tmp/hadoop"
HADOOP_CLUSTER_CONF_PATH="docker/hadoop_cluster/"

HADOOP_DOCKER_CONFIG_FILE="/home/$USER/.hadoop-docker.conf"
if [ -f $HADOOP_DOCKER_CONFIG_FILE ]; then
    source $HADOOP_DOCKER_CONFIG_FILE
fi

function get_base_path(){
    if [ ! -d $HADOOP_DOCKER_BASE_PATH ]; then
        >&2 echo "Criando docker bash path $HADOOP_DOCKER_BASE_PATH."
        mkdir -p $HADOOP_DOCKER_BASE_PATH
        if [[ $? -ne 0 ]]; then
            >&2 echo "Nao consegui criar o diretório :("
        fi
    fi
    echo $HADOOP_DOCKER_BASE_PATH
}

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

function get_master_urls(){
   local CLUSTER_NAME=$1
   local MASTER=$(get_online_master $CLUSTER_NAME)
   local IP_MASTER=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $MASTER)
   
   echo "Hadoop: http://${IP_MASTER}:9870"
   echo "Yarn: http://${IP_MASTER}:8088"
}

function docker_inspect_cluster(){
    # TODO: check if cluster exists
    local CLUSTER_NAME=$1
    # check if CLUSTER_NAME is a valid world
    re='^[a-zA-Z][a-zA-Z0-9]+$'
    if ! [[ $CLUSTER_NAME =~ $re ]] ; then
       echo "ERROR: '$CLUSTER_NAME' is not CLUSTER NAME"
       exit 1
    fi
    
    local BASE_PATH=$(get_base_path)
    local CLUSTER_PATH=$BASE_PATH/$CLUSTER_NAME
    local MASTER=$(get_online_master $CLUSTER_NAME)
    
    if [ ! -d $CLUSTER_PATH ]; then
        echo "ERROR: '$CLUSTER_PATH' not found."
        exit 1
    fi
    
    
    echo "Cluster ${CLUSTER_NAME} info" 
    echo "CLUSTER_PATH=${CLUSTER_PATH}"
    
    echo
    echo "workers:"
    docker exec $MASTER cat /usr/local/hadoop/etc/hadoop/workers
    
    echo 
    echo "dfs.exclude:"
    docker exec $MASTER cat /usr/local/hadoop/etc/hadoop/dfs.exclude
    
    echo 
    echo "Containers running: "
    docker ps --format '{{.Names}}' | grep ^"$CLUSTER_NAME-hadoop" | sort

    echo
    echo "IPs:"
    get_master_urls $CLUSTER_NAME
}


function docker_create_cluster(){
    local CLUSTER_NAME=$1
    local BASE_PATH=$(get_base_path)
    local N_NODES=$2

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


    if [ ! -d $BASE_PATH ]; then
        echo "ERROR: '$BASE_PATH' not found."
        exit 1
    fi

    local CLUSTER_PATH=$BASE_PATH/$CLUSTER_NAME
    local WORKERS_FILE="$CLUSTER_PATH/config/workers"

    if [ -d "$CLUSTER_PATH" ]; then
        echo "ERROR: Folder '$CLUSTER_PATH' already exists. Remove it first."
        exit 1
    fi
    
    echo "Creating folder '$CLUSTER_PATH'"
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
    cp $HADOOP_CLUSTER_CONF_PATH/config/core-site.xml $CLUSTER_PATH/config
    sed -i "s/hadoop-master/${CLUSTER_NAME}-hadoop-master/g" $CLUSTER_PATH/config/core-site.xml

    echo "Creating mapred-site.xml file"
    cp $HADOOP_CLUSTER_CONF_PATH/config/mapred-site.xml $CLUSTER_PATH/config
    sed -i "s/hadoop-master/${CLUSTER_NAME}-hadoop-master/g" $CLUSTER_PATH/config/mapred-site.xml
    
    echo "Creating dfs.exclude file"
    cp $HADOOP_CLUSTER_CONF_PATH/config/dfs.exclude $CLUSTER_PATH/config
    
    echo "Creating hdfs-site.xml file"
    cp $HADOOP_CLUSTER_CONF_PATH/config/hdfs-site.xml $CLUSTER_PATH/config
    

    local NETWORK="${CLUSTER_NAME}-hadoop-net"
    echo "Creating network $NETWORK"
    docker network create $NETWORK

    echo "Starting ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}"
    docker run -itd \
        --name "${CLUSTER_NAME}-${HADDOP_MASTER_NAME}" \
        --hostname "${CLUSTER_NAME}-${HADDOP_MASTER_NAME}" \
        --volume "$CLUSTER_PATH/datanode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}":/home/hadoopuser/hdfs/datanode \
        --volume "$CLUSTER_PATH/namenode/${CLUSTER_NAME}-${HADDOP_MASTER_NAME}":/home/hadoopuser/hdfs/namenode \
        --net=$NETWORK \
        ${HADOOP_DOCKER_IMG}


    docker cp $HADOOP_CLUSTER_CONF_PATH/files/docker-add-worker.sh ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/home/hadoopuser
    docker cp $HADOOP_CLUSTER_CONF_PATH/files/docker-rm-worker.sh ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/home/hadoopuser
    docker cp $HADOOP_CLUSTER_CONF_PATH/files/docker-readd-worker.sh ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/home/hadoopuser

    docker cp $WORKERS_FILE ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
    docker cp $CLUSTER_PATH/config/core-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
    docker cp $CLUSTER_PATH/config/mapred-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
    docker cp $CLUSTER_PATH/config/hdfs-site.xml ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/
    docker cp $CLUSTER_PATH/config/dfs.exclude ${CLUSTER_NAME}-${HADDOP_MASTER_NAME}:/usr/local/hadoop/etc/hadoop/


    docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} hdfs namenode -format
    sleep 5
    docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} start-dfs.sh
    docker exec ${CLUSTER_NAME}-${HADDOP_MASTER_NAME} start-yarn.sh

    for i in $(seq 1 $N_NODES); do
        docker_add_datanode ${CLUSTER_NAME} $CLUSTER_PATH
    done
}

function docker_rm_cluster(){
    local CLUSTER_NAME=$1

    for c in $(docker ps --format '{{.Names}}' | grep ^"$CLUSTER_NAME-hadoop" | sort); do 
        echo "Stopping/removing $c"
        docker stop $c
        docker rm -v $c
    done


    local NETWORK="${CLUSTER_NAME}-hadoop-net"
    echo "Removing network $NETWORK"
    docker network rm $NETWORK
}

function docker_purge_cluster(){
    local CLUSTER_NAME=$1
    
    local BASE_PATH=$(get_base_path)
    local CLUSTER_PATH=$BASE_PATH/$CLUSTER_NAME
    
    docker_rm_cluster $CLUSTER_NAME
    echo "Removing $CLUSTER_PATH"
    rm -rf $CLUSTER_PATH
}

function docker_add_datanode(){
    local CLUSTER_NAME=$1
    local BASE_PATH=$(get_base_path)
    local CLUSTER_PATH="${BASE_PATH}/${CLUSTER_NAME}"
    
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


function docker_rm_datanode(){
    # TODO verificar se o datanode realmente existe e nao esta excluido
    local CLUSTER_NAME=$1
    local DATANODE_ID=$2
    
    local BASE_PATH=$(get_base_path)
    local CLUSTER_PATH="${BASE_PATH}/${CLUSTER_NAME}"

    
    local DOCKER_DATANODE_NAME="${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-${DATANODE_ID}"
    
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

function docker_readd_datanode(){
    # TODO verificar se o datanode realmente esta excluido ou existe
    local CLUSTER_NAME=$1
    local DATANODE_ID=$2
    
    local MASTER=$(get_online_master $CLUSTER_NAME)
    
    if [[ $MASTER == "" ]]; then
        echo "Master node is not online. Please, it must be started to readd the datanode."
        exit 1
    fi
    
    local DATANODE_NAME="${CLUSTER_NAME}-${HADDOP_SLAVE_NAME}-${DATANODE_ID}"
    echo "Re-adding ${DATANODE_NAME}"
    docker exec $MASTER /home/hadoopuser/docker-readd-worker.sh "${DATANODE_NAME}"
}
