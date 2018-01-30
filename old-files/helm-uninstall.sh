#!/bin/sh

kubectl delete deployment tiller-deploy --namespace=kube-system
kubectl delete service tiller-deploy --namespace=kube-system
rm -rf ~/.helm/
