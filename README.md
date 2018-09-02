# Hadoop Multi Node Docker Cluster

## 1. Build the image

### 1.1 Clone github repository

```bash
git clone https://github.com/vconrado/hadoop-docker.git
```

### 1.2 Build
```bash
cd hadoop-docker
./build.sh
```

## 2. Start a Multi Node Hadoop

Creating a cluster named **c1** with 1 **master** (namenode/datanode) container + 2 **slave** (datanodes) containers
```bash
./hadoop-docker cluster create c1 2
```

Inspecting cluster **c1**
```bash
./hadoop-docker cluster inspect c1
```

Adding more **3** datanodes to cluster **c1**
```bash
./hadoop-docker datanode add c1 3
```

Removing the datanode **id=2** from cluster **c1**
```bash
./hadoop-docker datanode rm c1 2
```

Re-adding the datanode **id=2** to cluster **c1**
```bash
./hadoop-docker datanode readd c1 2
```



<!--
root@804f0b57432b:/# cat ~/.hdfscli.cfg 
[global]
default.alias = dev

[dev.alias]
url = http://hadoop-master:9870
user = hadoopuser
-->

