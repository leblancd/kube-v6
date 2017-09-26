# kube-v6
Instructions on how to instantiate a multi-node, IPv6-only Kubernetes cluster.

# Overview
The instructions below describe how to bring up a multi-node, IPv6-only Kubernetes cluster that uses the CNI bridge and host-local IPAM plugins. Many of the changes to Kubernetes code that are required to run a cluster in IPv6-only mode either have not been merged yet, or they are not yet available in the latest official release of Kubernetes. This wiki page offers you two ways to include these changes in your Kubernetes cluster instance:

 * Using "canned", or precompiled binaries and container images for Kubernetes components
 * Compiling your own Kubernetes binaries and container images.

For instructional purposes, the steps below assume the following topology, but certainly various topologies can be supported (e.g. using baremetal nodes or different IPv6 addressing schemes) with slight variations in the steps:

![Screenshot](kubernetes_ipv6_topology.png)

# FAQs

## Why Use the CNI Bridge Plugin? Isn't it intended for single-node clusters?
The Container Networking Interface (CNI) [Release v0.6.0](https://github.com/containernetworking/plugins/releases/tag/v0.6.0) included support for IPv6 operation for the Bridge plugin and Host-local IPAM plugin. It was therefore considered a good reference plugin with which to test IPv6 changes that were being made to Kubernetes. Although the bridge plugin is intended for single-node operation (the bridge on each minion node is isolated), a multi-node cluster using the bridge plugin
can be instantiated using a couple of manual steps:

 * Provide each node with its unique pod address space (e.g. each node gets a unique /64 subnet for pod addresses).
 * Add static routes on each minion to other minions' pod subnets using the target minion's node address as a next hop.

## Why is IPv6-only targeted here instead of dual-stack?
The first target for IPv6 on Kubernetes will be support for IPv6-only clusters. The main reason for this is that Kubernetes currently only supports/recognizes a single IP address per pod (i.e. no multiple-IP support). So even though the CNI bridge plugin supports dual-stack (as well as support for multiple IPv6 addresses) on the pods, Kubernetes will currently only be aware of one IP address per pod.

## Why is the purpose of NAT64 and DNS64 in the topology shown above?



