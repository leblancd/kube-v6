# Running an IPv6-Enabled, Nginx-based Replicated Service

These instructions show how you can instantiate an IPv6-enabled, Nginx-based replicated service on an IPv6-only Kubernetes cluster, using the associated YAML files in this repo.

# Downloading the YAML Files
To download the IPv6-enabled, Nginx-based service YAML files, you can either clone this entire repo, including the YAML files:
```
git clone https://github.com/leblancd/kube-v6.git
```


Or you can wget the 
```
wget .... https://raw.githubusercontent.com/leblancd/kube-v6/master/nginx-v6/*
```

# Creating the Replication Set
In the directory that contains the replication set:
```
kubectl create -f nginx-v6/
```

# Testing
TBD

