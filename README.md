# kube-v6
Instructions on how to instantiate a multi-node, IPv6-only Kubernetes cluster using the CNI bridge plugin and Host-local IPAM plugin for developing or exploring IPv6 on Kubernetes.

# Overview
So you'd like to take Kubernetes IPv6 for a test drive, or perhaps do some Kubernetes IPv6 development? The instructions below describe how to bring up a multi-node, IPv6-only Kubernetes cluster that uses the CNI bridge and host-local IPAM plugins, using kubeadm to stand up the cluster.

There have been many recent changes that have been added or proposed to Kubernetes for supporting IPv6 are either not merged yet, or they were merged after the latest official release of Kubernetesi (1.8.0). In the meantime, we need a way of exercising these yet "in-flight" IPv6 changes on a Kubernetes cluster. This wiki offers you two ways to include these changes in a Kubernetes cluster instance:

 * Using "canned", or precompiled binaries and container images for Kubernetes components
 * Compiling your own Kubernetes binaries and container images.

For instructional purposes, the steps below assume the topology shown in the following diagram, but certainly various topologies can be supported (e.g. using baremetal nodes or different IPv6 addressing schemes) with slight variations in the steps:

![Screenshot](kubernetes_ipv6_topology.png)

# FAQs

#### Why Use the CNI Bridge Plugin? Isn't it intended for single-node clusters?
The Container Networking Interface (CNI) [Release v0.6.0](https://github.com/containernetworking/plugins/releases/tag/v0.6.0) included support for IPv6 operation for the Bridge plugin and Host-local IPAM plugin. It was therefore considered a good reference plugin with which to test IPv6 changes that were being made to Kubernetes. Although the bridge plugin is intended for single-node operation (the bridge on each minion node is isolated), a multi-node cluster using the bridge plugin
can be instantiated using a couple of manual steps:

 * Provide each node with its unique pod address space (e.g. each node gets a unique /64 subnet for pod addresses).
 * Add static routes on each minion to other minions' pod subnets using the target minion's node address as a next hop.

#### Why run in IPv6-only mode rather than running in dual-stack mode?
The first phase of implementation for IPv6 on Kubernetes will target support for IPv6-only clusters. The main reason for this is that Kubernetes currently only supports/recognizes a single IP address per pod (i.e. no multiple-IP support). So even though the CNI bridge plugin supports dual-stack (as well as support for multiple IPv6 addresses on each pod interface) operation on the pods, Kubernetes will currently only be aware of one IP address per pod.

#### Why is the purpose of NAT64 and DNS64 in the IPv6 Kubernetes cluster topology diagram?
There are many servers that exist outside of our Kubernetes cluster that still do not support IPv6 exchanges. One big example are the docker image registries that we typically use to download Kubernetes service container images and other docker images that are run inside user pods. In order to connect with these services from an IPv6 platform, NAT64 translation coupled with DNS64 are required to translate IPv6 packets from within the cluster to IPv4 packets outside the cluster,
and vice versa.

#### Should I use global (GUA) or private (ULA) IPv6 addresses on the Kubernetes nodes?
You can use GUA, ULA, or a combination of both for addresses on your Kubernetes nodes. Using GUA addresses (that are routed to your cluster) gives you the flexibility of connecting directly to Kubernetes services from outside the cluster (e.g. by defining Kubernetes services using nodePorts or externalIPs). On the other hand, the ULA addresses that you choose can be convenient and predictable, and that can greatly simplify the addition of static routes between nodes and pods.

# Preparation Before Running kubeadm

## Set up node IP addresses
For the example topology show above, the eth2 addresses would be configured via IPv6 SLAAC, and the eth1 addresses would be statically configured as follows:
```
       Node        IP Address
   -------------   ----------
   NAT64/DNS64     fd00::64
   Kube Master     fd00::100
   Kube Minion 1   fd00::101
   Kube Minion 1   fd00::102
```

## (For convenience) Configure /etc/hosts on each node with the new addresses
Here's an example /etc/hosts file:
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
fd00::64 kube-nat64-dns64
fd00::100 kube-master
fd00::101 kube-minion-1
fd00::102 kube-minion-2
```

## Add static routes between nodes, pods, and Kubernetes services
In the list of static routes below, the subnets/addresses used are as follows:
```
   Subnet/Address          Description
   --------------    ---------------------------
   64:ff9b::/96      Prefix used inside the cluster for packets requiring NAT64 translation
   fd00::101         Kube Minion 1
   fd00::102         Kube Minion 2
   fd00:101::/64     Kube Minion 1's pod subnet
   fd00:102::/64     Kube Minion 2's pod subnet
   fd00:1234::/64    Cluster's Service subnet
```

#### Static Routes on NAT64/DNS64 Server
Example: CentOS 7, entries in /etc/sysconfig/network-scripts/route6-eth1:
```
fd00:101::/64 via fd00::101 metric 1024
fd00:102::/64 via fd00::102 metric 1024
```

#### Static Routes on Kube Master
Example: CentOS 7, entries in /etc/sysconfig/network-scripts/route6-eth1:
```
64:ff9b::/96 via fd00::64 metric 1024
fd00:101::/64 via fd00::101 metric 1024
fd00:102::/64 via fd00::102 metric 1024
```

#### Static Routes on Kube Minion 1
Example: CentOS 7, entries in /etc/sysconfig/network-scripts/route6-eth1:
```
64:ff9b::/64 via fd00::64 metric 1024
fd00:102::/64 via fd00::102 metric 1024
fd00:1234::/64 via fd00::100 metric 1024
```

#### Static Routes on Kube Minion 2
Example: CentOS 7, entries in /etc/sysconfig/network-scripts/route6-eth1:
```
64:ff9b::/64 via fd00::64 metric 1024
fd00:101::/64 via fd00::101 metric 1024
fd00:1234::/64 via fd00::100 metric 1024
```

## Set sysctl settings for forwarding and using iptables/ip6tables
For example, on CentOS 7 hosts, add the following to /etc/sysctl.conf:
```
sudo -i
cat << EOT >> /etc/sysctl.conf
net.ipv6.conf.all.forwarding=1
net.bridge.bridge-nf-call-ip6tables=1
EOT
sudo sysctl -p /etc/sysctl.conf
exit
```

## Configure and install NAT64 and DNS64 on the NAT64/DNS64 server
For installing on a Ubuntu host, refer to the [NAT64-DNS64-UBUNTU-INSTALL.md](NAT64-DNS64-UBUNTU-INSTALL.md) file.

For installing on a CentOS 7 host, refer to the [NAT64-DNS64-CENTOS-INSTALL.md](NAT64-DNS64-CENTOS-INSTALL.md) file.

