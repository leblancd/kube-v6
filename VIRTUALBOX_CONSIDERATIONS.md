## Special Considerations for Using VirtualBox VMs as Kubernetes Nodes in an IPv6-Only Cluster
VirtualBox typically sets up a VM's eth0 interface as an IPv4 NAT port to the external world, and configures the interface using DHCP. The presence of an IPv4 address (typically 10.0.2.15) on a VM's eth0 in an otherwise IPv6-only Kubernetes node won't interfere with IPv6-only operation of the cluster. However, the DHCP configuration also includes an IPv4 default route and a DNS server (configured in /etc/resolv.conf). The IPv4 default route can interfere with control channel communication in an IPv6-only cluster because Kubernetes favors any IPv4 address that is on a interface that is associated with an IPv4 default route over any IPv6 addresses when choosing a node IP for that node. The node IP is what is used for inter-node control plane communication, so this needs to be an IPv6 address for IPv6-only operation.

So if you are using VirtualBox VMs as Kubernetes nodes, you should delete the default IPv4 route and make sure that the nameserver in /etc/resolv.conf points to your DNS64 server, e.g.:
```
ip route delete default via 10.0.2.2 dev eth0
sed -i 's/nameserver.*/nameserver fd00::64/' /etc/resolv.conf
```
DHCP reconfiguration happens periodically (IP lease expiry) on VirtualBox, so you either have to do this repeatedly, or you can take steps to disable DHCP reconfiguration on each VM's eth0.
