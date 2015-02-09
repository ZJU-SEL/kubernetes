#!/bin/bash

# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# simple use the sed to replace some ip settings on user's demand
# Run as root only

# author ZJU-SEL http://www.sel.zju.edu.cn/

set -e

function cpMaster(){
	# copy /etc/init files
    cp init_conf/etcd.conf /etc/init/
    cp init_conf/kube-apiserver.conf /etc/init/
    cp init_conf/kube-controller-manager.conf /etc/init/
    cp init_conf/kube-scheduler.conf /etc/init/

    # copy /etc/initd/ files
    cp initd_scripts/etcd /etc/init.d/
    cp initd_scripts/kube-apiserver /etc/init.d/
    cp initd_scripts/kube-controller-manager /etc/init.d/
    cp initd_scripts/kube-scheduler /etc/init.d/

    # copy default configs
    cp default_scripts/etcd /etc/default/
    cp default_scripts/kube-apiserver /etc/default/
    cp default_scripts/kube-scheduler /etc/default/
    cp default_scripts/kube-controller-manager /etc/default/
}

function cpMinion(){
	# copy /etc/init files
    cp init_conf/etcd.conf /etc/init/
    cp init_conf/kubelet.conf /etc/init/
    cp init_conf/flanneld.conf /etc/init/
    cp init_conf/kube-proxy.conf /etc/init/

    # copy /etc/initd/ files
    cp initd_scripts/etcd /etc/init.d/
    cp initd_scripts/flanneld /etc/init.d/
    cp initd_scripts/kubelet /etc/init.d/
    cp initd_scripts/kube-proxy /etc/init.d/

    # copy default configs
    cp default_scripts/etcd /etc/default/
    cp default_scripts/flanneld /etc/default/
    cp default_scripts/kube-proxy /etc/default
    cp default_scripts/kubelet /etc/default/
}

if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

echo "Welcome to use this script to configure k8s setup by ZJU-SEL"

echo

PATH=$PATH:/opt/bin

if ! $(grep Ubuntu /etc/lsb-release > /dev/null 2>&1)
then
    echo "warning: not detecting a ubuntu system"
    exit 1
fi

if ! $(which etcd > /dev/null)
then
    echo "warning: etcd binary is not found in the PATH: $PATH"
    exit 1
fi


if ! $(which kube-apiserver > /dev/null) && ! $(which kubelet > /dev/null)
then
    echo "warning: kube binaries are not found in the $PATH"
    exit 1
fi

# detect the etcd version, we support only etcd 2.0.
etcdVersion=$(/opt/bin/etcd --version | awk '{print $3}')

if [ "$etcdVersion" != "2.0.0" ]; then
	echo "We only support 2.0.0 version of etcd"
	exit 1
fi

declare -A mm

ii=1

# we use static etcd configuration 
# see https://github.com/coreos/etcd/blob/master/Documentation/clustering.md#static
echo "Please enter all your cluster node ips, master node comes first"
read -p "And separated with blank space like \"<ip_1> <ip2> <ip3> " etcdIPs
# use an array to record name and ip
for i in $etcdIPs
do
    name="infra"$ii
    item="$name=$i"
    if [ "$ii" == 1 ]; then 
        cluster=$item
    else
        cluster="$cluster,$item"
        if [ "$ii" -gt 2 ]; then
        	minionIPs="$minionIPs,$i"
        else
        	minionIPs="$i"
        fi
    fi
    mm[$i]=$name
    let ii++
done
echo 

while true; do
	echo "Configure a master node press Y/y, configure a minion node press N/n"
	read -p "If this machine is running as both master and minion node press B/b > " option 
    echo

	case $option in
	    [Yy]* )
        	read -p "Enter IP address of this machine > " myIP
        	etcdName=${mm[$myIP]}
        	echo ETCD_OPTS=\"-name ${etcdName} -initial-advertise-peer-urls http://${myIP}:2380 -listen-peer-urls http://${myIP}:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster ${cluster} -initial-cluster-state new\" > default_scripts/etcd
	        sed -i "s/MINION_IPS/${minionIPs}/g" default_scripts/kube-controller-manager 
	        cpMaster
	        break
	        ;;
	    [Nn]* )     
        	read -p "Enter IP address of this machine > " myIP
            echo
           
            etcdName=${mm[$myIP]}
            echo ETCD_OPTS=\"-name ${etcdName} -initial-advertise-peer-urls http://${myIP}:2380 -listen-peer-urls http://${myIP}:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster ${cluster} -initial-cluster-state new\" > default_scripts/etcd
	        sed -i "s/MY_IP/${myIP}/g" default_scripts/kubelet
	        
	        cpMinion
	        break
	        ;;
	    [Bb]* )
        	read -p "Enter IP address of this machine > " myIP
            echo 
            etcdName=${mm[$myIP]}
            echo ETCD_OPTS=\"-name ${etcdName} -initial-advertise-peer-urls http://${myIP}:2380 -listen-peer-urls http://${myIP}:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster ${cluster} -initial-cluster-state new\" > default_scripts/etcd
	        sed -i "s/MY_IP/${myIP}/g" default_scripts/kubelet 

	        minionIPs="$minionIPs,$myIP"       
	        sed -i "s/MINION_IPS/${minionIPs}/g" default_scripts/kube-controller-manager
	        
	        cpMaster
	        cpMinion
	        break
	        ;;
	    * )
	        echo "Please answer Y/y or N/n or B/b."
	        ;;
	esac
done