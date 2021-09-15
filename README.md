# surv-cloud

## Overview

## Prerequisites
- Install docker: https://docs.docker.com/get-docker/
- Install docker-compose: https://docs.docker.com/compose/install/
- Install qpacker: https://code.kx.com/insights/cloud-edition/qpacker/quickstart/
- kc.lic
- Login into registry.dl.kx.com to download the dashboard images. 
  - If have login credentials, run `docker login registry.dl.kx.com -u username -p password` to login.
  - If you don't have login credentials comment out the services gui-dash, gui-gateway and gui-data in the docker-compose.yml file. You'll then be able to start the Surveillance app but you won't have a UI.

## Run
1. Run `qp build`
2. copy the .env file in qpbuild out to the top directory: `cp qpbuild/.env .`
3. `docker-compose up`
4. Had to copy docker-compose.yml into the qpbuild directory
