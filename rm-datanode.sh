#!/bin/bash

source hadoop.docker.sh

if [ $# -lt 2 ]; then
  echo "usage: $0 CLUSTER_NAME HDFS_BASE_PATH DATANODE_ID"
  exit 1
fi

CLUSTER_NAME=$1
HDFS_BASE_PATH=$2
DATANODE_ID=$3
CLUSTER_PATH="${HDFS_BASE_PATH}/${CLUSTER_NAME}"

rm_datanode $CLUSTER_NAME $CLUSTER_PATH $DATANODE_ID
