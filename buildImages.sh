#!/bin/bash

qp build;
if [ ! -d "qpbuild" ]
then
	echo "Error: qbuild directory does not exist";
	exit;
fi 

cp qpbuild/.env .;
qp tag surv-cloud/tp 1.0.0;
qp tag surv-cloud/rte 1.0.0;
qp tag surv-cloud/rdb 1.0.0;
qp tag surv-cloud/feed 1.0.0;
