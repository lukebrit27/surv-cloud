#!/bin/bash

qp build;
if [ ! -d "qpbuild" ]
then
	echo "Error: qbuild directory does not exist";
	exit;
fi 

cp qpbuild/.env .;
source .env;

docker tag $tp luke275/surv-cloud:tp;
docker tag $rte luke275/surv-cloud:rte;
docker tag $rdb luke275/surv-cloud:rdb;
docker tag $feed luke275/surv-cloud:feed;
docker tag $hdb luke275/surv-cloud:hdb;
