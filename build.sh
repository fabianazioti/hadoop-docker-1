#!/bin/bash

source ./utils/hadoop.docker.sh

docker build --tag $HADOOP_DOCKER_IMG .
