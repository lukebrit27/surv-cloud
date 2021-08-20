.cron.tab:([actID:"j"$()]nxtRun:"p"$();funcName:`$();funcArgs:();start:"p"$();end:"p"$();freq:"j"$();active:"b"$());

.cron.add:{[fnc;args;st;et;frq]tme:.z.P;nxtRun:$[(et>tme)&(st<=tme)&st<et;tme;st];`.cron.tab upsert (1+(a;-1)null a:last key[.cron.tab]`actID;nxtRun;fnc;args;st;et;frq*1000000;(st<et)&(et=0Wp)|et>tme)};
.cron.del:{delete from `.cron.tab where actID in x};

	
.cron.upd:{update nxtRun:nxtRun+freq, active:end>nxtRun+freq from `.cron.tab where active,actID in x};

.cron.run:{dct:exec actID,funcName,funcArgs from .cron.tab where active, nxtRun<=.z.P;if[count a:dct`actID;dct[`funcName]@'dct`funcArgs;.cron.upd a]};
