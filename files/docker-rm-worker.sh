#!/bin/bash

if [ $# -lt 1 ]; then
	echo "usage: $0 worker_name"
	exit 1
fi

echo $1 >> /usr/local/hadoop/etc/hadoop/dfs.exclude

hdfs dfsadmin -refreshNodes

#grep -v $1 $HADOOP_INSTALL/etc/hadoop/workers > $HADOOP_INSTALL/etc/hadoop/workers.tmp

#mv $HADOOP_INSTALL/etc/hadoop/workers.tmp $HADOOP_INSTALL/etc/hadoop/workers

echo "workers"
cat $HADOOP_INSTALL/etc/hadoop/workers

echo 
echo "dfs.exclude"
cat /usr/local/hadoop/etc/hadoop/dfs.exclude
