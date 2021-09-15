# surv-cloud

## Overview
Small market surveillance application packaged using qpacker, a kdb+ cloud packaging tool that allows you to easily wrap kdb+ services in docker images.

## Prerequisites
- Install docker: https://docs.docker.com/get-docker/
- Install docker-compose: https://docs.docker.com/compose/install/
- Install qpacker: https://code.kx.com/insights/cloud-edition/qpacker/quickstart/
- Login into registry.dl.kx.com to download the dashboard images. 
  - If you have login credentials, run `docker login registry.dl.kx.com -u username -p password` to login.
  - If you don't have login credentials comment out the services gui-dash, gui-gateway and gui-data in the docker-compose.yml file. You'll then be able to start the Surveillance app but you won't have a UI.

## Run
1. `git clone git@github.com:lukebrit27/surv-cloud.git` - private key required.
2.  Run `qp build`.
3. copy the .env file in qpbuild out to the top directory: `cp qpbuild/.env .`
4. `docker-compose up`
5. If running dashboard images, go to http://localhost:9090
6. If not running dashboard images, use `docker attach image_name` to attach to a Surveillance process. E.g. `docker attach surv-cloud_feed_1` 

## Images
The pre-built application images can be found in this docker repository https://hub.docker.com/repository/docker/luke275/surv-cloud/
