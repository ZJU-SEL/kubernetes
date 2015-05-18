#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
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

set -ex
# we only deploy one etcd instance among minions
if [ "$(id -u)" != "0" ]; then
  echo >&2 "Please run as root"
  exit 1
fi

MASTER_IP=""
HOSTNAME=""
flannelCID=""
if [ -z "${MASTER_IP}" ]; then
	echo "must set MASTER_IP and HOSTNAME variable"
	exit
fi

read -p "Is this the first minion node answer y/n > " bootstrap

# Start a bootstrap docker daemon for running
sudo -b docker -d -H unix:///var/run/docker-bootstrap.sock -p /var/run/docker-bootstrap.pid --iptables=false --ip-masq=false --bridge=none --graph=/var/lib/docker-bootstrap 2> /var/log/docker-bootstrap.log 1> /dev/null

# Wait a little bit
sleep 5

# Start etcd 
if [ "$bootstrap" == "y" ]; then
	sudo docker -H unix:///var/run/docker-bootstrap.sock run --net=host -d kubernetes/etcd:2.0.5.1 /usr/local/bin/etcd --addr=127.0.0.1:4001 --bind-addr=0.0.0.0:4001 --data-dir=/var/etcd/data
	# Set the net config for flannel
	sleep 5
    sudo docker -H unix:///var/run/docker-bootstrap.sock run --net=host kubernetes/etcd:2.0.5.1 etcdctl set /coreos.com/network/config '{ "Network": "10.1.0.0/16" }'
    flannelCID=$(sudo docker -H unix:///var/run/docker-bootstrap.sock run -d --net=host --privileged -v /dev/net:/dev/net quay.io/coreos/flannel:0.3.0 /opt/bin/flanneld)
elif [ "$bootstrap" == "n" ]; then
	read -p "please input your first minion ip > " minion1
	flannelCID=$(sudo docker -H unix:///var/run/docker-bootstrap.sock run -d --net=host --privileged -v /dev/net:/dev/net quay.io/coreos/flannel:0.3.0 /opt/bin/flanneld --etcd-endpoints=http://${minion1}:4001)
fi

sleep 5
sudo docker -H unix:///var/run/docker-bootstrap.sock cp ${flannelCID}:/run/flannel/subnet.env .
source subnet.env
# configure docker net settins ans restart it

echo "DOCKER_OPTS=\"\$DOCKER_OPTS --mtu=${FLANNEL_MTU} --bip=${FLANNEL_SUBNET}\"" | sudo tee -a /etc/default/docker

sudo ifconfig docker0 down
sudo apt-get install bridge-utils && sudo brctl delbr docker0
sudo service docker restart

# sleep a little bit
sleep 5

# Start minion
sudo docker run --net=host -d -v /var/run/docker.sock:/var/run/docker.sock  gcr.io/google_containers/hyperkube:v0.14.2 /hyperkube kubelet --api_servers=http://${MASTER_IP}:8080 --v=2 --address=0.0.0.0 --enable_server --hostname_override=${HOSTNAME}
sudo docker run -d --net=host --privileged gcr.io/google_containers/hyperkube:v0.14.2 /hyperkube proxy --master=http://${MASTER_IP}:8080 --v=2