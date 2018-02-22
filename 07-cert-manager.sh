#!/bin/sh

git clone https://github.com/jetstack/cert-manager
git -C ./cert-manager checkout $(git -C ./cert-manager describe --tags $(git -C ./cert-manager rev-list --tags --max-count=1))
helm install --name cert-manager --namespace kube-system ./cert-manager/contrib/charts/cert-manager
rm -rf ./cert-manager/

