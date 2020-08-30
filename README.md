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

If you want to make the master schedulable. Then you can use this command. Replace [node] with your node name
```
kubectl taint nodes [node] node-role.kubernetes.io/master-
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

The basic steps for upgrading a master are as follows, replace [version] with something like `1.18` and [node] with `s1`

NOTES:
- Kubernetes sometimes has problems upgrading and I can't really say anything concrete about what you must
do if things go wrong. Most of the problems I'm having are with etcd though
- You can't skip versions. If you're cluster is `1.16` then you must upgrade to `1.17` first
then afterwards you can upgrade to `1.18`. You must upgrade the entire cluster, one version at a time. It's a little labourious
- If you do try to skip versions. You're gonna have a lot of `**FUN** :D` to fix it. Don't do it.
```
./upgrade/1-upgrade-kubeadm [version]
./upgrade/2-drain-node [node]
./upgrade/3-upgrade-master

<run whatever command it gives you at the end>

./upgrade/5-upgrade-master-weave-net
./upgrade/6-upgrade-kubelet [version]
./upgrade/7-restart-kubelet
./upgrade/8-uncordon-node [node]
```

# Upgrading Worker Nodes

Same warnings as for master nodes, don't skip versions. Same instructions as master nodes, replace [node] and [version] accordingly.

On worker node:
```
./upgrade/1-upgrade-kubeadm [version]
```

Then on master node:
```
./upgrade/2-drain-node [node]
```

Afterwards on worker node:
```
./upgrade/4-upgrade-worker
./upgrade/6-upgrade-kubelet [version]
./upgrade/7-restart-kubelet
```

Finally, on master node:
```
./upgrade/8-uncordon-node-node [node]
```

Repeat for all your worker nodes

# Granting admin access to your local machine

Replace [user] with your ssh user and [master_node] with whatever node you elected to be the master

NOTES:
- the `.kube` directory might already exist, if this is the case, ignore the error from trying to create the directory
- if the `.kube` directory does exist, you might destroy an existing configuration if you overwrite it with the 
one from your master node like this, so be careful
```
mkdir $HOME/.kube
ssh [user]@[master_node] cat /root/.kube/config > $HOME/.kube/config
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

# Istio

### Step 1
This only works on kubernetes 1.18. I tried it on 1.16 and it crashed, so I'm not sure whether I did it wrong
or whether it's just not compatible. 

Firstly label the nodes you want to run as istio gateways. Replacing [node] with the name of the node you wish to label

```
kubectl label nodes [node] ingress=istio
```

### Step 2

In all the following text, please replace [ip_address] with the ip address of your master node.

To install istio is a bit more involved since to run it on a bare metal cluster, you have to generate a manifest which
you can edit and then apply to your cluster. Also, you need to update the kube apiserver command on the master node
to enable feature gates and options to get things working

Edit the file `/etc/kubernetes/manifests/kube-apiserver.yaml` and where you see the command line arguments, add
the following additions
```
--service-account-issuer=https://[ip_address]:6443
--service-account-jwks-uri=https://[ip_address]:6443/openid/v1/jwks
--service-account-signing-key-file=/etc/kubernetes/pki/sa.key
--service-account-key-file=/etc/kubernetes/pki/sa.pub
--feature-gates=ServiceAccountIssuerDiscovery=true
```

Kubernetes should detect the change and restart the api-server. If this is not done correctly, you're master node
will go down and everything will start going crazy. You can easily fix this by editing the file again and removing the
lines. 

If things work out. You'll be able to access the following two URLS

- https://[ip_address]:6443/.well-known/openid-configuration
- https://[ip_address]:6443/openid/v1/jwks

It will complain about the certificates, but you can just ignore them, or curl the url's and use the command line
options to ignore the self signed certificate issue. Maybe that's easier.

If you get seemingly correct replies to these endpoints. You should be all set to install istio.

### Step 3

Install `istioctl` for your operating system

- MacOs, using Brew: `brew install istioctl`
- Linux, ¯\_(ツ)_/¯ who knows, it's a crazy world where linux has 1261 package managers for what effectively is a zip file and some scripts.

### Step 4

Generate an installation manifest to be edited. Since running on a bare metal cluster requires a different
installation than normal. To generate the basic manifest the following commands can be used

You can first see what profiles you can generate manifests of by running this command
```
istioctl profile list
```

Read on which profile you like, but then the resulting process for customisation might
be different. 

To generate the manifest, you can use
```
istioctl manifest generate > istio.yaml
# or
istioctl manifest generate --set profile=demo  > istio.yaml
```

Now you must edit the yaml file, hopefully these instructions will lead to the right result for you.

- search for `apiVersion: autoscaling/v2beta1`, find and delete the ones labelled
    - `istio-ingressgateway`
    - `istiod`
- search for `kind: PodDisruptionBudget`, find and delete the ones labelled
    - `istio-ingressgateway`
    - `istiod`
- search for `apiVersion: apps/v1` and find the one labelled `istio-ingressgateway`
    - change its kind to `DaemonSet`
    - remove the `spec.strategy` block, it relates to the deleted autoscaling component
    - to the spec.template.spec block, add:
    ```
        hostNetwork: true
        nodeSelector:
            ingress: "istio"
    ```
    - to the spec.template.spec.containers[0].ports block, you need to add all the ports you wish to ingress.
    This should be a good starting place. 
    ```
        - name: http
          containerPort: 80
          hostPort: 80
          protocol: TCP
        - name: https
          containerPort: 443
          hostPort: 443
          protocol: TCP
    ```
- search for `apiVersion: apps/v1` and find the one labelled `istiod`
    - change its kind to `DaemonSet`
    - remove the `spec.strategy` block, it relates to the deleted autoscaling component

Once these modifications are complete, apply the manifest to install everything. Check the logs for any errors

### Step 5

Deploy a sample application to test if it's working. 

```
git clone https://github.com/istio/istio
kubectl create namespace bookinfo
kubectl apply --namespace=bookinfo -f istio/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply --namespace bookinfo -f istio/samples/bookinfo/networking/bookinfo-gateway.yaml
```

Check it's running ok by using these commands, firstly services:
```
# kubectl get services -n bookinfo
  NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
  details       ClusterIP   10.108.157.39   <none>        9080/TCP   3m23s
  productpage   ClusterIP   10.104.136.50   <none>        9080/TCP   3m21s
  ratings       ClusterIP   10.108.50.140   <none>        9080/TCP   3m22s
  reviews       ClusterIP   10.106.35.42    <none>        9080/TCP   3m22s
```
Then check pods are running:
```
# kubectl get pods -n bookinfo
  NAME                              READY   STATUS    RESTARTS   AGE
  details-v1-558b8b4b76-rxw2j       1/1     Running   0          4m3s
  productpage-v1-6987489c74-64hhb   1/1     Running   0          4m2s
  ratings-v1-7dc98c7588-gjcf4       1/1     Running   0          4m3s
  reviews-v1-7f99cc4496-jcw5d       1/1     Running   0          4m2s
  reviews-v2-7d79d5bd5d-49ppb       1/1     Running   0          4m2s
  reviews-v3-7dbcdcbc56-vbgv8       1/1     Running   0          4m2s
```
This command will access the container via an internal pod:
```
# kubectl exec -n bookinfo -it $(kubectl get pod -n bookinfo -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
<title>Simple Bookstore App</title>
```

#### Regarding Autoscaling
The reason we eliminate the autoscaling is because on bare metal, there is nowhere to scale to. You have a set of configured nodes
and you run as a DaemonSet on all the appropriately labelled nodes.

Technically it is possible to autoscale on bare metal. But since this repository isn't built for that environment. I'm skipping it altogether.

# Upgrading Weave.net

You might need to periodically upgrade weave. The way to do that is like this:
```
./upgrade/5-upgrade-master-weave-net
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