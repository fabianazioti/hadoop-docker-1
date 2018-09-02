#!/bin/bash

if [ $# -lt 1 ]; then
  echo "usage: $0 CLUSTER_NAME"
  exit 1
fi

CLUSTER_NAME=$1

for c in $(docker ps --format '{{.Names}}' | grep ^"$CLUSTER_NAME-hadoop" | sort); do 
    echo "Stopping/Removing $c"
    docker stop $c
    docker rm -v $c
done


NETWORK="${CLUSTER_NAME}-hadoop-net"
echo "Removing network $NETWORK"
docker network rm $NETWORK
