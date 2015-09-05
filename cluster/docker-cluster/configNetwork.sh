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

# reconfigure docker network setting
set -e

source ~/docker-cluster/kube-config/node.env

# TODO exit 1 will break ssh, maybe just exit?
if [ "$(id -u)" != "0" ]; then
  echo >&2 "configNetwork must be called as root!"
  exit 1
fi

if [[ ! -z $1 ]]; then
  # On master, we set flannel net config
  docker -H unix:///var/run/docker-bootstrap.sock run \
    --net=host gcr.io/google_containers/etcd:$ETCD_VERSION \
    etcdctl set /coreos.com/network/config \
    "{ \"Network\": \"$FLANNEL_NET\", \"Backend\": {\"Type\": \"vxlan\"}}"

fi


# TODO iface may change to a private network interface, eth0 is for default
flannelCID=$(docker -H unix:///var/run/docker-bootstrap.sock run \
    --restart=always -d --net=host --privileged \
    -v /dev/net:/dev/net quay.io/coreos/flannel:$FLANNEL_VERSION \
    /opt/bin/flanneld --etcd-endpoints=http://${MASTER_IP}:4001 -iface="eth0")

# sleep to wait network
sleep 5

# Copy flannel env out and source it on the host
docker -H unix:///var/run/docker-bootstrap.sock cp ${flannelCID}:/run/flannel/subnet.env .
source subnet.env


DOCKER_CONF=""

# Configure docker net settings, then restart it
# $lsb_dist is deceted in provision/common.sh
case "$lsb_dist" in
    fedora|centos|amzn)
        DOCKER_CONF="/etc/sysconfig/docker"
    ;;
    ubuntu|debian|linuxmint)
        DOCKER_CONF="/etc/default/docker"
    ;;
esac

# Append the docker opts
echo "DOCKER_OPTS=\"\$DOCKER_OPTS --mtu=${FLANNEL_MTU} --bip=${FLANNEL_SUBNET}\"" | sudo tee -a ${DOCKER_CONF}

ifconfig docker0 down

case "$lsb_dist" in
    fedora|centos|amzn)
        yum install bridge-utils && brctl delbr docker0 && systemctl restart docker
    ;;
    ubuntu|debian|linuxmint)
        apt-get install bridge-utils && brctl delbr docker0 && service docker restart
    ;;
esac

# sleep to wait docker daemon
sleep 2


##### Verify 
function verify() {
  local -a required_daemon=("/opt/bin/flanneld")
  local daemon
  for daemon in "${required_daemon[@]}"; do
    ssh $SSH_OPTS $2 "pgrep -f \"${daemon}\"" >/dev/null 2>&1 || {
      printf "Warning: $daemon is not running! \n"        
    }
  done
  printf "\n"
}