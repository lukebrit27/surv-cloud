#!/bin/bash

echo "Login required to registry.dl.kx.com."
read -p "Enter Username: " user
read -s -p "Enter Password: " pass
echo ""

#Pre helm attempt
kubectl create -f kube/surv-cloud-namespace.yml
kubectl create secret docker-registry kxregistry-secret --docker-server=registry.dl.kx.com --docker-username=$user --docker-password=$pass -n surv-cloud	
kubectl create -f kube/surv-cloud.yml

#Deploy with helm

#kubectl create -f kube/surv-cloud.yml
#helm repo add --username $user --password $pass kxi-repo https://nexus.dl.kx.com/repository/kx-insights-charts/
#helm repo update
#kubectl create secret docker-registry kx-repo-access --docker-server=registry.dl.kx.com --docker-username=$user --docker-password=$pass -n surv-cloud

