FROM vconrado/hadoop-cluster:3.1.1

RUN apt-get update \
    && apt-get install -y python3 python3-pip \
    && pip install hdfs \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ~/.cache/pip
