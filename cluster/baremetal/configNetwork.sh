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

if [ "$(id -u)" != "0" ]; then
  echo >&2 "Please run as root"
  exit 1
fi

source ~/kube/config-default.sh

# TODO Can we get the ENV properly?
# Set flannel net config
docker -H unix:///var/run/docker-bootstrap.sock run \
    --net=host gcr.io/google_containers/etcd:2.0.12 \
    etcdctl set /coreos.com/network/config \
    '{ "Network": "${FLANNEL_NET}", "Backend": {"Type": "vxlan"}}'


# iface may change to a private network interface, eth0 is for default
flannelCID=$(docker -H unix:///var/run/docker-bootstrap.sock run \
    --restart=always -d --net=host --privileged \
    -v /dev/net:/dev/net quay.io/coreos/flannel:0.5.0 /opt/bin/flanneld -iface="eth0")

sleep 8

# Copy flannel env out and source it on the host
docker -H unix:///var/run/docker-bootstrap.sock cp ${flannelCID}:/run/flannel/subnet.env .
source subnet.env

# Configure docker net settings, then restart it
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


# TODO sleep a little bit
ifconfig docker0 down

case "$lsb_dist" in
    fedora|centos|amzn)
        yum install bridge-utils && brctl delbr docker0 && systemctl restart docker
    ;;
    ubuntu|debian|linuxmint)
        apt-get install bridge-utils && brctl delbr docker0 && service docker restart
    ;;
esac