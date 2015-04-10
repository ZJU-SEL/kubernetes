#!/bin/bash

# Copyright 2015 Google Inc. All rights reserved.
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

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/../..
source "${KUBE_ROOT}/cluster/ubuntu/${KUBE_CONFIG_FILE-"config-default.sh"}"

function detect-master () {
  KUBE_MASTER_IP=$MASTER_IP
  echo "KUBE_MASTER_IP: ${KUBE_MASTER_IP}" 1>&2
}

# Get minion IP addresses and store in KUBE_MINION_IP_ADDRESSES[]
function detect-minions {
  echo "Minions already detected" 1>&2
  KUBE_MINION_IP_ADDRESSES=("${MINION_IPS[@]}")
}

# Verify prereqs on host machine.
# It includes ensuring the binaries is downloaded and ssh pub key is transfered to all the k8s node.
function verify-prereqs {

}

# Run command over ssh
function kube-ssh {
  local host="$1"
  shift
  ssh ${SSH_OPTS-} "root@${host}" "$@" 2> /dev/null
}

# Copy file over ssh
function kube-scp {
  local host="$1"
  local src="$2"
  local dst="$3"
  scp ${SSH_OPTS-} "${src}" "root@${host}:${dst}"
}

function verify-cluster {
  echo "Each machine instance has been created/updated."
  echo "  Now waiting for the Salt provisioning process to complete on each machine."
  echo "  This can take some time based on your network, disk, and cpu speed."
  echo "  It is possible for an error to occur during Salt provision of cluster and this could loop forever."

  # verify master has all required daemons
  echo "Validating master"
  local machine="master"
  local -a required_daemon=("kube-apiserver" "kube-controller-manager" "kube-scheduler")
  local validated="1"
  until [[ "$validated" == "0" ]]; do
    validated="0"
    local daemon
    for daemon in "${required_daemon[@]}"; do
        ssh "$machine" -c "which '${daemon}'" >/dev/null 2>&1 || {
        printf "."
        validated="1"
        sleep 2
      }
    done
  done

  # verify each minion has all required daemons
  local i
  for (( i=0; i<${#MINION_NAMES[@]}; i++)); do
    echo "Validating ${VAGRANT_MINION_NAMES[$i]}"
    local machine=${VAGRANT_MINION_NAMES[$i]}
    local -a required_daemon=("salt-minion" "kubelet" "docker")
    local validated="1"
    until [[ "$validated" == "0" ]]; do
      validated="0"
      local daemon
      for daemon in "${required_daemon[@]}"; do
        vagrant ssh "$machine" -c "which $daemon" >/dev/null 2>&1 || {
          printf "."
          validated="1"
          sleep 2
        }
      done
    done
  done

  echo
  echo "Waiting for each minion to be registered with cloud provider"
  for (( i=0; i<${#MINION_IPS[@]}; i++)); do
    local machine="${MINION_IPS[$i]}"
    local count="0"
    until [[ "$count" == "1" ]]; do
      local minions
      minions=$("${KUBE_ROOT}/cluster/kubectl.sh" get minions -o template -t '{{range.items}}{{.id}}:{{end}}')
      count=$(echo $minions | grep -c "${MINION_IPS[i]}") || {
        printf "."
        sleep 2
        count="0"
      }
    done
  done

  # By this time, all kube api calls should work, so no need to loop and retry.
  echo "Validating we can run kubectl commands."
  vagrant ssh master --command "kubectl get pods" || {
    echo "WARNING: kubectl to localhost failed.  This could mean localhost is not bound to an IP"
  }
  
  (
    echo
    echo "Kubernetes cluster is running.  The master is running at:"
    echo
    echo "  https://${MASTER_IP}"
    echo
    echo "The user name and password to use is located in ~/.kubernetes_vagrant_auth."
    echo
    )
}

# Create the master-node and minion node configuration file
# and put them in default_scripts, init_conf, init_scripts directory
function create-provision-scripts(){
  create-etcd-scripts
  create-kube-apiserver-scripts
  create-kube-controller-manager-scripts
  create-kube-scheduler-scripts
  create-kube-proxy-scripts

  for i in $MINION_IPS; do
    create-kubelet-scripts ${i}
  done
}

function create-etcd-scripts(){

}

function create-kube-apiserver-scripts(){

}

function create-kube-controller-manager-scripts(){

}

function create-kube-scheduler-scripts(){

}

function create-kubelet-scripts(){

}

function create-kube-proxy-scripts(){

}

function create-flanneld-script(){

}

function create-kube-scheduler-scripts()
# Instantiate a kubernetes cluster on ubuntu
function kube-up {
  create-provision-scripts

  verify-cluster
}

# Delete a kubernetes cluster
function kube-down {
}

# Update a kubernetes cluster with latest source
function kube-push {
  create-provision-scripts
}

# Execute prior to running tests to initialize required structure
function test-setup {
}

# Execute after running tests to perform any required clean-up
function test-teardown {
  
}

# Restart the kube-proxy on a node ($1)
function restart-kube-proxy {
  ssh-to-node "$1" "service kube-proxy restart"
}

# Restart the apiserver($1)
function restart-apiserver {
  ssh-to-node "$1" "service kube-apiserver restart"
}

# Restart the etcd on a node ($1)
function restart-etcd {
  ssh-to-node "$1" "service etcd restart"
}

# Restart the kubelet on a node ($1)
function restart-kubelet {
  ssh-to-node "$1" "service kubelet restart"
}

# Restart the kube-controller-manager on a node ($1)
function restart-kube-controller-manager {
  ssh-to-node "$1" "service kube-controller-manager restart"
}

# Restart the kube-scheduler on a node ($1)
function restart-kube-scheduler {
  ssh-to-node "$1" "service kube-scheduler restart"
}

# Restart the flannel on a node ($1)
function restart-flannel {
  ssh-to-node "$1" "service flannel restart"
}

# Perform preparations required to run e2e tests
function prepare-e2e() {
  echo "Ubuntu doesn't need special preparations for e2e tests" 1>&2
}
