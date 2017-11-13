# Configuring NAT64/DNS64 On a Ubuntu Server for Linking IPv6-only Clusters with IPv4-Only External Servers

## Background

We need to be able to test IPv6-only Kubernetes cluster configurations. However, there are many external services (e.g. DockerHub) that only work with IPv4. In order to interoperate between our IPv6-only cluster and these external IPv4 services, we configure a node in the lab to run as a NAT64 and DNS64 server. The NAT64 server operates in dual-stack mode, and it serves as a translator between the internal IPv6-only network and the external IPv4 Internet. It does this by translating any destination IPv6 addresses in egress packets that happen to have a special 64:ffd9::/64 prefix into IPv4 addresses, and it does the reverse translation in the opposite direction.

The DNS64 server acts as the DNS server for kubernetes master and minion nodes. It forwards requests to the original DNS server. For any DNS answers that are returned do not contain AAAA records with IPv6 addresses (i.e.for IPv4-only services), the DNS64 server will add AAAA records that it generates by prefixing the IPv4 addresses in A records with the special, NAT64 prefix of 64:ffd9::/64.

For NAT64 service, we use Jool.  
For DNS64 service, we use bind9.

![Screenshot](kubernetes_ipv6_topology.png)

## Installing Jool on the NAT64/DNS64 Node
References:  
[Introduction to IPv4/IPv6 Translation](https://www.jool.mx/en/intro-xlat.html)  
[Jool Documentation](https://www.jool.mx/en/documentation.html)  

#### Install build-essential, linux-headers, and dkms:
On the NAT64/DNSY64 node:
```
sudo apt-get install -y build-essential linux-headers-$(uname -r) dkms
Install Kernel Modules:
Reference: https://www.jool.mx/en/install-mod.html
sudo -i
git clone https://github.com/NICMx/Jool.git
dkms install Jool
exit
```

#### Install User Modules:
Reference: https://www.jool.mx/en/install-usr.html  
On the NAT64/DNS64 node:
```
sudo -i
apt-get install -y gcc make pkg-config libnl-genl-3-dev autoconf
cd Jool/usr
./autogen.sh
./configure
make
make install
exit
```

## Configuring Jool on the NAT64/DNS64 Node
References:  
[Stateful NAT64 Run](https://www.jool.mx/en/run-nat64.html)  
[Starting Jool](https://www.jool.mx/en/run-nat64.html#jool)  
[NAT64 Jool's Kernal Module Arguments](https://www.jool.mx/en/modprobe-nat64.html)  
[pool4: IPv4 Transport Address Pool](https://www.jool.mx/en/modprobe-nat64.html#pool4)  

#### If 'jool' does not show up in $PATH, add an alias for jool:

On the NAT64/DNS64 node:
```
echo "alias jool='/usr/local/bin/jool'" >> /root/.bash_aliases
source ~/.bash_aliases
```

#### Load the Jool kernel module via modprobe:
Reference: https://www.jool.mx/en/run-nat64.html#jool

On the NAT64/DNS64 node (leaving NAT64 translation disabled while configuring Jool):

```
/sbin/modprobe jool pool6=64:ff9b::/96 disabled
```

#### Set the pool4 range to use 10.0.2.15 7000-8000:
On the NAT64/DNS64 node:
```
jool -4 --add 10.0.2.15 7000-8000      < = = = NOTE: Don't use 5000-6000 on VirtualBox setup
```

#### Check pool4 and pool6:
On the NAT64/DNS64 node:
```
[root@kube-master usr]# jool -4 -d
0    TCP    10.0.2.15    7000-8000
0    UDP    10.0.2.15    7000-8000
0    ICMP    10.0.2.15    7000-8000
  (Fetched 3 samples.)
[root@kube-master usr]# jool -6 -d
64:ff9b::/96
  (Fetched 1 entries.)
[root@kube-master usr]#
```

#### Enable jool translation:
On the NAT64/DNS64 node:
```
jool --enable
```

#### Check jool status:
On the NAT64/DNS64 node:
```
jool -d
```

## Configuring and Verifying NAT64 Operation on Kubernetes Master and Minions

#### Enable IPv6 Forwarding
On Kubernetes master, minions, and VirtualBox host, make sure that ipv6.conf.all.forwarding is set to 1:
```
sysctl net.ipv6.conf.all.forwarding
```
 
#### Confirm that the NAT64/DNS64 node is reachable
On the Kubernetes master and each Kubernetes minion:
```
ping6 fd00::64
```

#### Add a static route for the NAT64 subnet 64:ff9b::/64 via eth1 to the NAT64 server
On the Kubernetes master and each minion, add the following to /etc/network/interfaces.d/[interface].cfg, if not already present.
#### NOTE: This example assumes that the NAT64/DNS64 node is reachable from the kubernetes master and minion nodes via the IPv6 address fd00::64

```
up ip -6 route add 64:ff9b::/96 via fd00::64 dev eth1
```

#### Do a ping test using a synthesized NAT64 address
From the Kubernetes master and each Kubernetes minion:
```
V4_ADDR=$(host google.com | awk '/has address/{print $4}')
ping6 64:ff9b::$V4_ADDR
```

For example:

```
[root@kube-minion-1 ~]# V4_ADDR=$(host google.com | awk '/has address/{print $4}')
[root@kube-minion-1 ~]# ping6 64:ff9b::$V4_ADDR
PING 64:ff9b::172.217.13.238(64:ff9b::acd9:dee) 56 data bytes
64 bytes from 64:ff9b::acd9:dee: icmp_seq=1 ttl=61 time=32.5 ms
64 bytes from 64:ff9b::acd9:dee: icmp_seq=2 ttl=61 time=33.6 ms
64 bytes from 64:ff9b::acd9:dee: icmp_seq=3 ttl=61 time=36.6 ms
64 bytes from 64:ff9b::acd9:dee: icmp_seq=4 ttl=61 time=34.0 ms
64 bytes from 64:ff9b::acd9:dee: icmp_seq=5 ttl=61 time=43.7 ms
. . .
```

## Installing bind9 (for DNS64 service) on the NAT64/DNS64 Node
Reference:  
[DNS64 Tutorial](https://www.jool.mx/en/dns64.html)

On the NAT64/DNS64 node, install bind9:
```
sudo -i
apt-get install -y bind9
```

## Configuring bind9 on the NAT64/DNS64 Node
On the NAT64/DNS64 node, edit the named configuration file for bind9:
```
cd /etc/bind
vi named.conf.options
```

In the /etc/bind/named.conf.options file (on the NAT64/DNS64 node), add the following line to enable recursive requests (e.g. from the kube-dns server):
```
    allow-query { any; };
```


In the /etc/bind/named.conf.options file (on the NAT64/DNS64 node), add a forwarder entry for the DNS server that you had been using. DNS64 will forward DNS requests to this server to determine e.g. what IPv4 address should be included in synthesized IPv6 addresses:
```
    forwarders {
        8.8.8.8;
    };
```

In the /etc/bind/named.conf.options file (on the NAT64/DNS64 node), comment out the "dnssec-validation auto;" line:
```
    //dnssec-validation auto;
```

In the /etc/bind/named.conf.options file (on the NAT64/DNS64 node), comment out any "listen-on-v6" option, and add a "listen-on-v6 { any; };" if necessary:
```
    // listen-on port 53 { 127.0.0.1; };
    // listen-on-v6 port 53 { ::1; };
    listen-on-v6 { any; };
```

In the /etc/bind/named.conf.options file (on the NAT64/DNS64 node), add the following option for a DNS64 prefix. Note that the exclude statement will force the DNS64 server to always synthesize IPv6 addresses, even for external dual-stack hosts/servers that have "native" (non-synthesized) IPv6 addresses:
```
    # Add prefix for Jool's `pool6`
    dns64 64:ff9b::/96 {
        exclude { any; };
    } ;
```

## Restart bind9 service on the NAT64/DNS64 node:

```
service bind9 restart
systemctl status bind9
```

## On the Kubernetes master and minions, set the host's DNS64 as the DNS server
On the Kubernetes master node and each minion node:
```
sed -i "s/nameserver.*/nameserver fd00::64/" /etc/resolv.conf
```
NOTE: On VirtualBox setups, where DHCP is used by default on the eth0 interface, this setting in /etc/resolv.conf may get overwritten periodically when the IP address lease expires. It's recommended to disable DHCP on eth0 in VirtualBox setups. On Ubuntu nodes, DHCP can be disabled by setting a static IPv4 address for eth0 in /etc/network/interfaces, e.g.:
```
auto eth0
iface eth0 inet static
	address 10.0.2.15
	netmask 255.255.255.0
	network 10.0.2.0
	broadcast 10.0.2.255
```

## Testing / Verifying NAT64 with DNS64

#### Debugging DNS64 operation while testing:
On the NAT64/DNS64 node, enable real-time journaling output from bind9:

```
sudo journalctl -u bind9 -f
```

#### On kube master and minions, test DNS64 lookup with dig

[root@kube-minion-2 ~]# dig hub.docker.com AAAA | grep "AAAA 64"
us-east-1-elbdefau-1nlhaqqbnj2z8-140214243.us-east-1.elb.amazonaws.com.    60 IN AAAA 64:ff9b::22c0:3fec
us-east-1-elbdefau-1nlhaqqbnj2z8-140214243.us-east-1.elb.amazonaws.com.    60 IN AAAA 64:ff9b::3406:740f
us-east-1-elbdefau-1nlhaqqbnj2z8-140214243.us-east-1.elb.amazonaws.com.    60 IN AAAA 64:ff9b::36ae:b1f4
[root@kube-minion-2 ~]#

#### On kube master and minions, test NAT64/DNS64 with curl
```
[root@kube-minion-2 ~]# curl -6 -v hub.docker.com
* About to connect() to hub.docker.com port 80 (#0)
*   Trying 64:ff9b::36ae:b1f4...
* Connected to hub.docker.com (64:ff9b::36ae:b1f4) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.29.0
> Host: hub.docker.com
> Accept: */*
>
< HTTP/1.1 301 Moved Permanently
< Location: https://hub.docker.com/
< Content-Length: 0
< Date: Thu, 20 Jul 2017 13:21:37 GMT
< Via: 1.1 rtp5-dmz-wsa-1.cisco.com:80 (Cisco-WSA/8.8.0-085)
< Connection: keep-alive
<
* Connection #0 to host hub.docker.com left intact
[root@kube-minion-2 ~]#
```
