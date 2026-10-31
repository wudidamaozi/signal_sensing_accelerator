`timescale 1ns/1ps
module edgeai_vio_axi_master_tb;
 reg clk=0;always #10 clk=~clk;reg rst_n=0,toggle=0,write_cmd=0;reg[11:0] addr=0;reg[31:0] data=0;
 wire ack,error;wire[31:0] response;wire[11:0] awaddr,araddr;wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;wire[31:0] wdata,rdata;wire[3:0] wstrb;wire[1:0] bresp,rresp;wire trap,fault;
 edgeai_vio_axi_master m(.clk(clk),.rst_n(rst_n),.command_toggle(toggle),.command_write(write_cmd),.command_addr(addr),.command_data(data),.acknowledge(ack),.response(response),.error(error),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),.araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rready(rready));
 occupancy_service_soc #(.MEM_INIT_FILE("data/memory/occupancy_live/program.hex"),.JOB_TIMEOUT_CYCLES(60000000)) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.address_fault(fault),.host_valid(),.host_data(),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq());
 reg[31:0] inputs[0:127],expected[0:3],v;integer i,j,n;
 task cmd(input reg wr,input[11:0] a,input[31:0] x,output[31:0] y);begin @(negedge clk);write_cmd=wr;addr=a;data=x;toggle=~toggle;wait(ack==toggle);@(negedge clk);if(error)$fatal(1,"AXI error addr=%h",a);y=response;end endtask
 initial begin $readmemh("data/memory/occupancy_live/inputs.hex",inputs);$readmemh("data/memory/occupancy_live/expected_logits.hex",expected);repeat(5)@(negedge clk);rst_n=1;
  for(j=0;j<2;j=j+1)begin
   n=0;v=0;while(v!=1 && n<100000)begin cmd(0,12'h008,0,v);n=n+1;end if(v!=1)$fatal(1,"ready timeout");
   cmd(1,12'h02c,256,v);for(i=0;i<64;i=i+1)cmd(1,12'h100+i*4,inputs[j*64+i],v);
   cmd(1,12'h014,32'h98760000+j,v);cmd(1,12'h010,1,v);
   n=0;v=0;while(!v[3]&&n<50000)begin cmd(0,12'h008,0,v);if(v[4])$fatal(1,"job error");n=n+1;end if(!v[3])$fatal(1,"job timeout");
   cmd(0,12'h018,0,v);if(v!=32'h98760000+j)$fatal(1,"id mismatch");
   cmd(0,12'h040,0,v);if(v!==expected[j*2])$fatal(1,"logit0 mismatch");
   cmd(0,12'h044,0,v);if(v!==expected[j*2+1])$fatal(1,"logit1 mismatch");
   cmd(0,12'h050,0,v);if(v!=35629)$fatal(1,"cycle mismatch");
   cmd(1,12'h010,2,v);$display("DYNAMIC_AXI_CASE_PASS fixture=%d cycles=35629",j);
  end
  if(trap||fault)$fatal(1,"CPU fault");$display("DYNAMIC_AXI_MASTER_PASS two_runtime_inputs");$finish;
 end
 initial begin #300000000;$fatal(1,"timeout");end
endmodule
