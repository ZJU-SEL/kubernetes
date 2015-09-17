<!-- BEGIN MUNGE: UNVERSIONED_WARNING -->

<!-- BEGIN STRIP_FOR_RELEASE -->

<img src="http://kubernetes.io/img/warning.png" alt="WARNING"
     width="25" height="25">
<img src="http://kubernetes.io/img/warning.png" alt="WARNING"
     width="25" height="25">
<img src="http://kubernetes.io/img/warning.png" alt="WARNING"
     width="25" height="25">
<img src="http://kubernetes.io/img/warning.png" alt="WARNING"
     width="25" height="25">
<img src="http://kubernetes.io/img/warning.png" alt="WARNING"
     width="25" height="25">

<h2>PLEASE NOTE: This document applies to the HEAD of the source tree</h2>

If you are using a released version of Kubernetes, you should
refer to the docs that go with that version.

<strong>
The latest 1.0.x release of this document can be found
[here](http://releases.k8s.io/release-1.0/docs/getting-started-guides/baremetal-docker-cluster.md).

Documentation for other releases can be found at
[releases.k8s.io](http://releases.k8s.io).
</strong>
--

<!-- END STRIP_FOR_RELEASE -->

<!-- END MUNGE: UNVERSIONED_WARNING -->
Kubernetes Deployment On Bare-metal Docker Cluster
------------------------------------------------

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Starting a Cluster](#starting-a-cluster)
    - [Add another Node into cluster](#add-another-node-into-cluster)
- [Test it out](#test-it-out)
- [Tear Down](#tear-down)
- [Trouble shooting](#trouble-shooting)

## Introduction

This document is originally designed as a replacement of [ubuntu cluster](ubuntu.md), aiming at eliminating OS differences, but due to some known issues of running k8s in docker (see: #13424), we choose to keep both guides until all issues are fixed.

This guide describes how to deploy kubernetes in bare-metal Docker cluster, 1 master and 2 node involved in the given examples. You can scale to **any number of nodes** by following the guide.The original idea was heavily inspired by @brendandburns's k8s in docker doc.

Cloud team from [Zhejiang University](https://github.com/ZJU-SEL) will maintain this work.


## Prerequisites

1. The nodes have installed docker version 1.2+.
2. All machines can communicate with each other, no need to connect Internet (but should configure to use
private docker registry in this case).
3. All the remote servers are ssh accessible.
4. If your machines were onced provisoned before, [Tear Down](#tear-down) first is highly recommended.


## Starting a Cluster

An example cluster is listed below:

| IP Address  |   Role   |
|-------------|----------|
|10.10.102.152|   node   |
|10.10.102.150|node (and master)|

Every machine in `NODES` will be provisioned as a Node (Minion), and you need to choose one of the `NODES` as Master, see below:

In `cluster/` directory:

```sh
export NODES="vcap@10.10.102.150 vcap@10.10.102.152"
export MASTER="vcap@10.10.102.150"
export KUBERNETES_PROVIDER=docker-cluster ./kube-up.sh
```

> Check `cluster/docker-cluster/config-default.sh` for more supported ENVs

If all things goes right, you will see the below message from console indicating the k8s is up.

```console
Deploy Complete!
... calling validate-cluster 
... Everything is OK! 
```

### Add another Node into cluster

Adding a Node to existing cluster is quite easy, just set `NODE_ONLY` to clarify you want to provision Node only:

```sh
export NODE_ONLY=yes
export NODES="vcap@10.10.102.153"
export MASTER="vcap@10.10.102.150"
```

### Test it out

On every node, you can see there're two containers running by `docker ps`:

```
kube_in_docker_proxy_xxx
kube_in_docker_kubelet_xxx
```

And on Master node, you can see extra master containers running:

```
k8s_scheduler.xxx
k8s_apiserver.xxx
k8s_controller-manager.xxx
```

> Currently, we assume 'Master only' node is meaningless, but please fire up issue if you want that, we can set `-runonce=false` for kubelet on the Master node

As we use `hyperkube` image to run k8s, we **do not** need to compile binaries, please download and extract `kubectl` binary from [releases page](https://github.com/kubernetes/kubernetes/releases).

At last, use `$ kubectl get nodes` to see if all of your nodes are ready.

```console
$ kubectl get nodes
NAME            LABELS                                 STATUS
10.10.102.150   kubernetes.io/hostname=10.10.103.150   Ready
10.10.102.153   kubernetes.io/hostname=10.10.102.153   Ready
```

Then you can run Kubernetes [guest-example](../../examples/guestbook/) to build a redis backend cluster on the k8s．

## Customize

One of the biggest benefits of using Docker to run Kubernetes is users can customize the cluster freely before deployment begin:

### Master

he configure file of Master locates in `docker-cluster/kube-config/master-multi.json`, which will be mounted as volume for Master Pod to comsume, you can customize it freely **before deploying**.

You can even change the configuration of Master after the deployment has done without re-deploy that Master Node, see:

1. Login the Master node
2. Change the content in `~/docker-cluster/kube-config/master-multi.json`
3. Restart the affected master containers

### kubelet

Except a few basic options defined in `provision/master.sh|node.sh`, you can customize the `docker-cluster/kube-config/kubelet.env` freely to add or update `kubelet` options **before deploying**.

## Tear Down

In `cluster/` directory:

```sh
export NODES="vcap@10.10.102.150 vcap@10.10.102.152"
export KUBERNETES_PROVIDER=docker-cluster ./kube-down.sh
```

## Trouble shooting

Although using docker to deploy k8s is much simpler than ordinary way, here're some tips to follow if there's any trouble.

### What did the scripts did?

1. Start a bootstrap daemon
2. Start `flannel` on every node's bootstrap daemon, `etcd` on Master's bootstrap daemon
3. Start `kubelet` & `proxy` containers by using `hyperkube` image on every node
4. `kubelet` on the Master node will start master Pod (contains `api-server`, `controller-manager` & `scheduler`)from a json file, that file is bind mounted in a host dir.

### Useful tips

1. Make sure you have access to the images stored in `gcr.io`, otherwise, you need to mannually load `hyperkube` image into your docker daemon and `etcd` into docker bootstrap daemon.

2. As we said, there're two kinds of daemon running on a node. The bootstrap daemon works on `-H unix:///var/run/docker-bootstrap.sock` with work_dir `/var/lib/docker-bootstrap`. Thus re-configuring and restarting docker daemon will never influence etcd and flanneld.

3. For k8s admins, you should learn to manage process by using docker container, `docker ps`, `docker logs` & `docker exec` solve most problems.

### Limitations

Due to `kubelet` runs insider docker container, there's known issue of secrets volume failure as there's no mount propagation. See: [#13791](https://github.com/kubernetes/kubernetes/pull/13791) , and the root cause: [docker #15648](https://github.com/docker/docker/pull/15648)

`hostDir` and `emptyDir` will not be influenced, but other volume types handled by `kubelet` like NFS volume will also exposed to the issues above

<!-- BEGIN MUNGE: GENERATED_ANALYTICS -->
[![Analytics](https://kubernetes-site.appspot.com/UA-36037335-10/GitHub/docs/getting-started-guides/baremetal-docker-cluster.md?pixel)]()
<!-- END MUNGE: GENERATED_ANALYTICS -->
