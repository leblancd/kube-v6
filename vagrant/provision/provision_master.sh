#!/bin/bash
#
# Author: Pierre Pfister <ppfister@cisco.com>
#
# Largely inspired from contiv-VPP vagrant file.
#

set -ex
echo Args passed: [[ $@ ]]

k8s_service_cidr=$K8S_SERVICE_CIDR
base_ip6=$K8S_IP6_PREFIX

vm_conf=""
vm_name=""
vm_id=""
vm_hostname=""
function get_vm_conf {
	vm_name="$1"
	vm_conf=$(echo "$VMS_CONF" | awk "BEGIN{ RS=\",\"; FS=\":\"; ORS=\" \" } \$1==\"$vm_name\" { print \$1, \$2, \$3 }")
	vm_id=$(echo "$vm_conf" | awk '{ print $3 }')
	vm_hostname=$(echo "$vm_conf" | awk '{ print $2 }')
}

self_name="$1"
get_vm_conf "$self_name"
self_id="$vm_id"
self_hostname="$vm_hostname"

#echo "Installing crictl"
#go get github.com/kubernetes-incubator/cri-tools/cmd/crictl

echo "Exporting Kube Master IP and Kubeadm Token..."
mkdir -p /vagrant/config/
echo "export KUBEADM_TOKEN=$(kubeadm token generate)" >> /vagrant/config/init

. /vagrant/config/init

if [ ! -f "/vagrant/config/kubadm-init-done" ]; then
  echo "Initiate kubeadm"
  sudo kubeadm init --apiserver-advertise-address=${base_ip6}0::$self_id \
    --service-cidr=$k8s_service_cidr:/110 --node-name=k86-master --token=$KUBEADM_TOKEN | tee /vagrant/config/cert
  touch "/vagrant/config/kubadm-init-done"
fi

echo "kubectl config for user $(id -u)"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Configuring CNI bridge"
sudo rm /etc/cni/net.d/* || true
sudo mkdir -p /etc/cni/net.d/
sudo tee /etc/cni/net.d/10-bridge-v6.conf << EOF
{
  "cniVersion": "0.3.0",
  "name": "mynet",
  "type": "bridge",
  "bridge": "cbr0",
  "isDefaultGateway": true,
  "ipMasq": true,
  "hairpinMode": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "${base_ip6}$self_id::/80",
          "gateway": "${base_ip6}$self_id::1"
        }
      ]
    ]
  }
}
EOF