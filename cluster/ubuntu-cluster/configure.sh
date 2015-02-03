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

# author ZJU-SEL 

set -e

if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

echo "Welcome to use this script to configure k8s setup"
echo

while true; do
	read -p "Configure a master node press Y/y, configure a minion node press N/n > " yn 
    echo
    read -p "Use 2.0.0 version etcd press Y/y, Use 0.4.6 version etcd press N/n > " isEtcdNew
    echo

	if [ "$isEtcdNew" == "y" ] || [ "isEtcdNew" == "Y" ]; then
	    # we use static etcd configuration 
		# see https://github.com/coreos/etcd/blob/master/Documentation/clustering.md#static
		read -p "please enter your etcd cluster configuration like \"name_1=url1,name_2=url2,name_3=url3,name_4=url4\" > " cluster
		echo
	fi

	case $yn in
	    [Yy]* )
	        if [ "$isEtcdNew" == "y" ] || [ "isEtcdNew" == "Y" ]; then
	        	# 2.0 version etcd
	        	read -p "Enter this machine's name, must be the same with the above configuration like name_1 if you on ip_1 machine > " name
	        	echo
	        	read -p "Enter your k8s master IP address > " myIP
	        	echo ETCD_OPTS=\"-name ${name} -initial-advertise-peer-urls http://${myIP}:2380 -listen-peer-urls http://${myIP}:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster ${cluster} -initial-cluster-state new\" > default_scripts/etcd
	        else
	        	# 0.4.6 version etcd
	        	# USE MY_IP as ETCD name
	        	read -p "Enter your k8s master IP address > " myIP
	        	echo 
	        	echo ETCD_OPTS=\"-name ${myIP} -addr ${myIP}:4001 -peer-addr ${myIP}:7001\" > default_scripts/etcd
	        fi
	        read -p "Enter your k8s minion IP addresses, comma separated like '<ip_1>,<ip_2>,<ip_3>' > " minionIPs
	        
	        sed -i "s/MINION_IPS/${minionIPs}/g" default_scripts/kube-controller-manager        
	        break
	        ;;
	    [Nn]* )
            if [ "$isEtcdNew" == "y" ] || [ "isEtcdNew" == "Y" ]; then
            	# 2.0 version etcd 
            	read -p "Enter this machine's name, must be the same with the above configuration like name_2 if you on ip_2 machine > " name
            	echo
            	read -p "Enter your k8s minion IP address > " myIP
                echo
                echo ETCD_OPTS=\"-name ${name} -initial-advertise-peer-urls http://${myIP}:2380 -listen-peer-urls http://${myIP}:2380 -initial-cluster-token etcd-cluster-1 -initial-cluster ${cluster} -initial-cluster-state new\" > default_scripts/etcd
	        else
	        	# 0.4.6 version etcd
	        	# USE myIP as ETCD name
	        	read -p "Enter the k8s master node IP address > " masterIP
                echo
                read -p "Enter your k8s minion IP address > " myIP
	        	echo ETCD_OPTS=\"-name ${myIP} -addr ${myIP}:4001 -peer-addr ${myIP}:7001 -peers=${myIP}:7001,${masterIP}:7001\" > default_scripts/etcd
	        fi
	        sed -i "s/MY_IP/${myIP}/g" default_scripts/kubelet
	        break
	        ;;
	    * )
	        echo "Please answer Y/y or N/n."
	        ;;
	esac
done

./cpfile.sh