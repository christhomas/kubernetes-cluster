# Kubernetes Cluster on Bare Metal

This is a repository of how I setup my new kubernetes cluster. I tried to accumulate as much useful knowledge into this
repository so I didn't have to keep searching on google for the information. None of the scripts are really necessary. You
can open them and run everything directly and it's just because it's sometimes easier to package things up rather than
do all the dirty work yourself. Probably you should understand what the scripts are doing before relying on them.

This is a single master cluster, it's working ok for me and I'm trying to integrate more things and build a little
system of git repositories which take care of various sides of my system and how it's configured. You'll find
other kubernetes repositories in my profile for gitlab and monitoring (grafana).

I'm trying to keep it current and make things as easy to understand as possible. I'm also adding extra knowledge 
as I find things useful to know, or produce better scripts.

This system only supports debian. But probably the basic information is enough for you to maybe clone it and translate
it for other linux distributions.

# New nodes (Master or Worker)

To install the various packages to use kubernetes on this node
```
./create/1-node-init
```

Optional script if you did not already have docker installed
```
./create/2-install-docker
```

# New Master
To initialise a node as a master node
```
./create/3-init-master
```

** There is NO HA support, this is a bare metal single master cluster. **

## Make the Master schedulable

If you want to make the master schedulable. Then you can use this command. Replace <name> with your node name
```
kubectl taint nodes <name> node-role.kubernetes.io/master-
```

WARNING: Making the master schedulable stops it from protecting itself against rogue pods which might overload 
the server and leave it starved of resources. When this happens. Kubernetes can get quite angry with you and 
then you have a storm of problems cause pods and services start fighting, getting oom-killed, and restarting. 
This "storm" can get quite hairy and I'm warning you that unless you're careful. You could have a "fun" weekend!


# Join Worker to Master node

On the master node, execute this command, it'll return you a statement to execute on the new worker node
```
kubeadm token create --print-join-command
```

Copy and paste that command into a terminal on the worker node


# Upgrading Master Nodes

The basic steps for upgrading a master are as follows, replace <version> with something like `1.18` and [node] with `s1`

NOTES:
- Kubernetes sometimes has problems upgrading and I can't really say anything concrete about what you must
do if things go wrong. Most of the problems I'm having are with etcd though
- You can't skip versions. If you're cluster is `1.16` then you must upgrade to `1.17` first
then afterwards you can upgrade to `1.18`. You must upgrade the entire cluster, one version at a time. It's a little labourious
- If you do try to skip versions. You're gonna have a lot of `**FUN** :D` to fix it. Don't do it.
```
./upgrade/1-kubeadm <version>
./upgrade/2-drain-node [node]
./upgrade/3-master

<run whatever command it gives you at the end>

./upgrade/4-master-weave-net
./upgrade/5-kubelet <version>
./upgrade/6-restart-kubelet
./upgrade/7-uncordon [node]
```

# Upgrading Worker Nodes

Same warnings as for master nodes, don't skip versions. Same instructions as master nodes, replace [node] and <version> accordingly.

On worker node:
```
./upgrade/1-kubeadm <version>
```

Then on master node:
```
./upgrade/2-drain-node [node]
```

Afterwards on worker node:
```
./upgrade/3-worker
./upgrade/5-kubelet <version>
./upgrade/6-restart-kubelet
```

Finally, on master node:
```
./upgrade/7-uncordon [node]
```

Repeat for all your worker nodes

# Granting admin access to your local machine

Replace <user> with your ssh user and <master_node> with whatever node you elected to be the master

NOTES:
- the `.kube` directory might already exist, if this is the case, ignore the error from trying to create the directory
- if the `.kube` directory does exist, you might destroy an existing configuration if you overwrite it with the 
one from your master node like this, so be careful
```
mkdir $HOME/.kube
ssh <user>@<master_node> cat /root/.kube/config > $HOME/.kube/config
```

# Ingress Nginx

You must tag the nodes you want to run ingress-nginx on. This is because I felt you should choose which nodes in 
your cluster should act as edge ingress nodes into the cluster and it doesn't have to apply to every node in your 
cluster.

You can see what nodes have what labels by running this command
```
kubectl get nodes --show-labels
```

You can label the nodes you want to run ingress on by executing this command. Replace [node] with the actual node name
```
kubectl label nodes [node] ingress=nginx
```

If you make a mistake, you can remove a label like this.
```
kubectl label nodes [node] ingress-
```

# Upgrading Weave.net

You might need to periodically upgrade weave. The way to do that is like this:
```
./upgrade/4-master-weave-net
```

# Monitoring: 
Previously there was a couple of yaml files to deploy heapster/prometheus/grafana/influxdb. But this was out of 
date and heapster was even deprecated.

To get a new monitoring system which works much better and has built in dashboards, I recommend this as a replacement.

https://github.com/coreos/kube-prometheus.git

To install it, clone it to your system, then run kubectl apply on the 'manifests' directory. You might want to 
customise it first, but I didn't since I read through and accepted all the defaults as reasonable for my 
circumstances

This configuraton is much better than the version I had in this repository

**CHANGE THE DEFAULT PASSWORD FROM ADMIN IMMEDIATELY**

# Debugging

Upgrading kubernetes can sometimes fail and cost you hours to fix it. Unfortunately I have no silver bullets to offer you.
But remember that kubernetes runs on the underlying container runtime, probably docker. If things go wrong, it can help to 
remember that you can get some extra information from docker itself. Here is some information you might find useful

1. You can use `docker ps`, `docker logs`, to find out information about a containers state
2. Remember that `docker ps -a` will show killed containers after a failed upgrade
3. I had a problem with etcd being defined as version 3.4 when 3.3 was being used. 
I edited the /etc/kubernetes/manifests/etcd.yaml and changed the docker image and then the cluster would start again
4. Kubernetes runs as a series of docker containers. EtcD is the brain, kube-apiserver is the frontend rest api. If the brain
dies, api server won't start.
5. In one terminal run `journalctl -f` and in a second terminal run `service docker restart` and then `service kubelet restart` to 
see what is happening when kubernetes tries to start up. Then use `docker logs` on the failed container to maybe find out more
6. Cry and realise how much of a failure you are. You're trying to run kubernetes and you just aren't able to fix it when it's broken.
Your life is a mess and you need to evaluate what direction you're taking. Is this really for you? Yes, it is. 
You just need to be persistent. I believe in you.