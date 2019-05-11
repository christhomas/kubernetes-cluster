# Kubernetes Cluster on Hetzner Cloud
This is a repository of how I setup my new kubernetes cluster.

# Weave.net

You might need to periodically upgrade weave. The way to do that is like this:
```
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

# Monitoring: 
Previously there was a couple of yaml files to deploy heapster/prometheus/grafana/influxdb. But this was out of date and heapster was even deprecated.

To get a new monitoring system which works much better and has built in dashboards, I recommend this as a replacement.

https://github.com/coreos/kube-prometheus.git

To install it, clone it to your system, then run kubectl apply on the 'manifests' directory. You might want to customise it first, but I didn't since I read through and accepted all the defaults as reasonable for my circumstances

This configuraton is much better than the version I had in this repository

**CHANGE THE DEFAULT PASSWORD FROM ADMIN IMMEDIATELY**

# New Cluster: Starting from scratch
## Install kubelet/kubeadm/kubectl onto the all the node
```
apt-get update && apt-get install -y apt-transport-https curl

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update && apt-get install -y kubelet kubeadm kubectl

apt-mark hold kubelet kubeadm kubectl
```

## Install docker onto all the node
```
apt-get update

apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common

curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

apt-get update

apt-get install -y docker-ce docker-ce-cli containerd.io

# Change the cgroup driver to systemd
cat > /etc/docker/daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
	"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart docker.
systemctl daemon-reload
systemctl restart docker

# This should show you 'Hello from Docker!'
docker run hello-world

```

## Configure Kubernetes
```
kubeadm init --pod-network-cidr=10.244.0.0/16
```

On your local machine, you can gain priviledges to run kubectl like this
```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

Once you have done this, you can install a kubernetes network control plane
```
###### TO USE FLANNEL
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml

###### OR USE WEAVE.NET
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
```

## Joining the cluster
For each worker node, you must 'join' the cluster. This command will do everything in one step

NOTE: Adjust the command if you require different ports for ssh
```
MASTER=master; WORKER=worker; ssh root@${WORKER} $(ssh root@${MASTER} kubeadm token create --print-join-command)
```

But for those who don't like too much bash scripting, here is the separated version
```
export MASTER=master
export WORKER=worker
ssh root@${MASTER} kubeadm token create --print-join-command
# copy the command and put it below
ssh root@${WORKER} <put command here>
```

Or you can just login to the worker and paste the command there

# Existing Cluster
## Before you start, upgrade all your server software
> NOTE: You have to decide for yourself whether you want to do this since it might have consequences for your operating system
```
apt-get update && apt-get upgrade
```

## Check apt-get has https and not http
I couldn't upgrade kubeadm because the apt repository for kubernetes was using http and not https
``` 
cat /etc/apt/sources.list.d/kubernetes.list
```
Make sure the file  contains
```
deb https://apt.kubernetes.io/ kubernetes-xenial main
```

# Perform this on your master node
> You must upgrade both master and workers in sync, master first, then all the worker nodes, repeating each step of the upgrade in sync until you've done all the upgrades. **Cutting corners might break something you can't fix :/**

## Upgrading from 1.12 -> 1.13
```
apt update
apt-cache policy kubeadm | grep 1.13
# Pick a patch number, set VERSION to the number you want, without the -00 on the end
VERSION=1.13.5
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=${VERSION}-00 && apt-mark hold kubeadm
# This should show the correct version number, then plan and if ok, do the upgrade
kubeadm version
kubeadm upgrade plan
kubeadm upgrade apply v${VERSION}
```

## Upgrading from 1.13 -> 1.14
```
apt update
apt-cache policy kubeadm | grep 1.14
# Pick a patch number, set VERSION to the number you want, without the -00 on the end
VERSION=1.14.1
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=${VERSION}-00 && apt-mark hold kubeadm
# This should show the correct version number, then plan and if ok, do the upgrade
kubeadm version
kubeadm upgrade plan
kubeadm upgrade apply v${VERSION}
apt-mark unhold kubelet && apt-get update && apt-get install -y kubelet=${VERSION}-00 kubectl=${VERSION}-00 && apt-mark hold kubelet
systemctl restart kubelet
kubeadm upgrade node experimental-control-plane
```

# Perform this on your worker nodes

## Upgrading from 1.12 -> 1.13
``` 
apt update
apt-cache policy kubeadm | grep 1.13
# Pick a patch number, set VERSION to the number you want, without the -00 on the end
VERSION=1.13.5
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=${VERSION}-00 && apt-mark hold kubeadm
apt-mark unhold kubelet && apt-get update && apt-get install -y kubelet=${VERSION}-00 && apt-mark hold kubeadm
# replace abc with the name of the worker node you want to upgrade
NODE=abc
# Run from the master node
kubectl drain ${NODE} --ignore-daemonsets
# Run from the worker node
kubeadm upgrade node config --kubelet-version v${VERSION}
# Run from the master node
kubectl uncordon ${NODE}
``` 

## Upgrading from 1.13 -> 1.14
``` 
apt update
apt-cache policy kubeadm | grep 1.14
# Pick a "patch number, set VERSION to the number you want, without the -00 on the end
VERSION=1.14.1
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=${VERSION}-00 && apt-mark hold kubeadm
apt-mark unhold kubelet && apt-get update && apt-get install -y kubelet=${VERSION}-00 && apt-mark hold kubeadm
# replace abc with the name of the worker node you want to upgrade
NODE=abc
# WARNING: delete-local-data will destroy any non persistent volumes such as emptyDir
# NOTES: but it doesn't delete persistent disks mounted from NFS or HostPath
# Run from the master node
kubectl drain ${NODE} --ignore-daemonsets --delete-local-data
# Run from the worker node
kubeadm upgrade node config --kubelet-version v${VERSION}
# Run from the master node
kubectl uncordon ${NODE}
``` 