# Surveillance in the Cloud

Trade Surveillance systems analyze up to terabytes of order and trade data daily, in an effort to detect potential illegal algorithmic trading. The logic to identify these transgressors is complex, and computationally expensive over such large data sets. For financial institutions that fail to report illegal activity within their ranks in a timely manner, regulatory fines loom.

That's why many exchanges, brokers and investment banks opt for [KX Surveillance](https://kx.com/solutions/surveillance/), built on the [world's fasted time series database](https://kx.com/news/kx-vexata-break-records-stac-benchmarks-tick-data-analytics/), kdb+. With kdb+, complex analyses of trading behavior across real-time and historical data can be done at record speeds, ensuring regulatory deadlines are always met. 

But speed is not the only important factor of a Surveillance system, there's also a need for fault-tolerance and scalability. Cloud infrastructure has revolutionized the way we can approach building applications. We can now auto-scale resources as data volumes increase, dynamically provision new disk storage as needed, and quickly spawn replications of an application in the event of a fault. These are desirable features for a Surveillance system, that can provide increased performance and reliability. However, committing to a single cloud provider can be daunting, as it can be difficult to untangle an application from the cloud provider once it's been built there.

Thus, we also want a Surveillance system that's portable, not dependent on any one cloud provider. This can be achieved using Kubernetes. Kubernetes is an open-source container orchestration platform, that allows us to automate a lot of the manual steps involved in deploying, managing and scaling containerized applications. Applications built using Kubernetes can be deployed across all the main cloud providers (AWS, GCP and Azure) and immediately take advantage of their scalable resources. Kubernetes is the gateway to the Cloud, providing all it's advantages, without having to fully commit to any single Cloud provider. 

In this paper we will build a mini Surveillance kdb+ application and deploy it locally, on AWS and on GCP using Kubernetes. This will demonstrate how Kubernetes helps to unlock the power of the cloud, while retaining fine-tuned control over the application's components and where they ultimately reside. 

## The Application

The first step is to construct a mini Surveillance application. The application will run one alert called Spoofing. Spoofing is a form of market manipulation where a market participant or group of market participants try to move the price of a financial instrument by placing orders on one side of the book, feigning an interest in the instrument and causing the price to shift. Once the price has shifted, the orders are cancelled and new orders are placed on the other side of the book, taking advantage of the price change.

![Architecture](https://lh3.googleusercontent.com/YkCCPEk4GoYy7FXjqWEzdiETfxDlQSUAn6zJQYbpQY4w0gRONKUGPn85L3qymvAusdPUO20KlDgZ4oe3tTv4bdsq1xP5KBIwUvhi-DMrnus-z7QrXfwqeu0qww_YItSrL9clF9uZC4iRYLPWFll9b7WlwfzF7y2c5yuFaNyRyFmQIr5xbnss3YnzIDgbYBn5ZwHjyUCpX6NaKtte703wd4VnH5ry5b6OCRQJBPJltO3vVBlkRvKwafIZYuF3z_S8rJN1GvMSooH6mKt8wakMVAVVTpAq0B5r6orWwc0FY1WA_jedl8SiOABLE-oAio4U70x8aIN9_Szkw-GV6ScaoBABFNrU8dvsXw2lxNxp0qVcKvt2Ak4tQ2XI_AqQdqjDr48kMg_xVyvIN4DFLYrWyLTlawcAEEzDwVZH868C2vThoELa1bCmQ7DXEjNhy7qtJeniBmbuksYj-_MEvfbhzlPDpkg2_s1vdWTpI_tdAN9GadUsjoOdosmE_8H6KiSL_C7iJnfH_2TCFMhud-S6NCL_1INxqKYUMH4oNzc2KexlPGHLmoQdxR_loLuYmyX4ZmqRcTnQQ-OD7qB6hk-ovW2U9szgfKGO_jHECg2Rrx_iySPuR5bJad-fDbKC-xC1_tVzaFC1ElzjzcyzKqjloew2JvkyT2sGOM1ktxTWacSMa1BLSsUIHeVNDrgr8LcnVivwaKXgzZ8E9_GagieeFe4=w671-h166-no?authuser=0)

The application will detect these participants that are attempting to spoof the market in real-time, and publish them to a data store. It will have a simple [real-time tickerplant](https://code.kx.com/q/wp/rt-tick/) architecture consisting of 5 processes, as can be seen in the graphic above. Let's discuss each process in detail: 

### Feed
The first process in the architecture is a mock feed-handler. It loads in order data from a csv and publishes it downstream to the **TP** in buckets, mimicking a real-time feed. The q code for this feed process can be seen below:

```
//MOCK FEED
// load required funcs and variables
system"l tick/sym.q";
system"l repo/cron.q";

\d .fd
h:hopen `$":",.z.x 0;
pubData:();

// add new data to the queue to be pubbed down stream 
// specify how many rows you want published per bucket
addDataToQueue:{[n;tab;data] 
  pubData,:enlist  enlist[n],enlist[tab],enlist data
  };

// func to pub data
pub:{[tab;data] neg[h] (`upd;tab;data)};

// Grab next buckets from tables in the queue and pub downsteam
pubNextBuckets:{[]
  if[count pubData;
    newPubData:{pub[x[1];x[0] sublist x[2]];x[2]:x[0]_x[2];x} each pubData;
    pubData::newPubData where  not  0=count  each newPubData[;2]
    ];
  };

\d .
// load in the test data
spoofingData:("*"^exec t from  meta[`order];enlist  csv) 0: `$":data/spoofingData.csv";

// add as cron job
// pub every 1 second
.cron.add[`.fd.pubNextBuckets;(::);.z.P;0Wp;1000*1];

.z.ts:{.cron.run[]};
system  "t 1000";
```
The process maintains a list of data to be published called `pubData`. Each item in the list will have the number of rows to publish per bucket, the table name and the data itself. Every second, the function `.fd.pubNextBuckets` will run to check if there are any items in the list, and if there is, it will publish the next bucket for each item. New data can be added to the `pubData` list by calling  `.fd.addDataToQueue`, e.g.  ``.fd.addDataToQueue[2;`order;spoofingData]`` will publish 2 rows of the spoofing test data downstream every second.

### Tickerplant (TP)
The tickerplant ingests order data from the upstream mock feed process, writes it to a log file that can be used for disaster recovery ([-11!](https://code.kx.com/q/basics/internal/#-11-streaming-execute)), and publishes it downstream to the **RDB** and **RTE**. The **RTE** then analyzes the order data, and publishes alert data back to the tickerplant if it finds any suspicious behavior. The tickerplant will then publish this alert data to the **RDB**.

We won't be going over the code for the tickerplant as it remains largely unchanged from the publicly available [kdb-tick](https://github.com/KxSystems/kdb-tick).

### Real-Time Engine (RTE)
The **RTE** is the core of the application, responsible for detecting bad actors attempting to spoof the market. It receives a real-time stream of order data from the **TP**, which it will run alert logic over. Any suspicious activity detected will trigger an alert to be sent back to the **TP**, which will be published to the **RDB**. 

Let's have a look at the spoofing alert code:

```
alert:{[args]
  tab:args`tab;
  data:args`data;
  thresholds:args`thresholds;

  // cache data
  // entity = sym+trader+side
  data:update  entity:`$({x,'"_",'y}/)(string[sym];trader;string[side]), val:1  from data;
  `.spoofing.orderCache  upsert data;
  delete  from  `.spoofing.orderCache  where time<min[data`time]-thresholds`lookbackInterval;

  // interested in cancelled orders
  data:select  from data where eventType=`cancelled;

  // window join
  windowTimes:enlist[data[`time] - thresholds`lookbackInterval],enlist data[`time];
  cancelOrderCache:`entity`time  xasc  update  totalCancelQty:quantity,totalCancelCount:val from  select  from .spoofing.orderCache where eventType=`cancelled;
  data:wj[windowTimes;`entity`time;data;(cancelOrderCache;(sum;`totalCancelQty);(sum;`totalCancelCount))];

  // check1: check to see if any individual trader has at any point had their total cancel quantity exceed the cancel quantity thresholds on an individual instrument
  // check2: check to see if any individual trader has at any point had their total cancel count exceed the cancel count thresholds on an individual instrument
  alerts:select  from data where thresholds[`cancelQtyThreshold]<totalCancelQty, thresholds[`cancelCountThreshold]<totalCancelCount;

  // Prepare alert data to be published to tp
  alerts:update  alertName:`spoofing,cancelQtyThreshold:thresholds[`cancelQtyThreshold],cancelCountThreshold:thresholds[`cancelCountThreshold],lookbackInterval:thresholds[`lookbackInterval] from alerts;

  cols[orderAlerts]#alerts
}
```
The first thing to note, is that since the data is being ingested in real-time, we need to maintain a cache, so we can lookback on past events along with the current bucket to identify patterns of behavior. The size of this cache is determined by the `lookbackInterval` , a configurable time window. We set this lookback in the **spoofingThresholds.csv** file:
```
cancelQtyThreshold,cancelCountThreshold,lookbackInterval
4000,3,0D00:00:25.0000000
```
As seen above, the `lookbackInterval` is set to 25 seconds. Therefore, only data that is less than 25 seconds old will be retained for analysis on each bucket, as can be seen from this line: 
``` delete  from  `.spoofing.orderCache  where time<min[data`time]-thresholds`lookbackInterval;```

There are also 2 other configurable parameters in the **spoofingThresholds.csv**, `cancelQtyThreshold` and `cancelCountThreshold`. The `cancelQtyThreshold` defines the minimum total order quantity for cancelled orders that an entity must exceed within the `lookbackInterval` in order to trigger an alert. The `cancelCountThreshold` defines the minimum number of cancelled orders than an entity must exceed within the `loobackInterval` in order to trigger an alert. If both thresholds are exceeded, an alert is triggered. Here an entity is defined as `sym+trader+side` .i.e. we are interested in trader activity on a particular side (buy or sell) for a particular instrument. 

As an example, see the test data set below:
```
time                          sym  eventType trader           side orderID     price quantity
---------------------------------------------------------------------------------------------
2015.04.17D12:00:00.000000000 SNDL new       "SpoofingTrader" S    "SPG-Oid10" 1.25  1000
2015.04.17D12:00:01.000000000 SNDL new       "SpoofingTrader" S    "SPG-Oid11" 1.25  1100
2015.04.17D12:00:04.000000000 SNDL new       "SpoofingTrader" S    "SPG-Oid12" 1.25  1200
2015.04.17D12:00:05.000000000 SNDL cancelled "SpoofingTrader" S    "SPG-Oid10" 1.25  1000
2015.04.17D12:00:05.000000000 SNDL new       "SpoofingTrader" S    "SPG-Oid13" 1.23  1300
2015.04.17D12:00:06.000000000 SNDL new       "SpoofingTrader" B    "SPG-Oid14" 1.25  2000
2015.04.17D12:00:10.000000000 SNDL cancelled "SpoofingTrader" S    "SPG-Oid12" 1.25  1200
2015.04.17D12:00:11.000000000 SNDL cancelled "SpoofingTrader" S    "SPG-Oid11" 1.25  1100
2015.04.17D12:00:12.000000000 SNDL filled    "SpoofingTrader" B    "SPG-Oid14" 1.25  2000
2015.04.17D12:00:20.000000000 SNDL cancelled "SpoofingTrader" S    "SPG-Oid13" 1.23  1300

```
There are 4 cancelled sell orders on the sym `SNDL`  within 25 seconds by `SpoofingTrader`, with a total quantity of 4,600. Therefore, both thresholds are exceeded, so an alert will be triggered, as can be seen below:
```
time                          sym  eventType trader           side orderID     price quantity alertName totalCancelQty totalCancelCount cancelQtyThreshold cancelCountThreshold lookbackInterval
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2015.04.17D12:00:20.000000000 SNDL cancelled "SpoofingTrader" S    "SPG-Oid13" 1.23  1300     spoofing  4600           4                4000               3                    0D00:00:25.000000000
```
**Note** that the order details in the alert message correspond to the order that triggered the alert.

For a more in-depth analysis of the considerations required when writing real-time Surveillance alerts, I highly recommend you  check out [this paper](https://code.kx.com/q/wp/surveillance-latency/#).
### Data Store
The Real-Time Database (**RDB**) and Historical Database (**HDB**)  make up the data store. The **RDB** receives order and alert data from the upstream **TP** and stores it in memory. At the end of the day, the **RDB** writes this data to disk and clears out its in-memory tables. The data written to disk can be queried by the **HDB**. In the event the **RDB** goes down intra-day, it will recover the lost data from the **TP**'s log file once it's restarted.


## Containerization
<a name="containerization"></a>
So far we have discussed the inner workings of the processes that make up the Surveillance application. Now we need to containerize it and push it to an image repository so that it can be retrieved in a Kubernetes setup. To do this we can use [QPacker](https://code.kx.com/insights/cloud-edition/qpacker/qpacker.html), a convenient containerization tool built especially for packaging kdb+ applications. 

### Configuring QPacker
The focal point of an application packaged with QPacker is the **qp.json** file. It contains the metadata about the components that comprise the application. It should be placed in the root directory of the application folder.

Here's the **qp.json** file:
```
{
  "tp": {
    "entry": [ "tick.q" ]
  },
  "feed": {
    "entry": [ "tick/feed.q" ]
  },
  "rdb": {
    "entry": [ "tick/r.q" ]
  },
  "rte": {
    "entry": [ "tick/rte.q" ]
  },
  "hdb": {
    "entry": [ "tick/hdb.q" ]
  }
}
```
It's a fairly intuitive configuration file, we specify a name for each process and then map each name to a q file. QPacker favors a [microservice architecture](https://cloud.google.com/learn/what-is-microservices-architecture#:~:text=Microservices%20architecture%20%28often%20shortened%20to,its%20own%20realm%20of%20responsibility.), so a separate image will be built for each process, with each q file specified serving as the entry-point. 

To kick off the build process we call `qp build` in the root directory of the application folder.  Under the covers QPacker uses docker, so once the build process is finished, we can view the new images by running `docker image ls`. Initially the images won't have names, but we can remedy this using `docker tag`. Here's a bash script that automates this procedure:
```
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

```
In order to push images to docker hub, the image name must match the name of the repository. Thus, we tag the images with the name `luke275/surv-cloud` , since this is the name of the image repository we are using on docker hub. We push the images to the repository using docker push: 
```
docker push luke275/surv-cloud:tp;
docker push luke275/surv-cloud:rte;
docker push luke275/surv-cloud:rdb;
docker push luke275/surv-cloud:feed;
docker push luke275/surv-cloud:hdb;
```
## Integrating with Kubernetes
Now that the application is containerized and pushed to an image repository, it can be integrated into a Kubernetes cluster.

### Configuration 
The smallest deployable unit in a Kubernetes application is a **pod**. A pod encapsulates a set of one or more containers that have shared storage/network resources and specification for how to run the containers. A good way of thinking of a pod is as a container for running containers. 

A common way for deploying a pod into a Kubernetes cluster is to define them within a **deployment**. Deployments act as a management tool that can be used to control the way pods behave. The composer of a deployment configuration file outlines the desired characteristics of a pod such as how many replicas of the pod to run. Deployments are very useful in a production environment, as they allow for applications to scale to meet demand, automatically restart pods if they go down and provide a mechanism for seamless upgrades with zero downtime.

 Each of the 5 components of the Surveillance application will have their own deployment specification and will be deployed within separate pods. This provides a greater degree of control over each component, as it allows us to scale each one individually without also having to scale the others.  
 
The below specification describes the deployment for the RDB process: 
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rdb
  namespace: surv-cloud
spec:
  selector:
    matchLabels:
      app: rdb
      version: 1.0.0
  replicas: 1 # tells deployment to run 1 pods matching the template
  template: # create pods using pod definition in this template
    metadata:
      labels:
        app: rdb
        version: 1.0.0
    spec:
      securityContext:
        fsGroup: 2000
      containers:
      - name: rdb
        image: luke275/surv-cloud:rdb
        env:
        - name: KDB_LICENSE_B64
          value: "" # insert base64 license string here
        args: ["tp:5011 hdb:5015 /opt/surv-cloud/app/hdb -p 5012"]
        ports:
        - containerPort: 5012
        volumeMounts:
        - mountPath: /opt/surv-cloud/app/tplogs
          name: tplogs
        - mountPath: /opt/surv-cloud/app/hdb
          name: hdbdir
      volumes:
      - name: tplogs
        persistentVolumeClaim:
          claimName: tp-data
      - name: hdbdir
        persistentVolumeClaim:
          claimName: hdb-data

```

Within the deployment we specify that a single RDB container will run within the pod and there will be only 1 replica of the pod running. The container will be created using the image `luke275/surv-cloud:rdb` that we pushed to the public docker repository earlier, and will be accessible on port 5012 within the pod.

The container mounts 2 volumes. **Volumes** provide a mechanism for data to be persisted. How long the data is persisted, depends on the type of volume used. In this case, the container is mounting a **persistent volume**, which is unique from other types of volumes as it has a lifecycle independent of any individual pods. This means if all pods are deleted, the volume will still exist, which is not true for regular volumes. 
The volumes themselves aren't directly created within the deployment, they simply reference existing persistent volume claims. **Persistent volume claims** are requests for the cluster to create new persistent volumes, they have their own specification:
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: tp-data
  namespace: surv-cloud
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: hdb-data
  namespace: surv-cloud
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
```
With each claim, we are asking the cluster to dynamically provision a volume. How the volume is provisioned, depends on the **storage class**, a resource in Kubernetes responsible for managing the dynamic provisioning of volumes. Since there's no storage class defined in the specification above, the default storage class will be used. 

To expose the RDB to other pods in the cluster, a service has to be created. **Services** provide a consistent endpoint that other pods can communicate with. Below is the service specification for the RDB:
```
apiVersion: v1
kind: Service
metadata:
  name: rdb
  namespace: surv-cloud
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 5012
    protocol: TCP
    targetPort: 5012
    name: tcp-rdb
  selector:
    app: rdb
```
Since the service type is `ClusterIP`, the RDB will only be exposed internally within the cluster. Other service types such as `LoadBalancer` expose the service outside the cluster, as we'll see when discussing the [User Interface](#ui).

This summarizes the configuration required to deploy the RDB process to Kubernetes. We won't be going over the configuration required for the other components of the application, since it's very similar to the RDB. 

### User Interface 
<a name="ui"></a>
To quickly create some visualizations on top of this Surveillance application built in Kubernetes, we can use [KX
Dashboards](https://code.kx.com/insights/microservices/dashboards/gettingstarted/#running-steps). 

There are 3 images that make up the KX dashboards architecture, `gui-dash`, `gui-gateway` and `gui-data`. We deploy them into a Kubernetes cluster by creating 3 separate deployments for the 3 images, along with an accompanying service per deployment. The configuration is similar to the RDB discussed earlier, with a couple of notable differences. The first, is that the service for `gui-dash` will be exposed externally as a `LoadBalancer`, so that the dashboards can be accessed from a browser. See it's configuration below:

```
apiVersion: v1
kind: Service
metadata:
  name: gui-dash
  namespace: surv-cloud
spec:
  type: LoadBalancer
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 8080
  selector:
    app: gui-dash

```
Here the pod is being exposed on port 9090. We'll see later how we use this port to access the UI across the AWS and GCP clusters. 

The second notable difference is that within the `gui-gateway` deployment an `initContainer` is defined so that we can import the Spoofing dashboard. See below:
```

initContainers:
- name: gw-data-download
  image: alpine:3.7
  command: ["/bin/sh","-c"]
  args: ['apk add --no-cache git && git clone https://github.com/lukebrit27/surv-cloud.git && mkdir -p /opt/kx/app/data && cp -r surv-cloud/dash/gw-data/* /opt/kx/app/data/']
  volumeMounts:
  - mountPath: /opt/kx/app/data
    name: gw-data
containers:
- name: gui-gateway
  image: registry.dl.kx.com/kxi-gui-gateway:0.10.1
  env:
  - name: KDB_LICENSE_B64
    value: "" # insert base64 license string here
  ports:
  - containerPort: 10001
  volumeMounts:
  - mountPath: /opt/kx/app/data
    name: gw-data
      
```
An `initContainer` allows us to initialize a pod before it starts up any containers. In this case, the `initContainer` is cloning a git repository that contains the Spoofing dashboard files and moving those files to a directory mounted by a volume. When the `gui-gateway` container starts up, it will pick up these files, as it mounts the same volume.

This is what the Spoofing dashboard looks like:
![Spoofing Dashboard](https://lh3.googleusercontent.com/h4nYYOeEZOY2g0rv4nnLm1eRwdMDuAlb7sLP4g2Fgl7uhCr63EaDOPhq_dVlgx_RFkVUWoTJVB4amK0Z3SxT5ITUSiWTrFav3D9RcZGCwMGJ1U_TQwib7JRrfr0w9_NjKuCENdSMWv9m8K2MCmZnpNF0G0IEe3iC709htaJEQMe0kw7u2zdylzbIDvlXOjFGvSd-lTCXJ8Gw_LN_yIIl53hxkpuMw2-NfTJg7xpanr93DGt4VdezvIFqYw0dhbFeRkEP8sDj4B8hiBW9Wr0Y0VtjKk9TH3haVw8FGyCrqmKgrxMsS5SUpCfZzIJIf00PwqSgvOilsEAom34vzktsq6QzJFfma_FnsETesY1jZW2pLhA6rhtpAxwPrTMv42l4Uc4G_wIJFrYY6iol51iDyon1CUepyr8Z7uS_kBxanronNKVhGniwg73ke1r2X1LCvFKl0kDcf7f_mGRHGEI0K7FNSvZrbSBgbyL-oTaJxrJ7u1fFcvUGiffiW1bwCd1hCWWk1lPrr18aMbHecSTbw5_hv3YuHoZoCOkpseAPbI3Q8nccG1WMswznl3dYaMuh0WP5F1OaGc30X8EAtK5zaYK7Av4gMUxUUJUuEAiNnjPhMUGNR5XTjLB8SZMZ8X6O5UBoiJqFcBemQO66bU0Q3x8h6nC3BYq_mWKBt815cmANHOlQxRMJo_7nDpeFAyE1DbzY3zSoJhlbkDtzUqvvweE=w1913-h906-no?authuser=0)

The bottom data grid shows the test order data set. We can push this data into the application by clicking 'Push Data'. Any alerts raised from the data are displayed in the top data grid.
 
## Deploying to Different Clusters
With everything configured, we can deploy the application into a Kubernetes cluster. To interact with the cluster, we use the Kubernetes command line interface, `kubectl`. `kubectl` allows us to create new objects in the cluster with the command `kubectl create`.  The below shell script,  `deployK8sCluster.sh`, creates the objects for the application and deploys them into the cluster. 
```
#!/bin/bash

echo "Login required to registry.dl.kx.com."
read -p "Enter Username: " user
read -s -p "Enter Password: " pass
echo ""

# Creates namespace and persistent volumes
kubectl create -f kube/surv-cloud-namespace.yml

# Creates a secret to allow running of dashboards images
kubectl create secret docker-registry kxregistry-secret --docker-server=registry.dl.kx.com --docker-username=$user --docker-password=$pass -n surv-cloud

# Creates  deployments and services
kubectl create -f kube/surv-cloud.yml
```
We will use this script to deploy the application across the local, AWS and GCP clusters.


### Local Deployment
We can setup a Kubernetes cluster on a local machine using **minikube**. Once installed, we simply run `minikube start` to kick off a single node cluster.

![minkube start](https://lh3.googleusercontent.com/qK8RyRxjsW04nj9qWO_Bx-cegLYGrWS_9yxdDPAY-RpxU1iM4jdCamc_oZNGIsddjqGoSTbdmQTTixIMn2iNLlySKYeFvTtSK4cLLmV8SAGPrDIvHAn4sF3X5tDa6e0tvkTOymzfKypXAdQ-pMJMLR_K_yzgKsj-GXc2DriI1xtWnzPfj-76Qpu_oaPKduMND5yoeGxpi5m4yr6iv7Y1BjehjvVEEEqMmQaKI71Z8BFulIa6Av2FOwzSc6b-aryBj0-MfU6VTSwMV74lM3k-Wbi5tDKDP6xa65PRurr_2MvmrgdxozF4zIyMPYseaS6kIVbDd6s2cpWLdw3dO89CR-ZI3TUl5onZBz56PGws36EkNRCVNfynfglKMCoz6uGDMoO4VXiw1K3cATiTRbu16CO_s4iZzvZ9aFTa7YlqSWHwrJ-LyJlfcmYrjjsP4EBps4C6u8e08aLlFGl-Eh7LaaW90IbuHqZMLB1virtUm1YWYfLboXgg3XAYH7s6YmoieDRfV1ynRVPlrVRQhzNP2NXanK7eb52VhsTxnrQH71hPfbN3-uevYGwIaxGGYn2XpIyJCzEhV9kvrpmgxA-kwQ55bI2Beox0yNPH4M65fdvnY035G236DsiJpSYmh7TIyvvB5Fh99SEAG4mWr9Z0IFJC6p2Z1c0XZn2BYku4x6X3L3kb3eMG4O5wnqGLx_nz-tAjoA-8WySJtrPXwcxbJpE=w1061-h311-no?authuser=0)

Now that there's a Kubernetes cluster running on the machine, the surveillance application can be deployed to it. We do this by cloning the application repository and running the `deployK8sCluster.sh` script. See below:

![enter image description here](https://lh3.googleusercontent.com/Sgn4a2SuBeIX7UdixsK5kX_aDq8KfYrbclGtrg8iQpOYBharCFbBwRYQ8Gf45RjgZO6aaqkbM61XKZcURvRNg9cxxvo6t19ljXCd7lGMav9Y0hNVhJMPKwtEJ1-52DkriIsahMJ_Hyw5IyyVx9Br0rGVLp1CZrNMn3mCNFF_Glm2m-U3FUO_UEBbVHCfZOgsCnAEODzlXwg_gSoCiOZDF3vRUgsTtehBD-KMXCt7iFB2hUValYJ0YyRv5BtP9vFQh4eLuJvXAMKzzTu2JQNiVOeMdHMVSnJ0b3pqPVQ2zFHrnmQ4Yu4uPF2K2210TZOJ_ZL6whIT2j5ivHukRHpibVA8g_ZOrdBcf-kybcRfHmCpJoBr3RlrQX6F6Uy-qrH21-z7GqO8wTNn4mbN5ncIGx2Oi__TpCaZ7UXBuG43d3DfddoK2bFRbJEO47hWbm6vJH9lhOAtYAo7_HThx-IFpqLG5ME5VEJzC2HsTQ5pf0ZwS_deJlfd55I411gzr300IPsERjqByzKrYcwGfTW8IrRN3yHpwk3NaLBETnhIkPxnf_UoR8XG90FG9noinoIm4-CmTPEraiSAWSloc6AOmkzulAajwhxSETRv_6m9H7xYv6L6i0beUCcTyJpT5T_B6G7H8XuSR0WQGd5yCCOXjbrnGs4n-e6yijWlbaQjBrNyaak9UclFxtv-u5WkfsL0mK-kcsgFXA9FFlJ4dnzf97s=w1197-h655-no?authuser=0)

And that's it! We've deployed the application to a Kubernetes cluster on a local machine. We can see the status of the pods running with the command `kubectl get pods -A` :

![localgetpods](https://lh3.googleusercontent.com/fK4Hv3qpfxv1jpfdeFq49FyftFeS_jhSjaXI3_V7AQmRL2lvVbRj7l7NUgE5LEQ1PomCwiZDDCDo2_I6DRJuLp7YYFoBRA2cd54jidpPM7DNxoYuMrxZoIkuA_3molFGtXRxPO1eDGsPXxvybqglGy-a1eG_JB44PMkZ0Sz9SVFQwAfa0Gk6oF0jQTufqiiq-LETf7BIiLNhLr9GRuzK3BpcbhHB_mDWYp0KgNThqVj1E9suAZse8jED9Xq74ILSoCWmwl5tb6yBk28c43OPkFUy8bWWs17zFVTcfd-yRtYuoE7kSlYWHN9HHVGArTg1M-IUk6FgntPlkv4RFFjlsNgcE0SbHvw6PK9JlBJAJ8cndCiGdf5IOPbRjjpZLLF7WOIs5ZTS5HblOPABZ0tUj0TFn41jEPZzJHYRC1JiOAJJrOUUt0716P7PaPEvm1-dd-9rSij7bYEcuqPy_LlWf4qJol5nf6EbotYJi6l1kYi6QiVIiO_PF4yCgTyQ32telg5jOGld3zwLBGTf407jbRhR5WvdETcxmU3eY8dysXnRaSGeZ2VFzPtvHmsPKs7hoW15mtVKDWqA1C7rJ5pm0HwUAAZeDEsfUe5dEaHSkbT7I2d4dx6du5jS0VQVxYKT4elwwPFxDJcwDtKfHcjMqeRO3oTjL6tgC5ifSf884NxIZjWiDfdeyGak_PcazUMs_U67UfBFJFNosF4iSyntom0=w798-h334-no?authuser=0)

To access the UI of the application, we need to connect to the service associated with the `gui-dash` deployment. We can connect to the service using `minikube service` , a command in minikube that returns a URL that can be used to connect to a service. See the command in action below:

![localgetservices](https://lh3.googleusercontent.com/hrGmK1sLM10hXdh2VFq7A9r6SR_EzXMJ6Gy0GCYtCsV-VE_swrSJ-ED6kfq9Xk2PbRcbNCUd-v-0L5L_9mIlybOMoIlKfUnGoDh-gGJONvlOUF2HypGIDgk9Q0WNqgmud0U7MVRBv7_TJTZgQT_Z4PQkE7JC1iA4PvBTh19JBaHrSwfteAc8e6FrLPoGM3XHo2Qh9mrQ1DFj7A06b6ZwW_cX2GJO3oR02dk3IpjbJmadj6cBVmrJIOp-m29SYP6rvp4ihwFBy88zKEJ04lqLC8AVXkh6jt91URywuDSdP1KnjM2d52QKWmoCUhOb0ixjIQqwVZaEc36gbRPG4QFDmIr4yZKuyrCSOthIetZM6ZPPqadw2BBaQWpvaio-OVWt3-l88HxVTyjfpOyH664QVaMkF0qyOcWDSueCmD0cSzf_Aag4t0hNC8f3664ydaKO0V4MtTt8OqvSHKwKEcSKKP-pRpfy-479dBqzpVqqiYipSLldOKWvNI40wnW2RLbsgUk2W1pE1rNPr5tVrOtGyes_tVeqNyRgQXJAyz7BhLjMOFuj6Mj91L1QQje_d2qhps73SI2vLCA97e_y0--kj6LubStpQ3N7ZA6vUh-3oE-SQ7IHzEEBGm3TAsRosH4p9eustH2cr7996iSMX4c6_JkjG4QLzRShRd82J73mm9ofk1OcvwonBA17ni2MT96iF9RPZ9Ik_kGuBHQ-6MeC8rM=w1004-h412-no?authuser=0)

We copy the URL returned by `minikube service` and paste it into a local browser to access the Spoofing dashboard. 

![enter image description here](https://lh3.googleusercontent.com/_IjtH6YlGLTXKL96ivO6bKZLDT8RRWUQ0HlJCNFNe5Zeyki9lFTHBtCxC88flCPXax57z8PxZt5LGNCeqJGnDceL_u5YMQ4qpk8W3smRTYSvNUToB0-KdUWfgCS6VRyi3iz6ORrCmuARwpkl749SpDHe4Y2SucEdhWZv7Tu0emoqqICowTEDPQcDdH1YWSGxeAf1N8c1l08dbi3DS2_ycldwi8VJ03AHlbu9lYne49nobZSKpiPruDczB1KQxHgjQbNdgJvVL7HIRWGYGi6TiiSEfbYlk0nxD4pIXmuB8yTH2k4vBBNPMzLveZIALGatzdUaXZc_K9eEmaj-Whv5Bpnh0DJz2SXQfa9JWv6l9my66yeYYPHzuSShomO1oUX8qT1GWyAjzK0JWluDhraV_QxmizlhNMLhZVsuyNPZw4ILRkidkW-cXQ5DdCgOSZ7D4ANXlfp7dIyn3zIHr5iQe51pQSaCW7a2srazcpPIDGzabWFsEkkg3g6lLdeq0WOKtve5ABc-SfxQseg3GKArzEUTAqDzsHuh5AcPxYDX8b405J3l4mPDWievu0q8OlrKudv9tc6U1cCLWnpPkc_R9sXR3ulCqzZtd7zHfv7oSg_BNRiTVrXM4lF-zmv7Ir88qCFTFOisdwNRo_-Tz0r_JxJtQi7tv1nnfCfpnqquPnt5KnM7KhkneSYkMkJeAc2THD_Dbhf3HwaBrHqTDXU69pE=w1753-h903-no?authuser=0)
### AWS
AWS provides a service for deploying Kubernetes applications called **Amazon EKS** (Elastic Kubernetes Service). When using EKS, we can take advantage of lots of services offered within AWS such as Elastic Compute Cloud (EC2), Elastic Block Storage and Elastic Load Balancer (ELB).

We can create Kubernetes clusters from the AWS management console by going to the EKS dashboard and clicking on 'Add cluster'. 

![aws-management-console](https://lh3.googleusercontent.com/YG0D9oCFaf7Hq6yinqgnoyGcGMRUkmoJFX0A92Ku8tHl1hiJSH37aFDIuv8aYP-69QBfJqW60H1a3MgjWZBM7OMk5IFvtmJxBfqiKEcrhI6XJFpt4DwPAdUCp9OgOk3FwcTV4kYlG2ahvUTgoat2Oo6-r3DYYT9eYGAwMjdjKRFwPu7UeFviFRaFJMgT5yBoRPBhRijlHJnh-EVilsmtTdxl9Y72XsZqZxLjIDujkfaPu7iCx5LQ4Ha4ioJil3c6HDS8Y1289JM_BdK9njn2OCONDteRQNQs3dwwR6peVmRO-BVCK61CsNfymhbz5S7R0CdQ7aEVwfQ5hSYszuCHjUO_OpjBkbCypO7TtDEtYIEsjd5JH9RcBs_UR8UviETO1yYq7XjXTt0CMeGxZ2ADk86mu7a0aDqvYuNcf5ft_4A59FqQu2P7vgnC3O80iVvYQvoqti-JjCNAdZt4drtpuoCCC3KLtUBNNXn4JbguM7Y6KVwzRIPcxNhZS0H8bmweDVRZaXr_PkE0Bbsy-zDGBo0GBf5Cet_UayfRvhMvDQQ10mDW0wEvyEjSwUOqSeA1S1mzg7zujoo_hHdUEGYwwKbv84dDUNIzMvwtDNokhYWPY8X_43xknkvB8F9FTFbn4gHXPJKzUp3GH1IR7zIikkEpNGZFQDttbWmXIVfJYhTX23iGI-JhDudBNsIvtmt_ruvfJ8TmyEo2F1GvR1pLbU0=w1911-h862-no?authuser=0)

As can be seen in the image above, we already have a cluster created called `surv-cloud-wp`. For more details on how to add a cluster on the management console, see the Amazon EKS documentation [here](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).

 Utilizing the AWS CLI, we are able to connect to this EKS cluster from a local machine. First we run `aws configure` to configure the connection to the AWS environment. Once configured, we can use the `aws eks` command to connect to the `surv-cloud-wp` cluster. See below:

![aws-configure](https://lh3.googleusercontent.com/WOnLFaMLYPUx4eI4qIuvI7dhiPkUrsvnAloiE2cRc1f4w5oQV0I_3tze3ZO16lZktxPChtHUg5I5IfY5x_drXL_-P0jlSBOK12TYTcDuo54UsbY-h6YfdgsR1D1sU_SC68bEDCh8BLSZUDGMyninZsTv2GwHRNqoUQ2Rs20RR6rT1u7y-WaQ6CzdBSMpVR-3C5a47-WFTE7J_8ERO3vr79RL-4cEbHUg4Yy02DxkmLWUgWjrTMN-Fb87a4RyAAtxlPSIiWIUs2HgeRkrncOWS2zHX41MmL0AdRxUbVkJULzxTABKqjIc8j3GETwItqiBJ1heMvQOhzgOLf9OK6ZcCnb2qlF6PHiJBNT0QdpfHyUjlQIa_SzJ3ESrdzNnxg96mUFF-WPfFURRVLLVj8ZnSu3-wkUx804ublla_xJC3IrkpZAGqCm4m2FnBfCyz_AJjGFGQUwJb5vh4No1DzOXZ3KzE-m-E83HSCItI8HGQUb-DvnoAfUe3YduAb4e5zT9_tD9UWnW5wa1P-WZMBT8ILwPr78NiR85BeDQykKTGf3Z_TFfOrfWS4nuoOZmDv-FLy2kYxfqOutiNCQ91w2BOtO-Zz70CRQl23nu6ReazQpiIcB38Wm0rz_CEJA0B5cmylG_Porhci0_9EblGbvhxmMYaUuAMeltdAYf0D5Hdv3KuGYYHkxtDG1MWCr5S3JnExUvrUoBGa3H9rHcVAm-n3A=w1346-h340-no?authuser=0)

Connected to the cluster, all we have to do now is run the `deployK8sCluster.sh` script:

![eks-deploy](https://lh3.googleusercontent.com/bMHgdze0oHXJSPEiSh4DS1I_xCIw_ohE6IKP2TG3M7blgURy4ti2FBwPA0I7a-vvQZTzxnmT4ht4dfZPofyp6eXKcRLiYu35zILjwLSyePzfnnLRfgKFWCrTE-XT5Vps3ygMbp-QDNbrDHa_AOuowxGIi9Jdm99GABu9yW8UEV3lAuJzSONvc46FEv8HYSNY76D1w2ZKpfcP-L-4aEcaqRYKd2f9Q5cbQOJKERTzIDB6Mdk0PsOZTc4vgb2E_HFRjBa3KdOAGpnQ6qn17kD4wazF7K-Zb5vDC_96t44whjEtS9zamSHbEH0zbErXz6H395iq1Y77qdgl-bDm56TshTkfs_lsxsaSMyvtIpIwa3mrF0Fm0A6xOO3fFJmvXwdaoHRUQy7WL2tjOjWfTfZMaagRZAL8t10A5SjIT_-xRvPUg31GxCYsmdsiAAUag2ANt3XyKVp_0NNoDCdE6movR_lMEiahSPAMX1UQ3zHWIVqbVSX4rTefhlJZ4iitVWrcmz5mcfOidQo6HrUjGkGFMtBWZ8cKeUgcKJ1yJN2X0X51F0ML6ofgSAR-Bsor4-o6mxAopVKhZw6xYa0-5T2NAVdFamfXIllmmYzkEIciDIqKqups1HkiaIK6HLt2SB2Nb0byqJIcTCPTvotCAQjnifcV-63UZJdxCWylQ9y2joQjEDui5oXxZCJJUCFXqu8jCu8Zr4OjvyZF1BJw_9Rcs6LE=w866-h769-no?authuser=0)

Like with the local deployment, we connect to the UI via the `gui-dash` service. However unlike the local deploy, AWS will automatically provision an **Elastic Load Balancer** resource for services that are of type `LoadBalancer`. This means the `gui-dash` service will be assigned an external IP/URL that can be used to access the UI. See the external IP assigned to `gui-dash` below:

![enter image description here](https://lh3.googleusercontent.com/K4MPlcwnvuUjPMktoGA9jwHrOcoQ1WNF6DKfvPxQtBJmzQysfKE9mCqPUZnve6hrkRVXNAonui5uUh8d6X5d-JjoPpka9RQxRF4OyOzhiO4pTi-Cp-OeRbS25xIYejVn7eK3OARJEnDlN5WVcaiEMfZqwvo1op2DuzFxwTs1RcSMrZtkJgYQ1mdvGF6lBFVEW45phhFhXR-NPq3tyFBIXTJW9x8Cjr4gvg9HvDzxTosHkJQ_ORz3gC2QqgrpmYTuvFrnDMVH4h8DAIOGkP9rzKaDKnXObtDBLYOmnwDRiM8dQLVv8QXXBAkKAi6WQ7WdlR9VmsSy1IXOWvhszUyFRFGxX5g5o_ZRmzPNsInM4YTrJtObDzDslGRL92qEJ9TDDe7nuy1gmJ5ieeOqhB_KTUHZ-2fkreb7cqb9W02l2Ax-Gie8A-6X8LueIQLhSD7u4dI2hBpnCJAvjo25LNebk_8WNrbUdYGEjCJ5WG5Mg8o5x9FF5ul5FKlZoLuVWq3BFwNEEQ4EMPSsFb8tq9gpYPrKOvCvQ8Qm7CGGiuT9lDr5EEPU21tgWZNhXnBL1j-h6fkp7YQdtuKwDE4kJPAdeP8z82OIwbRxiwcd_F8SShycsWgQ9JQAg0SDJznlIXymOa0QV6uPDSg7vmBliIWCbzSQ9E_Nyi_HU7Apu4xL6zgV75rMpJwNMi-SEE5LxMy11oi741ND6p1vouJWsHILpX0X=w1298-h240-no?authuser=0)

The port we assigned to the  `gui-dash` service was 9090, as shown in the configuration [earlier](#ui). We use the external IP + this port to access the UI, as shown here: 

![eks-spoofing-dashboard](https://lh3.googleusercontent.com/Nd0tjTCeflRY_g5e0C_jL8a1DlPUwaoOAkiPIIrHPK0VSywser0OrRQkxeeq2lPDnKnzSmU_d3bG4uYe693g9qVVGjRmIKchAJYdKz0jorbms4rXVxGMBKPv-zX2-GWRlExwDbLsa0B_oD7U7LcQ7rTzRW3WHS4r4O8MlvqehsOfEuf_DPiPoIkHuBP5sgVmzSE9UqXM4VooDxjVwMpwHp8aHjJq9SJW-n43nX_wKVuwM8BavPxNjEtD8btLVKG3KHDjxPicbQoxuZwLSFSoYh8xse_VelzoHh3iwWyMVhnxxha7Id_n5GArnyP8BenXcwrrJRyt8RexJLfRy56JGuX8XIZkNPO0ca_O7oPHP-mIhjUgDCzDwPxN-A0yAgNqYQwzUlCN26ehuZqN7ibIrBLZTvZFHbhS7T3HYNrpavRnq1Q7I5uO5vDH6q7cFFIqEbfLXz-meEk8ZZFTZDHnAz9YvF7pNR52ahq8htGKdpj0J4RazGNB08iRFw072QAhxwkMegifZqu1JGZddO0gFJ5rkpD341Q_6T9FG5Nm4Z0r1dP26MvRD7Fr7U7o3U1DYkxjDWgQbufrEjjg_065zoSqCV1XjOYLv_-WGEZVhgnJ1a3zI_Xcoy2cW0RKiqF5NR7EyInqDi9QU5ePx9iR7L5y_2jo2CtaT6t1wC-2nu1ppLRGfaZVGmUuOkUuwJJc3REUesh6VExDb8EzWXw1Yjp7=w1739-h903-no?authuser=0)

That's it, we're now running a scalable, fault-tolerant and portable Kubernetes application in the cloud. One of the great aspects about this is that we're taking advantage of lots of AWS resources, the pods are running within EC2 instances, the volumes are created using Elastic Block Storage and http requests are being managed via Elastic Load Balancer. But at the same time, we're still able to quickly deploy the application on another cloud provider, as shown next with GCP.

### GCP
Similar to AWS, GCP also provides a service for deploying, managing and scaling Kubernetes applications, called Google Kubernetes Engine (GKE). This is no surprise, since Google are the original creators of the Kubernetes software.

To create a new Kubernetes cluster in GCP, we go to GKE on the GCP management console and click 'Create'.

![gcp-cluster-creation](https://lh3.googleusercontent.com/MUYQKAVnd0tbQ61OlqnQmW6rZTgxGnB6AXYV2l_4Fie66I6MB9egdT-HlvSZRmY1cKo8JMTSLPvcYBLiw0JGqJKwg_ObCPyRWm3ujJ1v71dPqtY-jRFSo-Wc1VxUyUf0gQPs-I3I9lR16nbhxla5PGIpSzj3f3NSWJpiieezPfxyVTUmV3FvAMcbIKuu6xmbiSTMsMoMhGTDaQC-iKbn7JqDTd2tbFP-uxjWc3fpIxEd-Y8AtNWkCBi4gedFK05Ipo8QI1slfGiKfh2N29-LmJ3_n7KPUhVfeeAcmCFATlH-yMAgnnOtyv7s00oeGWNjhM4IXVhRYHBSmGBVayJWoVzBv4JtZRyXDJzXYe-0UXFtBXTFngdVfnGszmrR--_AmPvg5DelATFruMd0murgFijQl9pwIdo6nxJEDTCFm9Mex1PVi4UuGs06bETHmkzPyF0NABn_HhD41YrkZDJn9lj5uxgcrEnnRUh9O3kmLXtb4IRNx8tWPLMPSO1BlbXzvy64zEMarCZVPXgdOAOMTMaPNF5FtLdkEwbIcFJbLEnp_v0KGfoRjWaApONDbRpLk2ilaf0XTn906MK06R7_ejBWRYioCtP592CsgO14bYbBb6J99Y5u-QvicDm_MRouz1Y2-OcoNCKmTxrINWAlIj_KvZQUut-hxO1ynzrAjTBI3KzERPlGAcyHc5CCAUun2blYnd-DTodMJizJhMYsKJVI=w1909-h838-no?authuser=1)

In the above picture we already have a cluster created called `surv-cloud-wp-gcp` that we will use to deploy the Surveillance application. See the GCP documentation for detailed information on creating clusters on the management console. 

The GCP CLI, `gcloud`, allows us to connect to the cluster we created from a local machine.  We connect by running the command `gcloud container clusters get-credentials` to retrieve the cluster data and update the Kubernetes context to point at it. See the command running here:
![gcp-initalize-cluster](https://lh3.googleusercontent.com/MylMmWQxamKacPovOfoRwiFA6SQ-BY9ivmi0Sc2vX75PYR7W0xcHURINO3-9FnUphHJd7QZsLjByzMLZ1CE7BEMZ9t_pyw0R9itoHq9dVUMmK0I1fmGCXrFV4xRk3QYmVXXbK3fNNEdv-aJ_vqilozmP5aEuZu8JN1WUcVJsxb4t7kUsUNLN0ooY4pYdHLPY98exdvO_2uk_wxgkFk_HlumxcRNV7lnQzONtL0PXMpVHMS-z3iKi7MOMKkQ_qjzoghknGqaiUexhKfiwNVi9QuLfO9epKO7FJ2uApBRAfhq9XzVzvYLo77716KYb5o-tSTts0jm8ohCpb7fHcwCkdYrIo1PpvK-TxAFCqJNkksGapNnTgs7O5g8QgHNgnrR1yHUCE_VvTIB58z_1VigFFk6pDjFo3AUNb5Z62GRw5TXNJcxj35zDCWJ8WDtBWImDUOm5gM_jhIxZOrzDMjIHJor-PTot0CavBgFrgrUcEw6eYWeQn2xpNKgW4Qu8nNzvUeoNoDrMrVV1nARMnKdF9r49H_Kyc9Zw8_NzSSvq4K3fprNGRIRrGmdA7q3jYRqeqxbiqkxOACIPAAsDpwzgW7eENfW5JFcJn-u9DRalpWlmBvW1A7-p8SyfoaZFoDjfAVylGl8XL3HwbvJByAf7YJRAYkkN_zNlTV2snoKh8XhYzrnQTvitGQBsCMdNV0ClrZghtVGZoFYz2bjNK0fZkHAi=w1178-h396-no?authuser=1)

Connected to the cluster, we can deploy the application, once again running the `deployK8sCluster.sh` script: 

![gcp-deploy-app](https://lh3.googleusercontent.com/uPGfhUZYXTdTPMG-gHt5rOLuH-PS7oXZGuO23A9drRaITaiSuQJZLvIIfviZ9nanGjudydkGYLuTH-4DAYZ19d6YxdHDWrgr32bAncPmqg-CtEDR5gF68qTN8_Ij51Z7FOCKayt3tQsd-c9HLvG146TruJfGGX74Pf0m_ULU-Q5oR4GW-hp5BfpIMUig7WlDBhzLp6TPiMDy0qejAJxjV4q61-V-MWVlULR7lcezttnAFwSAiauF9T7oOPnTEFnPERpRchk9dbJ_s8Zzvimbfg62sM4XZkqvx4nJQoTMKRCye1XMJ49YxLecZQTxEy52_KP_j7nHHo-0TwmIrKB1F38ZZcBOzYBOimnIteFWbnKz5aJ1dHiloaTgbuQTP3oh-8IDahYZYNEfox_6pgzE4CfOlmEJ1cdTXzsktlZU2WY8NQN8mn9h14h4tgcTmJixmy7aBvmvll9_5-3XvbUhDDlDj33YCDDh-ilQX7KYCaUR5oND2XSpYuPPyo0nFUTNKBDVF4sfYSqFoZiz0vN0I7IcAWJPOZnaots8xMmIVe7BKR-h0jZiHaGX2LqI0iZ3Icr2idF2ounEcFs2Mi4ijdlvjy82GatNTcpDxHt11XlcAwf3Sktc2ugbpio2hDILRBlvNhjNZFOfvgpRiLtFdYfrFXnpR1BjlfukyZStaH0JWrtpOV0f0TH9PZc8i5xszuflHIZA-xGdxAYOImPYcTKI=w1013-h769-no?authuser=1)

Like AWS, when a service in Kubernetes is of type `LoadBalancer`, GCP will automatically spawn a network load balancer that will be attached to the service. This results in the `gui-dash` service being assigned an external IP that can be used to access the UI.

![gcp-services](https://lh3.googleusercontent.com/uYm3OetulIGWMaqKfpQPCctSJR4g9ZEfF9HUwLGI67Obld2AT-GQDW6inRHLF7APUmFpmCDEOTh4i2CCx6xOM4bhgkaJLkBwA6bHonUtZLMIhvfy4XzJalMY9R1vy_WbvUqfZEHL-Mv59b7fXxvlwlnKRDLWjP1h54OL6RbMfAKlpcymVof0Oiv9sZu906IVN-gqdBscJzafDXffhltyPfqE9xdecR8WP_YjqT1043X-rVrtrD9I4y65f5qCIYbfxdn_siWVsVQCwewaAevuKUWAdjAjyfcR9AoGEgaperq6LtEdPK5cjCJobUdWK1JkX4ssgVk0VvvpfHaU2_zYSP-mhMHW8jA9uvcoWIfB_CtCmlTtSBtCq8zB4HP9lG0Lf7XeIB64J3BKFLaOcNUzGFJYyGww1nxS6Tjm-fhOZt_2CvciyCFt3dI4tNH1qfQrKpcSJ7hUt5Cmjr6mJyiqgoFOikHtTEUtc0zaa1TqryWOLhherCUSOxNlbwiO96egNYCGxFujHsEc95udpagzmVTtwgyKSoeO0ZCx4K8K2JzxHkqXJoydRueCptoN2HlymmCusyh3_eIszqCgKcJVCf0WItU6BeU-OcOQCdEUPjpl_oMGlkvMMMcY8Q5PHJvup3L7BVn_m-9nBUjudp2-xkbNMg2zblFkgRyNibcksdkA400riary_OkmcaF3Jo6tSRgZQ9bM4iVeP4XSuxdrWOgQ=w947-h291-no?authuser=1)

We take the `gui-dash` external IP and service port to build the URL to access the UI, as seen below:
 
![spoofing-dash-gcp](https://lh3.googleusercontent.com/gnIqOQAFwibqTeC5LPflxW-sgspROq9RF4MLGnUjNa4J6zSdk6MiCNSMr8bvM9K_3b0AEMbCDSblJ5Luh_7Mi_jN1Cu36Hwy68dACDwd_ZxLdxKuH71BWoicbtVhS90LuXgFV97VbYeugwxtMu2aDpu5Y9rhNFfFETQJtIADa7NUnWaPHveqUbx4SaMVN_oNjE6m1w5p2UqQM2c1F8AUXeJL7jZfbJoe9FcvVK1vkTUnt4Bs-gzz57jG-9VOgNO3kvlVQCxYzBRiGS7nfYlOJWyymit0hCnHihcl8QqWmPCzfigYHYDFb71wGC08glVp7HwK6XnYMea1ne0cPYgjs58LvshWr6dLZGr8_LmDVt45qmnI6ur8sjv02vlb_wM9T7Qc2NfsI3YTTNNe7IAjC2oiDa7eqwR5qpvyfoETnxjXFnEaaGCOzbCxRImr-oWsMSU4BXC9qeG4Odh3e9wIir4Dx_sOqAz9ZWiDeWbpTGPu-HWv8LkID1uf2Op2XX0PKT7hrp0znGpvK_QojAlK9h7Usq3qDt9Ifb2tFXaZtPnFcA4ecQ__Gk_o0UGTbI7vFf6yuBMngi6gPTIvGXSrH2su4ZC9o5UTg92EjfvvbQR12WGvcl-mGOePuzBGTvdO97Py4TDS_aBuTckv-n-bVKJBAnvxzxgFRUmhVzhwThHEelcwGrdHYk2XnFW5O8XS3aULrxkvzh3Q0r8rfSV4k0g0=w1749-h903-no?authuser=1)

And once more the Surveillance application is deployed to the cloud, this time in GCP. What's noticeable about the steps that were involved to deploy the application in GCP, is that they were very similar to the steps for deploying to AWS, and equally as straightforward. No changes were even required to the Kubernetes configuration files to deploy to GCP vs deploying to AWS. This illustrates the power of using Kubernetes.

## Conclusion

As alluded to at the start of the paper, Trade Surveillance systems are only going to become more complex and more data intensive. We only need to look at the explosion of cryptocurrency over the last few years, and the web of new regulatory complexities that's created, in conjunction with an average daily trading volume of $91 billion, as an example. As a result, fast, robust and scalable Surveillance solutions are now a must. Building Surveillance applications in kdb+ provides unrivalled computational speed on large datasets, and as shown, deploying them using Kubernetes offers the scalability and built-in fault-tolerance we crave without having to become surgically attached to a single cloud provider. 





## Author
**Luke Britton**


