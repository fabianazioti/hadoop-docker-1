FROM vconrado/hadoop-cluster:3.1.1

RUN sudo apt-get update \
    && sudo apt-get install -y python3 python3-pip \
    && sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
    
RUN pip3 install hdfs \
    && rm -rf ~/.cache/pip
