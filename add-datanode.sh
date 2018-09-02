#!/bin/bash

source hadoop.docker.sh

if [ $# -lt 2 ]; then
  echo "usage: $0 CLUSTER_NAME HDFS_BASE_PATH [N_NODES]"
  exit 1
fi

CLUSTER_NAME=$1
HDFS_BASE_PATH=$2
N_NODES=${3:-1}

CLUSTER_PATH="${HDFS_BASE_PATH}/${CLUSTER_NAME}"

for i in $(seq 1 $N_NODES); do
    add_datanode $CLUSTER_NAME $CLUSTER_PATH
done
