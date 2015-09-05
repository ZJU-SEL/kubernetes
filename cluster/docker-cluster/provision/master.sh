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

# A scripts to install k8s worker node.
# Author @wizard_cxy @reouser

set -e

source ~/docker-cluster/provision/common.sh

# Start k8s components in containers
start_k8s(){
    
    # start ectd
    docker -H unix:///var/run/docker-bootstrap.sock run \
    --restart=always --net=host -d \
    gcr.io/google_containers/etcd:$ETCD_VERSION \
    /usr/local/bin/etcd --addr=127.0.0.1:4001 \
    --bind-addr=0.0.0.0:4001 \
    --data-dir=/var/etcd/data

    sleep 3

    start-network $MASTER_IP

    clear_old_components

    sed -i "s/VERSION/v${K8S_VERSION}/g" ~/docker-cluster/kube-config/master-multi.json

    # Start kubelet & proxy, then start master components as pods
    docker run --net=host --privileged --restart=always -d \
    -v /:/rootfs:ro \
    -v /sys:/sys:ro \
    -v /dev:/dev \
    -v /var/lib/docker/:/var/lib/docker:ro \
    -v /var/lib/kubelet/:/var/lib/kubelet:rw \
    -v /var/run:/var/run:rw \
    -v ~/docker-cluster/kube-config/master-multi.json:/etc/kubernetes/manifests-multi/master.json \
    --net=host \
    --privileged=true \
    --name=kube_in_docker_kubelet_$RANDOM \
    gcr.io/google_containers/hyperkube:v$K8S_VERSION \
    /hyperkube kubelet --containerized \
    --api-servers=http://localhost:8080 \
    --config=/etc/kubernetes/manifests-multi/master.json \
    $KUBELET_OPTS

    docker run -d --net=host --privileged --restart=always \
    --name kube_in_docker_proxy_$RANDOM \
    gcr.io/google_containers/hyperkube:v$K8S_VERSION \
    /hyperkube proxy --master=http://127.0.0.1:8080 --v=2 
}
echo "... Detecting your OS distro"
detect_lsb
echo "... Starting bootstrap daemon"
bootstrap_daemon
echo "... Starting k8s"
start_k8s
echo "Master done!"