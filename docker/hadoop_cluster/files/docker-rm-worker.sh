#!/bin/bash

if [ $# -lt 1 ]; then
	echo "usage: $0 worker_name"
	exit 1
fi

echo $1 >> /usr/local/hadoop/etc/hadoop/dfs.exclude

hdfs dfsadmin -refreshNodes

#echo "workers"
#cat $HADOOP_INSTALL/etc/hadoop/workers

#echo 
#echo "dfs.exclude"
#cat /usr/local/hadoop/etc/hadoop/dfs.exclude
