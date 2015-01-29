#!/bin/bash
# simple use the sed to replace some ip settings on user's demand
# author chenxingyu wizard_cxy@hotmail.com

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