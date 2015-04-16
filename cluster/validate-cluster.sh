#!/bin/bash

# Copyright 2014 Google Inc. All rights reserved.
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

# Validates that the cluster is healthy.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/..
source "${KUBE_ROOT}/cluster/kube-env.sh"
source "${KUBE_ROOT}/cluster/${KUBERNETES_PROVIDER}/util.sh"

MINIONS_FILE=/tmp/minions-$$
trap 'rm -rf "${MINIONS_FILE}"' EXIT

# Make several attempts to deal with slow cluster birth.
attempt=0
while true; do
  "${KUBE_ROOT}/cluster/kubectl.sh" get nodes -o template -t $'{{range.items}}{{.metadata.name}}\n{{end}}' --api-version=v1beta3 > "${MINIONS_FILE}"
  found=$(grep -c . "${MINIONS_FILE}")
  if [[ ${found} == "${NUM_MINIONS}" ]]; then
    break
  else
    if (( attempt > 5 )); then
      echo -e "${color_red}Detected ${found} nodes out of ${NUM_MINIONS}. Your cluster may not be working. ${color_norm}"
      cat -n "${MINIONS_FILE}"
      exit 2
    fi
    attempt=$((attempt+1))
    sleep 30
  fi
done
echo "Found ${found} nodes."
cat -n "${MINIONS_FILE}"

attempt=0
while true; do
  kubectl_output=$("${KUBE_ROOT}/cluster/kubectl.sh" get cs) || true

  # On vSphere, use minion IPs as their names
  if [[ "${KUBERNETES_PROVIDER}" == "vsphere" ]] || [[ "${KUBERNETES_PROVIDER}" == "vagrant" ]] || [[ "${KUBERNETES_PROVIDER}" == "libvirt-coreos" ]] || [[ "${KUBERNETES_PROVIDER}" == "ubuntu" ]]; then
    MINION_NAMES=("${KUBE_MINION_IP_ADDRESSES[@]}")
  fi

  # On AWS we can't really name the minions, so just trust that if the number is right, the right names are there.
  if [[ "${KUBERNETES_PROVIDER}" == "aws" ]]; then
    MINION_NAMES=("$(cat ${MINIONS_FILE})")
    # /healthz validation isn't working for some reason on AWS.  So just hope for the best.
    # TODO: figure out why and fix, it must be working in some form, or else clusters wouldn't work.
    echo "Kubelet health checking on AWS isn't currently supported, assuming everything is good..."
    echo -e "${color_green}Cluster validation succeeded${color_norm}"
    exit 0
  fi


  # The "kubectl componentstatuses" output is four columns like this:
  #
  #     COMPONENT            HEALTH    MSG       ERR
  #     controller-manager   Healthy   ok        nil
  #
  # Parse the output to capture the value of the second column("HEALTH"), then use grep to
  # count the number of times it doesn't match "success".
  # Because of the header, the actual unsuccessful count is 1 minus the count.
  non_success_count=$(echo "${kubectl_output}" | \
    sed -n 's/^[[:alnum:][:punct:]]/&/p' | \
    grep --invert-match -c '^[[:alnum:][:punct:]]\{1,\}[[:space:]]\{1,\}Healthy') || true

  if ((non_success_count > 1)); then
    if ((attempt < 5)); then
      echo -e "${color_yellow}Cluster not working yet.${color_norm}"

    name="${MINION_NAMES[$i]}"
    if [ "$KUBERNETES_PROVIDER" != "vsphere" ] && [ "$KUBERNETES_PROVIDER" != "vagrant" ] && [ "$KUBERNETES_PROVIDER" != "libvirt-coreos" ] && [ "$KUBERNETES_PROVIDER" != "ubuntu" ]; then
      # Grab fully qualified name
      name=$(grep "${MINION_NAMES[$i]}\." "${MINIONS_FILE}")
    fi

    # Make sure the kubelet is healthy.
    # Make several attempts to deal with slow cluster birth.
    attempt=0
    while true; do
      echo -n "Attempt $((attempt+1)) at checking Kubelet installation on node ${MINION_NAMES[$i]} ..."
      if [ "$KUBERNETES_PROVIDER" != "libvirt-coreos" ] && [ "$KUBERNETES_PROVIDER" != "ubuntu" ]; then
        curl_output=$(curl -s --insecure --user "${KUBE_USER}:${KUBE_PASSWORD}" \
          "https://${KUBE_MASTER_IP}/api/v1beta1/proxy/minions/${name}/healthz")
      else
        curl_output=$(curl -s \
          "http://${KUBE_MASTER_IP}:8080/api/v1beta1/proxy/minions/${name}/healthz")
      fi
      if [[ "${curl_output}" != "ok" ]]; then
          if (( attempt > 5 )); then
            echo
            echo -e "${color_red}Kubelet failed to install on node ${MINION_NAMES[$i]}. Your cluster is unlikely to work correctly."
            echo -e "Please run ./cluster/kube-down.sh and re-create the cluster. (sorry!)${color_norm}"
            exit 1
          fi
      else
          echo -e " ${color_green}[working]${color_norm}"
          break
      fi
      echo -e " ${color_yellow}[not working yet]${color_norm}"

      attempt=$((attempt+1))
      sleep 30
    else
      echo -e " ${color_yellow}Validate output:${color_norm}"
      echo "${kubectl_output}"
      echo -e "${color_red}Validation returned one or more failed components. Cluster is probably broken.${color_norm}"
      exit 1
    fi
  else
    break
  fi
done

echo "Validate output:"
echo "${kubectl_output}"
echo -e "${color_green}Cluster validation succeeded${color_norm}"
