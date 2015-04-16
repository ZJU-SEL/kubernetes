#!/bin/bash
# Run as root only
# reconfigure docker network setting

if [ "$(id -u)" != "0" ]; then
  echo >&2 "Please run as root"
  exit 1
fi

attempt=0
while true; do
  /opt/bin/etcdctl get /coreos.com/network/config 
  if [[ "$?" == 0 ]]; then
    break
  else
  	# enough timeout?? 
    if (( attempt > 600 )); then
      echo "timeout for waiting network config" > ~/kube/err.log
      exit 2
    fi

    /opt/bin/etcdctl mk /coreos.com/network/config '{"Network":"10.0.0.0/16"}'
    attempt=$((attempt+1))
    sleep 3
  fi
done

#wait some secs for flannel ready
sleep 10
sudo ip link set dev docker0 down
sudo brctl delbr docker0

source /run/flannel/subnet.env

echo DOCKER_OPTS=\"-H tcp://127.0.0.1:4243 -H unix:///var/run/docker.sock \
  --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU}\" > /etc/default/docker
sudo service docker restart