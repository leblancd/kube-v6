# Installing a Dual-Stack Ingress Controller on an IPv6-Only Kubernetes Cluster

These instructions show how to install a dual-stack ingress controller on a *mostly* IPv6-only Kubernetes cluster. The term *mostly* is used here in that this setup requires dual-stack addresses on the Kubernetes worker nodes, i.e. each node requires a public IPv4 address and a global IPv6 address in order for external IPv4 and IPv6 clients to be able to access Kubernetes services/applications that are hosted in cluster.

Many thanks to Antonio Ojea (@aojea) for determining the methodology used here.

## Background
This ingress controller configuration is based upon the [Kubernetes NGINX Ingress Controller](https://github.com/kubernetes/ingress-nginx#nginx-ingress-controller). Baseline installation instructions are provided in the [NGINX Ingress Controller Installation Guide](https://kubernetes.github.io/ingress-nginx/deploy/), with details concerning bare metal installations provided in the ["Bare Metal Considerations"](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/) guide.

As described in the ["Bare Metal Considerations"](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/) guide, there are several configuration options for running the NGINX ingress controller on bare metal:
- [Using MetalLB software](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#a-pure-software-solution-metallb)
- [Over a nodePort service](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#over-a-nodeport-service) 
- [Via a host network](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#via-the-host-network)
- [Using a self-provisioned edge](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#using-a-self-provisioned-edge)
- [Using externalIPs](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#external-ips)

The ingress controller configurations that depend upon Kubernetes nodePort and externalIPs services (i.e. "Over a nodePort service", "Using a self-provisioned edge", and "Using externalIPs") are not applicable for providing dual-stack ingress access because the current single-family (IPv4-only or IPv6-only) Kubernetes support does not support dual-stack nodePort and dual-stack externalIPs.

The "Using MetalLB software" might work in providing dual-stack access on an IPv6-only cluster with dual-stack nodes, but I haven't tried this.

The "Via a host network" configuration will be used here. This involves creating an ingress controller pod that runs directly on the host network, such that the ingress controller server is listening on ports 80 and 443 for all IPv4 and all IPv6 IP addresses on the host network.

The Kubernetes manifests that are used here are actually modified versions of the standard Kubernetes manifests for creating a nodePort-based ingress controller:
- https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
- https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml

The specific changes that are required to the "mandatory.yaml" file to set up an ingress controller on the host network can be seen in the [hostnetwork_ingress_patch.txt](hostnetwork_ingress_patch.txt) file. The changes can be summarized as follows:
- Convert the manifest kind from Deployment to a DaemonSet, and delete replicas setting (so that one ingress controller runs on each worker node)
- Add "hostNetwork: true" to the pod spec
- Add --report-node-internal-ip-address to the ingress controller startup flags

## Configure Your Worker Nodes with a Public IPv4 and Global IPv6 Address

NOTE: When configuring nodes with dual-stack addresses on an otherwise IPv6-only Kubernetes cluster, care should be taken to configure the /etc/hosts file on each master/worker node to include only IPv6 addresses for each node. An example /etc/hosts file can be seen in the section ["Configure /etc/hosts on each node with the new addresses"](https://github.com/leblancd/kube-v6#configure-etchosts-on-each-node-with-the-new-addresses). Failure to configure the /etc/hosts file in this way will result in Kubernetes system pods (API server, controller manager, etc.) getting assigned IPv4 addresses, so that their services are not reachable from the other pods in the cluster with IPv6 addresses.

The configuration of IPv4 and IPv6 addresses on worker nodes is dependent upon the operating system used on the nodes, so details are left to the reader.

## Downloading the YAML Files
To download the manifests for a dual-stack, host-network based NGINX ingress controller, clone this repo:
```
git clone https://github.com/leblancd/kube-v6.git
```

## Creating the Ingress Controller Daemonset and Service
In the directory where you cloned this repository, run the kubectl create command on the ingress-nginx directory:
```
    kubectl create -f ingress-nginx/
```

## Check Ingress Controller Pods
```
[root@kube-master ~]# kubectl get pods -o wide -n ingress-nginx
NAME                             READY     STATUS    RESTARTS   AGE       IP          NODE
nginx-ingress-controller-8rrqf   1/1       Running   0          1d        fd00::101   kube-minion-1
nginx-ingress-controller-t6469   1/1       Running   0          1d        fd00::102   kube-minion-2
[root@kube-master ~]# 
```

## Check Ingress Controller Services
```
[root@kube-master ~]# kubectl get svc nginx-service
NAME            TYPE       CLUSTER-IP          EXTERNAL-IP   PORT(S)          AGE
nginx-service   NodePort   fd00:1234::3:f52d   <none>        8080:30302/TCP   1d
[root@kube-master ~]# 
```

## Create an NGINX Service to Test the NGINX Ingress Controller
Note: This is an NGINX service deployment that is separate from (not to be confused with) the NGINX ingress controller. It will be used to create a backend service with which to test the ingress controller.

In the directory where you cloned the kube-v6 repository in the ["Downloading the YAML Files" step](#downloading-the-yaml-files), run the kubectl create command on the nginx_v6 directory:
```
    kubectl create -f nginx_v6/
```

## Check NGINX Service Backend Pods
```
[root@kube-master ~]# kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
nginx-controller-7p6jt   1/1       Running   0          1d
nginx-controller-bt6j4   1/1       Running   0          1d
nginx-controller-vz2vb   1/1       Running   0          1d
nginx-controller-xn29r   1/1       Running   0          1d
[root@kube-master ~]# 
```

## Check the NGINX (Backend) Service
```
[root@kube-master ~]# kubectl get svc nginx-service
NAME            TYPE       CLUSTER-IP          EXTERNAL-IP   PORT(S)          AGE
nginx-service   NodePort   fd00:1234::3:f52d   <none>        8080:30302/TCP   1d
[root@kube-master ~]# 
```

## Use a Browser to Access the NGINX Service Using the Node's IPv4 and IPv6 Addresses
For example, access the NGINX service using URLs:
```
https://[<worker-pod-V6-address>]/myCOOLnginx
https://<worker-pod-V4-address>/myCOOLnginx
```

## From an External Host, Curl the NGINX Service using IPv4 and IPv6
```
[root@nat64-dns64 ~]# curl -g [<ipv6-address-redacted>]/myCOOLnginx -kL
<!DOCTYPE html>
<html>
<head>
<title>Kubernetes IPv6 nginx</title> 
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx on <span style="color:  #C70039">IPv6</span> Kubernetes!</h1>
<p>Pod: nginx-controller-bt6j4</p>
</body>
</html>
[root@nat64-dns64 ~]# 
[root@nat64-dns64 ~]# 
[root@nat64-dns64 ~]# 
[root@nat64-dns64 ~]# curl <ipv4-address-redacted>/myCOOLNGINX -kL
<!DOCTYPE html>
<html>
<head>
<title>Kubernetes IPv6 nginx</title> 
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx on <span style="color:  #C70039">IPv6</span> Kubernetes!</h1>
<p>Pod: nginx-controller-xn29r</p>
</body>
</html>
[root@nat64-dns64 ~]# 
```
