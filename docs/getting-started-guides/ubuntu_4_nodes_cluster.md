# Kubernetes deployed on multiple ubuntu nodes

This document describes how to run kubernetes on a 4 nodes cluster (one master and three minions) with flannel network on Ubuntu system. [Cloud team from ZJU](https://github.com/ZJU-SEL) will keep updating this work.

This post describes how to deploy kubernetes on multiple ubuntu nodes, including 1 master node and 3 minion nodes, and people uses this approach can scale to **any number of minion nodes** by changing some settings with ease.
Although there exists saltstack based ubuntu k8s installation ,  it may be tedious and hard for a guy that knows little about saltstack but want to build a really distributed k8s cluster. This approach is inspired by [k8s deploy on a single node](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/ubuntu_single_node.md)

### **Prerequisites：**
*1 The minion nodes have installed docker version 1.2+* 

*2  All machines can communicate with each orther*

*3 These scripts only tested on Ubuntu 14.04 LTS 64bit, but it should work in most distributions*


### **Main Steps**
#### １Make *kubernetes* , *etcd* and *flanneld* binaries

1. Either build from source or download the latest [kubernetest binaries](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/getting-started-guides/binary_release.md) .Then copy the kube binaries into `/opt/bin`  of every node.

2.  Similarly fetch an `etcd` and `etcdctl` binary from [etcd releases](https://github.com/coreos/etcd/releases) or build them using instructions at [coreos etcd github main page](https://github.com/coreos/etcd). Then copy the `etcd` and `etcdctl` binary into `/opt/bin` of every node.
 
3. We use flanneld to build an overlay network across multiple minion machines. Follow  the instructions on [coreos flanneld github main page](https://github.com/coreos/flannel) to build an executable binary. Then copy the `flanneld` binary into `/opt/bin` of every node.

#### ２ Configue and install every components upstart script

Copy the cluster/ubuntu-cluster dirctory to **every node including both master and minon nodes**，and run `cluster/ubuntu-cluster/configue.sh` interactively to **on every node**.

On master node:
```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup
Configure a master node press 'Y or y', configure a minion node press 'N or n' > y
Enter your k8s master IP address > 10.10.10.88
Enter your k8s minion IP addresses, comma separated like '<ip_1>,<ip_2>,<ip_3>' > 10.10.0.22,10.10.0.34,10.10.0.35
```

On minion node:

```
$ cd cluster/ubuntu-cluster
$ sudo ./configure.sh 
Welcome to use this script to configure k8s setup
Configure a master node press 'Y or y', configure a minion node press 'N or n' > n
Enter your k8s minion IP address > 10.10.0.22
Enter the k8s master node IP address > 10.10.0.88
```
 You can also customize your own settings in `/etc/default/{component_name}` in the future !

#### ３ Start all components
  1. On the master node:
  
     `$ sudo service etcd start`

     Then on every minion node:
     
     `$ sudo service etcd start`
	 
     NOTE:  This **start order must be kept**．
	
  2. On any node:
  
     `$ etcdctl mk /coreos.com/network/config '{"Network":"10.0.0.0/16"}'`
     
     This command will configure the flannel overlay network, we just use the default configuration. 
     
     Now, you can run the below command on another node to comfirm if the network setting is correct.
     
     `$ etcdctl get /coreos.com/network/config`
     
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

#### 4 Post Check
　 You can use kubectl command to see if the newly created k8s is working correctly. For example , `$ kubectl get minions` to see if you get all your minion nodes comming up. Also you can run kubernetes [guest-example](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples/guestbook) to build a redis backend cluster on the k8s．
