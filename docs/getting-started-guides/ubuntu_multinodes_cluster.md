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

> **NOTE:** etcd stable version have recently upgraded from 0.4.6 to 2.0.0 This guide supports both two versions. You can choose whatever version you like. If you'd like to use advanced features of etcd, please choose 2.0+
 
3. We use flanneld to build an overlay network across multiple minion machines. Follow  the instructions on [coreos flanneld github main page](https://github.com/coreos/flannel) to build an executable binary. Then copy the `flanneld` binary into `/opt/bin` of every node.

> **NOTE:** We used flannel here because we want to use overlay network, but please remember it is not the only choice, and it is also not a k8s' necessary dependence. Actually you can just build up k8s cluster natively, or use flannel, Open vSwitch or any other SDN tool you like, we just choose flannel here as a example.

#### II. Configue and install every components upstart script
The example cluster is listed as below:

|Name| IP Address|Role |      
|------|---------|------|
|infra0|10.10.103.223| minion|
|infra1|10.10.103.224| minion|
|infra2|10.10.103.162| minion|
|infra3|10.10.103.250| master|

First of all, copy the cluster/ubuntu-cluster dirctory to **every node including both master and minon nodes**，and run `cluster/ubuntu-cluster/configue.sh` interactively to **on every node**.

If you are using **etcd 0.4.6**:

On master node( 10.10.103.250 ):
```
$ cd ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup

Configure a master node press Y/y, configure a minion node press N/n > y

Use 2.0.0 version etcd press Y/y, Use 0.4.6 version etcd press N/n > n

Enter your k8s master IP address > 10.10.103.250

Enter your k8s minion IP addresses, comma separated like '<ip_1>,<ip_2>,<ip_3>' > 10.10.103.223,10.10.103.224,10.10.103.162
```

On every minion node( e.g. 10.10.103.223 ):

```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup

Configure a master node press Y/y, configure a minion node press N/n > n

Use 2.0.0 version etcd press Y/y, Use 0.4.6 version etcd press N/n > n

Enter your k8s minion IP address > 10.10.103.223

Enter the k8s master node IP address > 10.10.103.250
```

If you are using **etcd 2.0.0**

You may need write down this setting (or remember it in your mind) so that you can copy and paste this long config string in the next steps. The string is like:
```
infra0=http://10.10.103.223:2380,infra1=http://10.10.103.224:2380,infra2=http://10.10.103.162:2380,infra3=http://10.10.103.250:2380
```
This string will be used in the following part to fill in the etcd `-initial-cluster` option. It is a little tedious and long , please do check it is correct. For more information , see [etcd doc](https://github.com/coreos/etcd/blob/master/Documentation/clustering.md#static).


On master( infra3 10.10.103.250 ) node:
```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh
Welcome to use this script to configure k8s setup

Configure a master node press Y/y, configure a minion node press N/n > y

Use 2.0.0 version etcd press Y/y, Use 0.4.6 version etcd press N/n > y

Please enter your etcd cluster configuration like "name_1=url_1,name_2=url_2,name_3=url_3" > infra0=http://10.10.103.223:2380,infra1=http://10.10.103.224:2380,infra2=http://10.10.103.162:2380,infra3=http://10.10.103.250:2380

Enter this machine's name, must be the same with the above configuration like 'name_1' if you on 'ip_1' machine > infra3

Enter your k8s master IP address > 10.10.103.250

Enter your k8s minion IP addresses, comma separated like '<ip_1>,<ip_2>,<ip_3>' > 10.10.103.223,10.10.103.224,10.10.103.162

```
On every minion ( e.g. infra2 10.10.103.162 ) node:

```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup

Configure a master node press Y/y, configure a minion node press N/n > n

Use 2.0.0 version etcd press Y/y, Use 0.4.6 version etcd press N/n > y

Please enter your etcd cluster configuration like "name_1=url_1,name_2=url_2,name_3=url_3" > infra0=http://10.10.103.223:2380,infra1=http://10.10.103.224:2380,infra2=http://10.10.103.162:2380,infra3=http://10.10.103.250:2380

Enter this machine's name, must be the same with the above configuration like 'name_2' if you on 'ip_2' machine > infra2

Enter your k8s minion IP address > 10.10.103.162
```

 **You can also customize your own settings in `/etc/default/{component_name}` in the future !**

#### III. Start all components
  1. On the master node:
  
     `$ sudo service etcd start`

     Then on every minion node:
     
     `$ sudo service etcd start`
   
     **NOTE:** Start order must be kept if you use etcd 0.4.6
  
  2. On any node:
  
     `$ /opt/bin/etcdctl mk /coreos.com/network/config '{"Network":"10.0.0.0/16"}'`
     
     This command will configure the flannel overlay network, we just use the default configuration. 
     
     Now, you can run the below command on another node to comfirm if the network setting is correct.
     
     `$ /opt/bin/etcdctl get /coreos.com/network/config`
     
     If you got `{"Network":"10.0.0.0/16"}`，then etcd cluster is working in good condition. **Victory is in sight！**
     If not , you should check` /var/log/upstart/etcd.log` to resolve this problem before going forward.
  
  
  3. On every minion node
     
     `$ sudo service flanneld start`
  
     You can use ifconfig to see if there is a new network interface named `flannel0` coming up.
     
     Then run `$ sudo ./reconfigureDocker.sh` to alter the docker daemon settings.
   
  
  4. Back to master node and start kube-apiserver ，kube-scheduler and kube-controller-manager:
     
     `$ sudo service kube-apiserver start`
    
     `$ sudo service kube-scheduler start `

     `$ sudo service kube-controller-manager start`
  
  5. Back to every minion node to start kubelet and kube-proxy:
    
     `$ sudo service kubelet start`

     `$ sudo service kube-proxy start`


#### IV. Validation
You can use kubectl command to see if the newly created k8s is working correctly. 

For example , `$ kubectl get minions` to see if you get all your minion nodes comming up. 

Also you can run kubernetes [guest-example](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples/guestbook) to build a redis backend cluster on the k8s．