# Kubernetes deployed on ubuntu nodes

This document describes how to deploy kubernetes on ubuntu nodes, including 1 master node and 3 minion nodes, and people uses this approach can scale to **any number of minion nodes** by changing some settings with ease. Although there exists saltstack based ubuntu k8s installation ,  it may be tedious and hard for a guy that knows little about saltstack but want to build a really distributed k8s cluster. This new approach of kubernets deployment is much more easy and automatical than the previous one.

[Cloud team from ZJU](https://github.com/ZJU-SEL) will keep updating this work.

### **Prerequisites：**
*1 The minion nodes have installed docker version 1.2+ and bridge-utils to manipulate linux bridge* 

*2 All machines can communicate with each orther, no need to connect Internet (should use private docker registry in this case)*

*3 These guide is tested OK on Ubuntu 14.04 LTS 64bit server, but it should also work on most Ubuntu versions*

*4 Dependences of this guide: etcd-2.0.0, flannel-0.2.0, k8s-0.15.0, but it may work with higher versions*

*5 All the remote servers can be ssh logged in without a password by using key authentication* 


### **Main Steps**
#### I. Make *kubernetes* , *etcd* and *flanneld* binaries

On your laptop, copy `cluster/ubuntu` directory to your workspace.

The `build.sh` will download and build all the needed binaries into `./binaries`.

You can customize your etcd version or K8s version in the build.sh by changing  variable `ETCD_V` and `K8S_V` in build.sh, default etcd version is 2.0.0 and K8s version is 0.15.0.


```
$ cd cluster/ubuntu
$ sudo ./build.sh
```

Please make sure that there are `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kubelet`, `kube-proxy`, `etcd`, `etcdctl` and `flannel` in the binaries directory. All the other files are not necessary for a build for now. 

> We used flannel here because we want to use overlay network, but please remember it is not the only choice, and it is also not a k8s' necessary dependence. Actually you can just build up k8s cluster natively, or use flannel, Open vSwitch or any other SDN tool you like, we just choose flannel here as a example.

#### II. Configue and install every components upstart script
An example cluster is listed as below:

| IP Address|Role |      
|---------|------|
|10.10.103.223|   minion   |
|10.10.103.162|   minion   |
|10.10.103.250| both master and minion|

First configure the cluster information in cluster/ubuntu/config-default.sh, below is a simple sample.

```
export nodes="vcap@10.10.103.250 vcap@10.10.103.162 vcap@10.10.103.223"

export roles=("ai" "i" "i")

export NUM_MINIONS=${NUM_MINIONS:-3}

export PORTAL_NET=11.1.1.0/24

export FLANNEL_NET=172.16.0.0/16

```

The first variable `nodes` defines all your cluster nodes, MASTER node comes first and separated with blank space like `<user_1@ip_1> <user_2@ip_2> <user_3@ip_3> `

Then the `roles ` variable defines the role of above machine in the same order, "ai" stands for machine acts as both master and minion, "a" stands for master, "i" stands for minion. So they are just defined the k8s cluster as the table above described.

The `NUM_MINIONS` variable defines the total number of minions.

The `PORTAL_NET` variable defines the kubernetes service portal ip range. Please make sure that you do have a private ip range defined here.You can use below three private network range accordin to rfc1918. Besides you'd better not choose the one that conflicts with your own private network range.

     10.0.0.0        -   10.255.255.255  (10/8 prefix)

     172.16.0.0      -   172.31.255.255  (172.16/12 prefix)

     192.168.0.0     -   192.168.255.255 (192.168/16 prefix) 

The `FLANNEL_NET` variable defines the IP range used for flannel overlay network, should not conflict with above PORTAL_NET range

After all the above variable being set correctly. We can use below command in cluster/ directory to bring up the whole cluster.

`$ KUBERNETES_PROVIDER=ubuntu ./kube-up.sh` 

The scripts is automatically scp binaries and config files to all the machines and start the k8s service on them. The only thing you need to do is to type the sudo password when promoted. The current machine name is shown below like. So you will not type in the wrong password.

```

Deploying minion on machine 10.10.103.223

...

[sudo] password to copy files and start minion: 

```

If all things goes right, you will see the below message from console
`Cluster validation succeeded` indicating the k8s is up.

**All done !**

You can also use kubectl command to see if the newly created k8s is working correctly. 

For example , `$ kubectl get minions` to see if you get all your minion nodes comming up and ready. It may take some times for the minions be ready to use like below . 

```
NAME                 LABELS             STATUS

10.10.103.162       <none>              Ready

10.10.103.223       <none>              Ready

10.10.103.250       <none>              Ready
```

Also you can run kubernetes [guest-example](https://github.com/GoogleCloudPlatform/kubernetes/tree/master/examples/guestbook) to build a redis backend cluster on the k8s．


#### V. Trouble Shooting

Generally, what of this approach did is quite simple: 

1. Build and copy binaries and configuration files to proper dirctories on every node

2. Configure `etcd` using IPs based on input from user 

3. Create and start flannel network

So, whenver you have problem, do not blame Kubernetes, **check etcd configuration first** 

Please try:

1. Check `/var/log/upstart/etcd.log` for suspicisous etcd log 

2. Check `/etc/default/etcd`, as we do not have much input validation, a right config should be like:
	```
	ETCD_OPTS="-name infra1 -initial-advertise-peer-urls <http://ip_of_this_node:2380> -listen-peer-urls <http://ip_of_this_node:2380> -initial-cluster-token etcd-cluster-1 -initial-cluster infra1=<http://ip_of_this_node:2380>,infra2=<http://ip_of_another_node:2380>,infra3=<http://ip_of_another_node:2380> -initial-cluster-state new"
	```

3. You can use below command 
   `$ KUBERNETES_PROVIDER=ubuntu ./kube-down.sh` to bring down the cluster and run
   `$ KUBERNETES_PROVIDER=ubuntu ./kube-up.sh` again to start again.
    
4. You can also customize your own settings in `/etc/default/{component_name}` after configured success. 
