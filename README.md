# kubernetes-experiments
This is a repository of how I setup my new kubernetes cluster.

# Installing Kubernetes

Updating Jessie debian to support kubernetes

1. Install basic stuff
	- apt-get update && apt-get install -y vim
	- locale-gen && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
	- vim /etc/default/grub: GRUB_CMDLINE_LINUX="quiet cgroup_enable=memory swapaccount=1"
	- update-grub
	- Add backports, vim: /etc/apt/sources.list:
		- deb http://ftp.debian.org/debian jessie-backports main
		- deb-src http://ftp.debian.org/debian jessie-backports main
		- apt-get update && apt-get -t jessie-backports install -y linux-image-4.9.0-0.bpo.4-amd64
	- Upgrade to debian 9
		- sed -i 's/jessie/stretch/g' /etc/apt/sources.list
		- apt-get update && apt-get upgrade && apt-get dist-upgrade && apt-get autoremove
	- vim: /etc/sysctl.conf
		- net.bridge.bridge-nf-call-iptables=1
		- net.ipv4.ip_forward=1
	- swapoff -a
	- vim: /etc/fstab
		- comment out the swap
	- reboot
2. Install docker
	- Set the version of docker to use
		- DOCKER_VERSION=https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")
	- Add docker gpg key
		- apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
		- curl -fsSL $DOCKER_VERSION/gpg | apt-key add -
	- Add docker repository
		- echo "deb [arch=amd64] $DOCKER_VERSION $(lsb_release -cs) stable edge" >> /etc/apt/sources.list.d/docker.list
	- apt-get update && apt-get install -y docker-ce
	- docker run hello-world
3. Install Kubernetes
	- curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	- echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >> /etc/apt/sources.list.d/kubernetes.list
	- apt-get update && apt-get install -y kubelet=1.8.6-00 kubeadm=1.8.6-00 kubectl=1.8.6-00 kubernetes-cni=0.5.1-00
7. Configure kubernetes
	- kubeadm init --pod-network-cidr=10.244.0.0/16
8. Setup kubernetes to run as an unpriviledged user
	- mkdir -p $HOME/.kube
	- cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	- chown $(id -u):$(id -g) $HOME/.kube/config
9. Install a kubernetes network control plane
    TO USE FLANNEL
	- kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml
	OR USE WEAVE.NET
	- export kubever=$(kubectl version | base64 | tr -d '\n')
    - kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"

