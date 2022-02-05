/q tick/r.q [host]:port[:usr:pwd] [host]:port[:usr:pwd]
/2008.09.09 .k ->.q
if[not "w"=first string .z.o;system "sleep 1"];

upd:insert;
/ get the ticker plant and history ports, defaults are 5010,5012
.u.x:.z.x,(count .z.x)_(":5010";":5015");
/ end of day: save, clear, hdb reload
.u.end:{t:tables`.;t@:where `g=attr each t@\:`sym;.Q.hdpf[`$":",.u.x 1;`$":",.u.x 2;x;`sym];@[;`sym;`g#] each t;};
/ init schema and sync up from log file;cd to hdb(so client save can run)
.u.rep:{(.[;();:;].)each x;if[null first y;:()];-11!y;system "cd ",1_-10_string first reverse y};
1"Connecting and replaying from tp \n";
.u.rep .(h:hopen `$":",.u.x 0)"(.u.sub[`;`];`.u `i`L)";
1"The handle for the tp is ",string[h]," \n";
1"The cols of the order table are ",(", " sv string h"cols order")," \n";
1"Finished connecting and replaying! \n";

