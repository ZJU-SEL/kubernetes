# Kubernetes deployed on multiple ubuntu nodes

This document describes how to deploy kubernetes on multiple ubuntu nodes, including 1 master node and 3 minion nodes, and people uses this approach can scale to **any number of minion nodes** by changing some settings with ease. Although there exists saltstack based ubuntu k8s installation ,  it may be tedious and hard for a guy that knows little about saltstack but want to build a really distributed k8s cluster. This approach is inspired by [k8s deploy on a single node](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/ubuntu_single_node.md).       [Cloud team from ZJU](https://github.com/ZJU-SEL) will keep updating this work.

### **Prerequisites：**
*1 The minion nodes have installed docker version 1.2+* 

*2  All machines can communicate with each orther*

*3 These guide  is tested OK on Ubuntu 14.04 LTS 64bit server, but it should also work on most Ubuntu versions*


### **Main Steps**
#### I. Make *kubernetes* , *etcd* and *flanneld* binaries

1. Either build from source or download the latest [kubernetest binaries](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/binary_release.md) .Then copy the kube binaries into `/opt/bin`  of every node.

2.  Similarly fetch an `etcd` and `etcdctl` binary from [etcd releases](https://github.com/coreos/etcd/releases) or build them using instructions at [coreos etcd github main page](https://github.com/coreos/etcd). Then copy the `etcd` and `etcdctl` binary into `/opt/bin` of every node.  

> **NOTE:** etcd stable version have recently upgraded from 0.4.6 to 2.0.0 This guide supports 2.0.0 only.
 
3. We use flanneld to build an overlay network across multiple minion machines. Follow  the instructions on [coreos flanneld github main page](https://github.com/coreos/flannel) to build an executable binary. Then copy the `flanneld` binary into `/opt/bin` of every node.

> **NOTE:** We used flannel here because we want to use overlay network, but please remember it is not the only choice, and it is also not a k8s' necessary dependence. Actually you can just build up k8s cluster natively, or use flannel, Open vSwitch or any other SDN tool you like, we just choose flannel here as a example.

#### II. Configue and install every components upstart script
The example cluster is listed as below:

| IP Address|Role |      
|---------|------|
|10.10.103.223| minion|
|10.10.103.224| minion|
|10.10.103.162| minion|
|10.10.103.250| master|

First of all, copy the cluster/ubuntu-cluster dirctory to **every node including both master and minon nodes**，and run `cluster/ubuntu-cluster/configue.sh` interactively  **on every node**.


> **NOTE:** The first input must be the same on every node , or the etcd will fail to start.


On master( infra1 10.10.103.250 ) node:

```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh
Welcome to use this script to configure k8s setup by ZJU-SEL

Please enter all your cluster node ips, master node comes first
And separated with blank space like "<ip_1> <ip2> <ip3> 10.10.103.250 10.10.103.223 10.10.103.224 10.10.103.162

Configure a master node press Y/y, configure a minion node press N/n
If this machine is running as both master and minion node press B/b > y

Enter IP address of this machine > 10.10.103.250


```

On every minion ( e.g.  10.10.103.224 ) node:


```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup by ZJU-SEL

Please enter all your cluster node ips, master node comes first
And separated with blank space like "<ip_1> <ip2> <ip3> 10.10.103.250 10.10.103.223 10.10.103.224 10.10.103.162

Configure a master node press Y/y, configure a minion node press N/n
If this machine is running as both master and minion node press B/b > n

Enter IP address of this machine > 10.10.103.224
```


If you want a node both running the master and minion,  you can press "b" on the second input. Just like below:


```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup by ZJU-SEL

Please enter all your cluster node ips, master node comes first
And separated with blank space like "<ip_1> <ip2> <ip3> 10.10.103.250 10.10.103.223 10.10.103.224

Configure a master node press Y/y, configure a minion node press N/n
If this machine is running as both master and minion node press B/b > b

Enter IP address of this machine > 10.10.103.250 


```

 **You can also customize your own settings in `/etc/default/{component_name}` in the future !**

#### III. Start all components
  1. On the master node:
  
     `$ sudo service etcd start`

     Then on every minion node:
     
     `$ sudo service etcd start`
  
  2. On any node:
  
     `$ /opt/bin/etcdctl mk /coreos.com/network/config '{"Network":"10.0.0.0/16"}'`
     
     This command will configure the flannel overlay network, we just use the default configuration. 
     
     Now, you can run the below command on another node to comfirm if the network setting is correct.
     
     `$ /opt/bin/etcdctl get /coreos.com/network/config`
     
     If you got `{"Network":"10.0.0.0/16"}`，then etcd cluster is working in good condition. **Victory is in sight！**
     If not , you should check` /var/log/upstart/etcd.log` to resolve this problem before going forward.
  
  
  3. On every minion node
  
     You can use ifconfig to see if there is a new network interface named `flannel0` coming up.
     
     Then run `$ sudo ./reconfigureDocker.sh` to alter the docker daemon settings.
 

**All done !**

#### IV. Validation
You can use kubectl command to see if the newly created k8s is working correctly. 

For example , `$ kubectl get minions` to see if you get all your minion nodes comming up. 

Also you can run kubernetes [guest-example](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples/guestbook) to build a redis backend cluster on the k8s．