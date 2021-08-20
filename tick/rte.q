//TODOS
/ need to get details about thresholds and how much they were exceeded by passed through to the TP
/ add a feed above the rte that passes the data through in chunks //THIS SHOULD BE THE LAST THING TO DO. THEN CAN MOVE ONTO QPACKER

\l tick/sym.q
/ get the ticker plant and history ports, defaults are 5010,5012
.u.x:.z.x,(count .z.x)_(":5010";":5012");
.tp.handle:hopen `$":",.u.x 0;

\d .spoofing
\l tick/sym.q
thresholdSchema:([]cancelQtyThreshold:"j"$();cancelCountThreshold:"j"$();lookbackInterval:"n"$());
thresholds:first ("*"^exec t from meta[thresholdSchema];enlist csv) 0: `$":data/spoofingThresholds.csv";

alert:{[args]
    tab:args`tab;
    data:args`data;
    thresholds:args`thresholds;

    //cache data
    data:update entity:{`$x,'"_",'y}[string[sym];trader],val:1 from data;
    `.spoofing.orderCache upsert data;
    delete from `.spoofing.orderCache where time<min[data`time]-thresholds`lookbackInterval; 

    //interested in cancelled orders
    data:select from data where eventType=`cancelled;

    //window join 
    windowTimes:enlist[data[`time] - thresholds`lookbackInterval],enlist data[`time];
    cancelOrderCache:`entity`time xasc update totalCancelQty:quantity,totalCancelCount:val from select from .spoofing.orderCache where eventType=`cancelled;
    data:wj[windowTimes;`entity`time;data;(cancelOrderCache;(sum;`totalCancelQty);(sum;`totalCancelCount))];

    //check 1: check to see if any individual trader has at any point had their total cancel quantity exceed the cancel quantity thresholds on an individual instrument 
    //check2: check to see if any individual trader has at any point had their total cancel count exceed the cancel count thresholds on an individual instrument
    alerts:select from data where thresholds[`cancelQtyThreshold]<totalCancelQty, thresholds[`cancelCountThreshold]<totalCancelCount;

    //publish out to an rdb
    alerts:update alertName:`spoofing,cancelQtyThreshold:thresholds[`cancelQtyThreshold],cancelCountThreshold:thresholds[`cancelCountThreshold],lookbackInterval:thresholds[`lookbackInterval] from alerts;
    .lb.alerts:alerts;
    cols[orderAlerts]#alerts
    }   

runAlert:{[tab;data]
    args:`tab`data`thresholds!(tab;data;thresholds);
    alerts:alert[args];
    neg[.tp.handle] `.u.upd,(enlist `$string[tab],"Alerts"),enlist value flip alerts;
    }

\d .

upd:.spoofing.runAlert;