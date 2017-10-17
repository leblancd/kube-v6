# Manually Testing an IPv6 Kubernetes Cluster With an IPv6-Enabled, Nginx-based Replicated Service

These instructions show how you can manually test an IPv6-only Kubernetes cluster by instantiating an IPv6-enabled, Nginx-based replicated service on an IPv6-only Kubernetes cluster, using the associated YAML files in this repo.

## Downloading the YAML Files
To download the IPv6-enabled, Nginx-based service YAML files, clone this repo:
```
git clone https://github.com/leblancd/kube-v6.git
```

## Creating the Replication Set
cd into the kube-v6 directory, and run kubectl create:
```
[root@kube-master kube-v6]# cd kube-v6
No resources found.
[root@kube-master kube-v6]# kubectl create -f nginx_v6
replicationcontroller "nginx-controller" created
service "nginx-service" created
[root@kube-master kube-v6]#
```

## Check Pods
```
[root@kube-master kube-v6]# kubectl get pods -o wide
NAME                     READY     STATUS    RESTARTS   AGE       IP            NODE
nginx-controller-gknzr   1/1       Running   0          27s       fd00:102::2   kube-minion-2
nginx-controller-kqd7c   1/1       Running   0          27s       fd00:101::2   kube-minion-1
nginx-controller-sdx7w   1/1       Running   0          27s       fd00:102::3   kube-minion-2
nginx-controller-zw565   1/1       Running   0          27s       fd00:101::3   kube-minion-1
[root@kube-master kube-v6]# 
```

## Check Services
```
[root@kube-master kube-v6]# kubectl get svc
NAME            TYPE        CLUSTER-IP          EXTERNAL-IP   PORT(S)          AGE
kubernetes      ClusterIP   fd00:1234::1        <none>        443/TCP          10h
nginx-service   NodePort    fd00:1234::3:b606   <none>        8080:30302/TCP   3m
[root@kube-master kube-v6]# 
```

## Curl the Service From a Kubernetes Node
Based on the Cluster-IP and service port indicated in the previous step, curl the service:
```
[root@kube-master kube-v6]# curl -g [fd00:1234::3:b606]:8080
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
<p>Pod: nginx-controller-gknzr</p>
</body>
</html>
[root@kube-master kube-v6]# 
```

## Test Random Load-Balancing by Curling the Service Repeatedly
If you curl the service repeatedly, you should see a response from one of the 4 endpoint controllers (randomly):
```
[root@kube-master kube-v6]# curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  44865      0 --:--:-- --:--:-- --:--:-- 70600
<p>Pod: nginx-controller-gknzr</p>
[root@kube-master kube-v6]# curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  36500      0 --:--:-- --:--:-- --:--:-- 39222
<p>Pod: nginx-controller-zw565</p>
[root@kube-master kube-v6]# curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  44774      0 --:--:-- --:--:-- --:--:-- 50428
<p>Pod: nginx-controller-sdx7w</p>
[root@kube-master kube-v6]# 
```

## Test Service Access From a Pod

#### cd to nginx_v6 directory and start a pod that includes the curl utility:
```
[root@kube-master kube-v6]# cd nginx_v6
[root@kube-master nginx_v6]# ./pod-curl
If you don't see a command prompt, try pressing enter.
[ root@test-curl:/ ]$
```

#### Curl the service's endpoints (using IPs from prior 'kubectl get pods -o wide' output):
```
[ root@test-curl:/ ]$ curl -g [fd00:101::2]:80 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  68120      0 --:--:-- --:--:-- --:--:--  172k
<p>Pod: nginx-controller-kqd7c</p>
[ root@test-curl:/ ]$ curl -g [fd00:102::2]:80 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  41710      0 --:--:-- --:--:-- --:--:-- 50428
<p>Pod: nginx-controller-gknzr</p>
[ root@test-curl:/ ]$ 
```

#### Curl the service's cluster-IP and service port (using prior 'kubectl get svc' output):
```
[ root@test-curl:/ ]$ curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  54950      0 --:--:-- --:--:-- --:--:--  114k
<p>Pod: nginx-controller-kqd7c</p>
[ root@test-curl:/ ]$ curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  87898      0 --:--:-- --:--:-- --:--:--  114k
<p>Pod: nginx-controller-zw565</p>
[ root@test-curl:/ ]$ curl -g [fd00:1234::3:b606]:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  46282      0 --:--:-- --:--:-- --:--:-- 50428
<p>Pod: nginx-controller-gknzr</p>
[ root@test-curl:/ ]$ 
```

#### Check that kube-dns can resolve the nginx-service:
```
[ root@test-curl:/ ]$ nslookup nginx-service
Server:    fd00:1234::10
Address 1: fd00:1234::10

Name:      nginx-service
Address 1: fd00:1234::3:b606
[ root@test-curl:/ ]$ 
```

#### Curl the service using the service name and service port:
```
[ root@test-curl:/ ]$ curl nginx-service:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0   7423      0 --:--:-- --:--:-- --:--:--  344k
<p>Pod: nginx-controller-zw565</p>
[ root@test-curl:/ ]$ curl nginx-service:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0  21695      0 --:--:-- --:--:-- --:--:-- 58833
<p>Pod: nginx-controller-sdx7w</p>
[ root@test-curl:/ ]$ curl nginx-service:8080 | grep controller
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   353  100   353    0     0   5684      0 --:--:-- --:--:-- --:--:-- 32090
<p>Pod: nginx-controller-gknzr</p>
[ root@test-curl:/ ]$ 
```

#### Exit the pod-curl pod
```
[ root@test-curl:/ ]$ exit
pod "test-curl" deleted
[root@kube-master nginx_v6]# 
```


