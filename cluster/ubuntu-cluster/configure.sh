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

set -e

if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

echo "Welcome to use this script to configure k8s setup"
read -p "Configure a master node press Y/y, configure a minion node press N/n > " yn 

while true; do
	case $yn in
	    [Yy]* )
            read -p "Enter your k8s master IP address > " myIP
            read -p "Enter your k8s minion IP addresses, comma separated like '<ip_1>,<ip_2>,<ip_3>' > " minionIPs
	        # USE MY_IP as ETCD name 
	        echo ETCD_OPTS=\"-name ${myIP} -addr ${myIP}:4001 -peer-addr ${myIP}:7001\" > default_scripts/etcd
	        sed -i "s/MINION_IPS/${minionIPs}/g" default_scripts/kube-controller-manager        
	        break
	        ;;
	    [Nn]* )
            read -p "Enter your k8s minion IP address > " myIP
            read -p "Enter the k8s master node IP address > " masterIP
            # USE MY_IP as ETCD name
            echo ETCD_OPTS=\"-name ${myIP} -addr ${myIP}:4001 -peer-addr ${myIP}:7001 -peers=${myIP}:7001,${masterIP}:7001\" > default_scripts/etcd
	        sed -i "s/MY_IP/${myIP}/g" default_scripts/kubelet
	        break
	        ;;
	    * )
	        echo "Please answer Y/y or N/n."
	        ;;
	esac
done

./cpfile.sh