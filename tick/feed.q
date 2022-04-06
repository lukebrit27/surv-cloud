//MOCK FEED

/ load required funcs and variables
system"l tick/sym.q";
system"l repo/cron.q";


\d .fd
h:hopen `$":",.z.x 0;
pubData:([]table:`$();data:();rows:"j"$());

//add new data to the queue to be pubbed down stream, specifying how many rows you want published per bucket
addDataToQueue:{[n;tab;data] `.fd.pubData upsert (tab;data;n)};
/ func to pub data
/pub:{(neg h) `.u.upd,a,enlist $[`Trade=a:first tabs where wthin[first 1?1f;intvls];genTrades[];genQuotes[]]};
pub:{[tab;data] neg[h] (`upd;tab;data)};
pubNextBuckets:{[]
    if[count pubData;
        newPubData:{pub[x[`table];x[`rows] sublist x[`data]];x[`data]:x[`rows]_x[`data];x} each pubData;
        pubData::newPubData where not 0=count each newPubData[;`data]
        ];
    };

\d .

/ load in our test data
spoofingData:("*"^exec t from meta[`order];enlist csv) 0: `$":data/spoofingData.csv";
/.fd.addDataToQueue[2;`order;spoofingData];
/pub every 1 second
.cron.add[`.fd.pubNextBuckets;(::);.z.P;0Wp;1000*1];

.z.ts:{.cron.run[]};
system "t 1000";
