#!/bin/bash
# script to reconfigue the docker daemon network settings 
# author chenxingyu wizard_cxy@hotmail.com


# Run as root only
if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

ip link set dev docker0 down
brctl delbr docker0

source /run/flannel/subnet.env

echo DOCKER_OPTS=\"-H tcp://127.0.0.1:4243 -H unix:///var/run/docker.sock \
    --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU}\" > /etc/default/docker

service docker restart