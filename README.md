# surv-cloud

## Overview
Small market surveillance application packaged using qpacker, a kdb+ cloud packaging tool that allows you to easily wrap kdb+ services in docker images.

## Prerequisites
- Install docker: https://docs.docker.com/get-docker/
- Install docker-compose: https://docs.docker.com/compose/install/
- Install q: https://code.kx.com/q/learn/install/
- Install qpacker: https://code.kx.com/insights/cloud-edition/qpacker/quickstart/
- Login into registry.dl.kx.com so you're able to download the dashboard images. 
  - If you have login credentials, run `docker login registry.dl.kx.com -u username -p password` to login.
  - If you don't have login credentials comment out the services gui-dash, gui-gateway and gui-data in the docker-compose.yml file. You'll then be able to start the Surveillance app but you won't have a UI.

## Run
1. `git clone https://github.com/lukebrit27/surv-cloud.git`
2. `cd surv-cloud`
3. `./buildImages.sh`
4. Change permissions of all files in the repo to avoid any access issues: `chmod -R 777 *;chmod -R g+s tplogs`
5. `docker-compose up`
6. If running dashboard images, go to http://localhost:9090
7. If not running dashboard images, use `docker attach image_name` to attach to a Surveillance process. E.g. `docker attach surv-cloud_feed_1` 

## Run with Kubernetes
### Additional Prerequisites
- Install kubernetes with minikube: https://kubernetes.io/docs/tasks/tools/ 
- Install minikube

### Run
1. `minikube start`
2. `./deployK8sCluster.sh`
3. Run `kubectl get pods -n surv-cloud --output=wide`. Wait for all pods to be marked as ready.
4. Run `minikube service gui-dash` to open the dashboards in your local browser

## Images
The pre-built application images can be found in this docker repository https://hub.docker.com/repository/docker/luke275/surv-cloud/

## Miscellaneous

### Dashboard Image Volume Backup
Useful tool for extracting volume data from existing images: https://github.com/loomchild/volume-backup
