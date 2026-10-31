 task send_aw(input[11:0] addr);
 integer n;begin
  @(negedge clk);awaddr=addr;awvalid=1;n=0;
  @(posedge clk);while(!awready && n<100)begin @(posedge clk);n=n+1;end
  if(n==100)$fatal(1,"AW timeout");@(negedge clk);awvalid=0;
 end endtask
 task send_w(input[31:0] data,input[3:0] strobes);
 integer n;begin
  @(negedge clk);wdata=data;wstrb=strobes;wvalid=1;n=0;
  @(posedge clk);while(!wready && n<100)begin @(posedge clk);n=n+1;end
  if(n==100)$fatal(1,"W timeout");@(negedge clk);wvalid=0;
 end endtask
 task wr(input[11:0] addr,input[31:0] data,input[3:0] strobes,input integer ordering,input[1:0] expected);
 integer n,stall;begin
  bready=0;
  if(ordering==0)begin send_aw(addr);repeat(2)@(negedge clk);send_w(data,strobes);end
  else if(ordering==1)begin send_w(data,strobes);repeat(2)@(negedge clk);send_aw(addr);end
  else begin fork send_aw(addr);send_w(data,strobes);join end
  n=0;while(!bvalid && n<100)begin @(negedge clk);n=n+1;end
  if(n==100||bresp!==expected)$fatal(1,"AXI write bad addr=%h resp=%b expected=%b",addr,bresp,expected);
  stall=($random(seed)&7);repeat(stall)@(negedge clk);bready=1;@(posedge clk);@(negedge clk);bready=0;writes=writes+1;
 end endtask
 task rd(input[11:0] addr,output[31:0] data,input[1:0] expected);
 integer n,stall;begin
  @(negedge clk);araddr=addr;arvalid=1;rready=0;n=0;
  @(posedge clk);while(!arready && n<100)begin @(posedge clk);n=n+1;end
  if(n==100)$fatal(1,"AR timeout");@(negedge clk);arvalid=0;n=0;
  while(!rvalid && n<100)begin @(negedge clk);n=n+1;end
  if(n==100||rresp!==expected)$fatal(1,"AXI read bad addr=%h resp=%b",addr,rresp);
  data=rdata;stall=($random(seed)&7);repeat(stall)@(negedge clk);rready=1;@(posedge clk);@(negedge clk);rready=0;reads=reads+1;
 end endtask
