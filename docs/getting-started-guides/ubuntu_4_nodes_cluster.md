
This document describes how to run kubernetes on a 4 nodes cluster (one master and three minions) Ubuntu system. [Cloud team from ZJU](https://github.com/ZJU-SEL) will keep updating this work.

# Kubernetes deployed on multiple ubuntu nodes

This post describes how to deploy kubernetes on multiple ubuntu nodes, including 1 master node and 3 minion nodes, and people uses this approach can scale to **any number of minion nodes** by changing some settings with ease.
Although there exists saltstack based ubuntu k8s installation ,  it may be tedious and hard for a guy that knows little about saltstack but want to build a really distributed k8s cluster. This approach is inspired by [k8s deploy on a single node](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/ubuntu_single_node.md)

### **Prerequisites：**

*1 The minion nodes have installed docker version 1.2+* 
*2  All machines can communicate with each orther*


### **Main Steps**
#### １Make *kubernetes* , *etcd* and *flanneld* binaries

1. Either build from source or download the latest [kubernetest binaries](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/binary_release.md) .Then copy the kube binaries into `/opt/bin` 

2.  Similarly fetch an `etcd` binary from [etcd releases](https://github.com/coreos/etcd/releases) or build the `etcd` yourself using instructions at [coreos etcd github main page](https://github.com/coreos/etcd). Then copy the `etcd` binary into `/opt/bin`.
 
3. We use flanneld to build an overlay network across multiple minion machines. Follow  the instructions on [coreos flanneld github main page](https://github.com/coreos/flannel) to build an executable binary. Then copy the `flanneld` binary into `/opt/bin` too.

#### ２ Configue and install every components upstart script

Copy the cluster/ubuntu-cluster dirctory to **every node including both master and minon nodes**，and run cluster/ubuntu-cluster/configue.sh interactively to configure every node.

A sample master node configuration process works like below:
```
wizard@smart:~/go/src/github.com/GoogleCloudPlatform/kubernetes/cluster/ubuntu-cluster$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup
Going to configure a master node press Y/y Or a minion node press N/n > y
Enter your IP_address like 10.10.0.88 > 10.10.10.88
Enter your minion IP_address, comma separated like 10.10.0.34,10.10.0.35,10.10.0.36 > 10.10.0.22,10.10.0.34,10.10.0.35
```

A sample  minion node configuration process works like below:

```
wizard@smart:~/go/src/github.com/GoogleCloudPlatform/kubernetes/cluster/ubuntu-cluster$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup
Going to configure a master node press Y/y Or a minion node press N/n > n
Enter your IP_address like 10.10.0.66 > 10.10.0.22
Enter the master node ip like 10.10.0.88 > 10.10.0.88
```
 You can also customize your own settings in /etc/default/{componentname} like /etc/default/kubelet in the future !

#### ３ Start all components
  1. Fisrt on the master node , run the command "sudo service etcd start"  to start  etcd , then on every minion node , run the command "sudo service etcd start" to start etcd. The  start order must be kept, or etcd cluster will fail to start．
  2. On any node, issue below command to configure the flannel overlay network, Here we only use the default configuration.
`$ etcdctl mk /coreos.com/network/config '{"Network":"10.0.0.0/16"}'`
   After issuing the above command , you can run the below command on the other etcd node to see if the network setting is correct.
`$ etcdctl get /coreos.com/network/config`
  If the return value is {"Network":"10.0.0.0/16"}，then etcd cluster is working in good condition.
   **Victory is in sight！**
  If not , you must check /var/log/upstart/etcd.log to resolve this problem before going forward.
  3. Then on every minion machine run the command `sudo service flanneld start` to start flanneld．Use ifconfig to see if there is a new network interface named flannel0 coming up. If so，Then run `sudo ./ reconfigureDocker.sh` to alter the docker daemon settings.
  4. On master node, issue the command `sudo service kube-apiserver start && service kube-scheduler start && service kube-controller-manager start` to start kube-apiserver ，kube-scheduler and kube-controller-manager.
  5. On every minion machine, issue the command `sudo service kubelet start && service kube-proxy start` to start kubelet and kube-proxy.

#### 4 Post Check
　 You can use kubectl command to see if the newly created k8s is working correctly. For example , `kubectl get minions` to see if you get all your minion nodes comming up. Also you can run kubernetes [guest-example](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples/guestbook) to build a redis backend cluster on the k8s．