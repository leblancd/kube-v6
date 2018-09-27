#!/bin/bash
#
# Author: Pierre Pfister <ppfister@cisco.com>
#
# Largely inspired from contiv-VPP vagrant file.
#

set -ex
echo Args passed: [[ $@ ]]

http_proxy=$HTTP_PROXY
https_proxy=$HTTPS_PROXY
node_os=$K8S_NODE_OS
base_ip6=$K8S_IP6_PREFIX
nat64_prefix=$K8S_NAT64_PREFIX
num_workers=$K8S_WORKERS
provider=$VAGRANT_DEFAULT_PROVIDER
k8s_version=$KUBERNETES_VERSION
nat64_vm_id=$K8S_NAT64_ID
master_vm_id=$K8S_MASTER_ID
worker_vm_id_first=$K8S_FIRST_WORKER_ID
docker_version=$DOCKER_VERSION
service_cidr=$K8S_SERVICE_CIDR

vm_names=$(echo $VMS_CONF | awk 'BEGIN{ RS=","; FS=":"; ORS=" " } { print $1 }')

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

cat | sudo tee /etc/profile.d/envvar.sh <<EOF
export http_proxy="${http_proxy}"
export https_proxy="${https_proxy}"
export HTTP_PROXY="${http_proxy}"
export HTTPS_PROXY="${https_proxy}"
EOF

echo "Configuring IPv6 network in enp0s8"
sudo tee /etc/network/interfaces.d/enp0s8 << EOF
# Generated during provisioning in k86 provision_every_node
iface enp0s8 inet6 static
  address ${base_ip6}0::$self_id
  netmask 80
	dns-nameservers fd00:f00d::64
EOF

sudo tee /etc/resolvconf/interface-order << EOF
lo
enp0s8.inet6
enp0s3.dhclient
EOF

if [ "$self_name" != "nat64" ]; then
	get_vm_conf "nat64"
	sudo tee --append /etc/network/interfaces.d/enp0s8 << EOF
  # Route to ze interwebz
  post-up /sbin/ip -6 route add ${nat64_prefix}/96 via ${base_ip6}0::$vm_id dev enp0s8
EOF
fi

if [ "$self_name" != "master" ]; then
	get_vm_conf "master"
	sudo tee --append /etc/network/interfaces.d/enp0s8 << EOF
  # The k8s service CIDR going to master.
  post-up /sbin/ip -6 route add $service_cidr:/110 via ${base_ip6}0::$vm_id dev enp0s8
EOF
else
  get_vm_conf "nat64"
	sudo tee --append /etc/network/interfaces.d/enp0s8 << EOF
  # The k8s service CIDR going to nat64 (only for master).
  post-up /sbin/ip -6 route add $service_cidr:/110 via ${base_ip6}0::$vm_id dev enp0s8
EOF
fi

sudo tee /etc/hosts << EOF
::1     $(hostname) localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

echo "Configuring IPv6 node routes"
for vm in $vm_names; do
	get_vm_conf $vm
  
	if [ "$vm_id" != "$self_id" ]; then
    sudo tee --append /etc/network/interfaces.d/enp0s8 << EOF
  post-up /sbin/ip -6 route add ${base_ip6}$vm_id::/80 via ${base_ip6}0::$vm_id dev enp0s8
EOF
  fi
	
	sudo tee --append /etc/hosts << EOF
${base_ip6}0::$vm_id $vm_hostname
EOF
	
done

echo "Setting up enp0s8"
sudo ifdown enp0s8 || true
sudo ifup enp0s8

source /etc/profile.d/envvar.sh
echo "Updating apt lists..."
sudo -E apt-get update

echo "Installing dependency packages..."
sudo -E apt-get install -y apt-transport-https ca-certificates \
                   curl software-properties-common htop

echo "Adding Kubernetes & Docker repos..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo -E apt-key add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo -E apt-key add -
sudo -E add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo -E add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"

echo "Updating apt lists..."
sudo -E apt-get update -q

echo "Installing Kubernetes Components..."
sudo -E apt-get install -qy --allow-downgrades kubelet=$k8s_version-00  kubectl=$k8s_version-00 kubeadm=$k8s_version-00

echo "Installing Docker-CE..."
sudo -E apt-get install -y --allow-downgrades docker-ce=$docker_version

# Setup the proxy if needed
if [ "${http_proxy}" != "" ] || [ "${https_proxy}" != "" ]; then
	sudo mkdir -p /etc/systemd/system/docker.service.d
	echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
	if [ "${http_proxy}" != "" ]; then
		echo "Environment=\"HTTP_PROXY=${http_proxy}\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
	fi
	if [ "${https_proxy}" != "" ]; then
		echo "Environment=\"HTTPS_PROXY=${https_proxy}\"" | sudo tee --append /etc/systemd/system/docker.service.d/http-proxy.conf
	fi
	sudo systemctl daemon-reload
fi

sudo systemctl stop docker
sudo modprobe overlay

sudo tee /etc/docker/daemon.json << EOF
{
  "storage-driver": "overlay2",
  "ipv6": true,
  "fixed-cidr-v6" : "fd00:dead::/110"
}
EOF

sudo rm -rf /var/lib/docker/*
sudo systemctl start docker

#Disable swap
sudo swapoff -a
sudo sed -e '/swap/ s/^#*/#/' -i /etc/fstab