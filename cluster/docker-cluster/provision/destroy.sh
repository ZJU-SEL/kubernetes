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

# Used to clean nodes

# Clear old bootstrap daemon, and clean bootstrap containers first
function clear_old_bootstrap {
    echo "... Bootstrap daemon already started, destroying"
    PID=`ps -eaf | grep 'unix:///var/run/docker-bootstrap.sock' | grep -v grep | awk '{print $2}'`

    if [[ "" !=  "$PID" ]]; then
        clear_bootstrap_containers
        kill -9 $PID
        echo "... Clearing bootstrap dir"
        rm -rf /var/lib/docker-bootstrap || true
        # Have to warn user some dirs left ...
        echo "Warning: Some directories can not be deleted, clear them mannually later"
    fi
}

function clear_bootstrap_containers {
  # Clean the bootstrap containers
  containers=`docker -H unix:///var/run/docker-bootstrap.sock ps -aq`
  if [[ "" !=  "$containers" ]]; then
      # Stop first
      docker -H unix:///var/run/docker-bootstrap.sock stop $containers
      # Somtimes cleaning fs fails, leaving those garbage for now
      docker -H unix:///var/run/docker-bootstrap.sock rm -vf $containers || true
  else
      echo "Nothing on bootstrap to clear"
  fi
}

# Clear the old kubelet, kube-proxy, and related 
function clear_old_components() {
  echo "... Clearing old components on the Node"

  # Stop & rm
  containers=`docker ps -a | grep -E "kube_in_docker|k8s-master" | awk '{print $1}'`
  if [[ "" !=  "$containers" ]]; then
      docker stop $containers 
      docker rm -vf $containers
  else
      echo "Nothing kube-in-docker to clear"
  fi

  # Just stop, in case users have their own hyperkube containers
  suspicious=`docker ps | grep -E "/hyperkube kubelet|/hyperkube proxy" | awk '{print $1}'`
  if [[ "" !=  "$suspicious" ]]; then
      docker stop $suspicious
      echo "... ... And stopped some users' redundant kubelet"
      sleep 3
      stubborn=`docker ps | grep -E "/hyperkube kubelet|/hyperkube proxy" | awk '{print $1}'`
      if [[ "" !=  "$stubborn" ]]; then
          echo "... ... Found some stubborn kubelet, removed by force"
          docker rm -vf $stubborn
      fi
  fi
}

# Just clear all
function clear_all() {
  clear_old_bootstrap
  clear_old_components
}

$@