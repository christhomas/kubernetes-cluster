#!/bin/sh

kubectl create -f helm-service-account.yml
helm init --service-account helm
