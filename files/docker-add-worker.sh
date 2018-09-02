#!/bin/bash

if [ $# -lt 1 ]; then
	echo "usage: $0 worker_name"
	exit 1
fi

echo $1 >> $HADOOP_INSTALL/etc/hadoop/workers

cat $HADOOP_INSTALL/etc/hadoop/workers
