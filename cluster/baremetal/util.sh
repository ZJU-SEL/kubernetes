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

# A library of helper functions that each provider hosting Kubernetes must implement to use cluster/kube-*.sh scripts.
set -e

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR"


# Assumed Vars:
#   KUBE_ROOT
function test-build-release {
 
}

# Verify ssh prereqs
function verify-prereqs {
  local rc

  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "Could not open a connection to your authentication agent."
  if [[ "${rc}" -eq 2 ]]; then
    eval "$(ssh-agent)" > /dev/null
    trap-add "kill ${SSH_AGENT_PID}" EXIT
  fi

  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "The agent has no identities."
  if [[ "${rc}" -eq 1 ]]; then
    # Try adding one of the default identities, with or without passphrase.
    ssh-add || true
  fi
  # Expect at least one identity to be available.
  if ! ssh-add -L 1> /dev/null 2> /dev/null; then
    echo "Could not find or add an SSH identity."
    echo "Please start ssh-agent, add your identity, and retry."
    exit 1
  fi

  # TODO check dockerd is running
}

# Install handler for signal trap
function trap-add {
  local handler="$1"
  local signal="${2-EXIT}"
  local cur

  cur="$(eval "sh -c 'echo \$3' -- $(trap -p ${signal})")"
  if [[ -n "${cur}" ]]; then
    handler="${cur}; ${handler}"
  fi

  trap "${handler}" ${signal}
}

function verify-cluster {
  echo
  echo "Kubernetes cluster is running.  The master is running at:"
  echo
  echo "  http://${MASTER_IP}:8080"
  echo

}

function verify-master(){

  printf "\n"

}

function verify-minion(){
 
  printf "\n"
}

# Detect the IP for the master
#
# Assumed vars:
#   MASTER_NAME
# Vars set:
#   KUBE_MASTER
#   KUBE_MASTER_IP
function detect-master {
 
}

# Detect the information about the minions
#
# Assumed vars:
#   nodes
# Vars set:
#   KUBE_MINION_IP_ADDRESS (array)
function detect-minions {
  
}

# Instantiate a kubernetes cluster on ubuntu
function kube-up() {
  KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
  source "${KUBE_ROOT}/cluster/ubuntu/${KUBE_CONFIG_FILE-"config-default.sh"}"

  # TODO pull hyperkube image, check first?
  MASTER_IP=${MASTER#*@}
  
  for node in $NODES
  do
    {
      if [ "$node" == $MASTER ]; then
        provision-master $MASTER_IP
      else
        provision-node ${node#*@}
      fi
    }
  done
  wait

  echo "Finished!"

  # verify-cluster
  # detect-master
  # export CONTEXT="ubuntu"
  # export KUBE_SERVER="http://${KUBE_MASTER_IP}:8080"

  # source "${KUBE_ROOT}/cluster/common.sh"

  # # set kubernetes user and password
  # gen-kube-basicauth

  # create-kubeconfig
}

function provision-master() {
  # copy the scripts to the ~/kube directory on the master
  echo "Deploying master on machine $MASTER_IP"
  echo
  ssh $SSH_OPTS $MASTER "mkdir -p ~/kube"
  scp -r $SSH_OPTS baremetal/config-default.sh baremetal/util.sh baremetal/configNetwork.sh baremetal/kube-config/ "${MASTER}:~/kube"

  # remote login to MASTER and use sudo to configue k8s master
  ssh $SSH_OPTS -t $MASTER "source ~/kube/util.sh; \
                            start-docker-bootstrap $MASTER_IP; \
                            start-etcd; \
                            start-kubelet-master $DNS_SERVER_IP $DNS_DOMAIN; \
                            start-kubeproxy; \
                            start-network;"
}

function provision-node() {
  # copy the scripts to the ~/kube directory on the node
  echo "Deploying node on machine $1"
  echo
  ssh $SSH_OPTS $node "mkdir -p ~/kube"
  scp -r $SSH_OPTS baremetal/config-default.sh baremetal/util.sh baremetal/configNetwork.sh baremetal/kube-config/ "$node:~/kube"

  # remote login to node and use sudo to configue k8s node
  ssh $SSH_OPTS -t $node "source ~/kube/util.sh; \
                       start-docker-bootstrap $node; \
                       start-kubelet $DNS_SERVER_IP $DNS_DOMAIN; \
                       start-kubeproxy; \
                       start-network;" 
}

# kubelet & kubeproxy use host network, so we can deal with contaienr network seperately
function start-network() {
  sudo -b ~/kube/configNetwork.sh
}

function start-docker-bootstrap {
  sudo -p "[sudo] password for $1: " -b docker -d -H unix:///var/run/docker-bootstrap.sock -p /var/run/docker-bootstrap.pid --iptables=false --ip-masq=false --bridge=none --graph=/var/lib/docker-bootstrap 2> /var/log/docker-bootstrap.log 1> /dev/null
    
  sleep 3
}

function start-etcd {
   sudo docker -H unix:///var/run/docker-bootstrap.sock run \
   --restart=always --net=host -d gcr.io/google_containers/etcd:${ETCD_VERSION} \
   /usr/local/bin/etcd --addr=127.0.0.1:4001 \
   --bind-addr=0.0.0.0:4001 \
   --data-dir=/var/etcd/data

}

# TODO add a option to stop kubelet
# TODO we need support add more workers
function start-kubelet-master {
  # Load kubelet configuration
  source ~/kube/kube-config/kubelet_config
  
  # start kubelet and then load master as a pod
  sudo docker run --net=host --privileged --restart=always -d \
    --volume=/:/rootfs:ro \
    --volume=/sys:/sys:ro \
    --volume=/dev:/dev \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
    --volume=/var/run:/var/run:rw \
    --net=host \
    --privileged=true \
    -v ~/kube/kube-config/master-multi.json:/etc/kubernetes/manifests-multi/master.json
    gcr.io/google_containers/hyperkube:v${K8S_VERSION} \
    /hyperkube kubelet --containerized \
    --api-servers=http://localhost:8080 \
    --config=/etc/kubernetes/manifests-multi/master.json \
    --hostname-override=127.0.0.1 \
    --cluster-dns=$1 \
    --cluster-domain=$2 $KUBELET_OPTS
}

function start-kubelet {
  # Load kubelet configuration
  source ~/kube/kube-config/kubelet_config
  
  # start kubelet
  sudo docker run --net=host --privileged --restart=always -d \
    --volume=/:/rootfs:ro \
    --volume=/sys:/sys:ro \
    --volume=/dev:/dev \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
    --volume=/var/run:/var/run:rw \
    gcr.io/google_containers/hyperkube:v${K8S_VERSION} \
    /hyperkube kubelet --containerized \
    --api-servers=http://$MASTER_IP:8080 \
    --hostname-override=$(hostname -i) \
    --cluster-dns=$1 \
    --cluster-domain=$2 $KUBELET_OPTS
}

function start-kubeproxy {
  sudo docker run -d --net=host --privileged \
    gcr.io/google_containers/hyperkube:v${K8S_VERSION} \
    /hyperkube proxy --master=http://$MASTER_IP:8080 --v=2   

}

# Delete a kubernetes cluster
function kube-down {
  KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
  source "${KUBE_ROOT}/cluster/ubuntu/${KUBE_CONFIG_FILE-"config-default.sh"}"

  for i in ${nodes}; do
    {
      echo "Cleaning on node ${i#*@}"
      ssh -t $i 'pgrep etcd && sudo -p "[sudo] password for cleaning etcd data: " service etcd stop && sudo rm -rf /infra*'
      # Delete the files in order to generate a clean environment, so you can change each node's role at next deployment.
      ssh -t $i 'sudo rm -f /opt/bin/kube* /etc/init/kube* /etc/init.d/kube* /etc/default/kube*; sudo rm -rf ~/kube /var/lib/kubelet'
    }
  done
  wait
}

# Update a kubernetes cluster with latest source
function kube-push {
  echo "not implemented"
}

# Perform preparations required to run e2e tests
function prepare-e2e() {
  echo "Ubuntu doesn't need special preparations for e2e tests" 1>&2
}
