FROM ubuntu:16.04

# FONTE: http://gaurav3ansal.blogspot.com/2017/08/installing-hadoop-300-alpha-4-multi.html

ENV HADOOP_USER=hadoopuser
ENV HADOOP_GRP=hadoopgroup

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 
ENV HADOOP_INSTALL=/usr/local/hadoop
ENV PATH=$PATH:$HADOOP_INSTALL/bin:$HADOOP_INSTALL/sbin  
ENV HADOOP_MAPRED_HOME=$HADOOP_INSTALL  
ENV HADOOP_COMMON_HOME=$HADOOP_INSTALL  
ENV HADOOP_HDFS_HOME=$HADOOP_INSTALL  
ENV YARN_HOME=$HADOOP_INSTALL

# Instalando pre-requisitos
RUN apt-get update \
    && apt-get install -y openssh-server wget rsync vim net-tools openjdk-8-jdk ant sudo iputils-ping \ 
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Criando usuario/grupo hadoopuser/hadoopgroup
RUN addgroup $HADOOP_GRP \
    && adduser --ingroup $HADOOP_GRP $HADOOP_USER \
    && adduser $HADOOP_USER sudo
    
# no password sudo
RUN echo "$HADOOP_USER ALL=(ALL:ALL) NOPASSWD:ALL" | EDITOR='tee -a' visudo

WORKDIR /tmp

# Download and install Hadoop
RUN wget https://www.apache.org/dist/hadoop/core/hadoop-3.1.1/hadoop-3.1.1.tar.gz \
    && tar -xzvf hadoop-3.1.1.tar.gz \
    && sudo mv hadoop-3.1.1 $HADOOP_INSTALL \
    && rm hadoop-3.1.1.tar.gz
   
COPY config/hadoop-env.sh  $HADOOP_INSTALL/etc/hadoop/
COPY config/hdfs-site.xml  $HADOOP_INSTALL/etc/hadoop/
COPY config/core-site.xml  $HADOOP_INSTALL/etc/hadoop/
COPY config/yarn-site.xml  $HADOOP_INSTALL/etc/hadoop/
COPY config/mapred-site.xml  $HADOOP_INSTALL/etc/hadoop/
COPY config/workers  $HADOOP_INSTALL/etc/hadoop/
COPY files/start-hadoop.sh  /home/$HADOOP_USER/

USER $HADOOP_USER

RUN mkdir -p ~/hdfs/namenode \
    && mkdir -p ~/hdfs/datanode \
    && mkdir -p $HADOOP_INSTALL/logs

# ssh without key
RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

RUN hdfs namenode -format

EXPOSE 9870
EXPOSE 8088

WORKDIR /home/$HADOOP_USER

CMD [ "sh", "-c", "sudo service ssh start; bash"]
