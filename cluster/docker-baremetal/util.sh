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

# Implementation of baremetal docker based kubernetes provider
set -e

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

# Verify SSH is available and ENVs are set
function verify-prereqs-baremetal {
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
}

# Deploy master (or master & node)
#
# Assumed vars:
#   MASTER
#   REGISTER_MASTER_KUBELET
#   SSH_OPTS
function deploy-node-master-baremetal() {
  local files="${KUBE_ROOT}/cluster/images/hyperkube/master-multi.json \
  ${KUBE_ROOT}/cluster/docker"
  local dest_dir="${MASTER}:~"
  
  scp -r $SSH_OPTS $files $dest_dir
  
  local machine=$MASTER
  local cmd="sudo bash ~/docker/kube-deploy/master.sh $REGISTER_MASTER_KUBELET;"
  # Remotely login to $MASTER and use $cmd to deploy k8s master
  # $REGISTER_MASTER_KUBELET is the flag when this machine is both master & node
  ssh $SSH_OPTS -t $machine $cmd
}

# Deploy node
#
# Assumed vars:
#   node
#   SSH_OPTS
function deploy-node-baremetal() {
  local files="${KUBE_ROOT}/cluster/docker"
  local dest_dir="$node:~"
  scp -r $SSH_OPTS $files $dest_dir 

  # remote login to $node and use $cmd to deploy k8s node
  ssh $SSH_OPTS -t $node "sudo bash ~/docker/kube-deploy/node.sh;" 
}


# Destroy k8s cluster
#
# Assumed vars:
#   node
#   SSH_OPTS
function kube-down-baremetal() {
  for i in ${NODES}; do
  {
    echo "... Cleaning on node ${i#*@}"
    ssh -t $i "sudo bash ~/destroy.sh clear_all && rm -rf ~/docker/"
  }
  done 
}

# Verify cluster
# 
# Assumed vars:
#   MASTER
#   NODES
#   SSH_OPTS
function validate-cluster-baremetal() {
  ssh $SSH_OPTS -t $MASTER "bash ~/docker/kube-deploy/verify.sh master"

  for node in $NODES
  do
    {
      if [ "$node" != $MASTER ]; then
        ssh $SSH_OPTS -t $node "bash ~/docker/kube-deploy/verify.sh node"
      fi
    }
  done
}