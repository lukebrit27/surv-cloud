\l tick/sym.q

.hdb.pth:.z.x 0;

.hdb.createEmptyPartition:{[pth]
    {[pth;t] tpth:hsym`$pth,$["/"=last pth;"";"/"],"1000.01.01/",string[t],"/";tpth set .Q.en[hsym`$pth;get t]}[pth;] each tables`;
    }

if[not count key hsym `$.hdb.pth;.hdb.createEmptyPartition .hdb.pth];

system "l ", .hdb.pth;
