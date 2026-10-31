`timescale 1ns/1ps
module edgeai_vio_class_master_tb;
 reg clk=0;always #10 clk=~clk;reg rst_n=0,toggle=0,write_cmd=0;reg[11:0] addr=0;reg[31:0] data=0;
 wire ack,error;wire[31:0] response;wire[11:0] awaddr,araddr;wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;wire[31:0] wdata,rdata;wire[3:0] wstrb;wire[1:0] bresp,rresp;wire trap,fault;
 edgeai_vio_axi_master m(.clk(clk),.rst_n(rst_n),.command_toggle(toggle),.command_write(write_cmd),.command_addr(addr),.command_data(data),.acknowledge(ack),.response(response),.error(error),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),.araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rready(rready));
 assign fault=1'b0;
 picorv32_accel_soc_host #(.MEM_INIT_FILE("data/memory/classification_live/full_network.hex"),.WEIGHT_INIT_FILE("data/memory/classification_live/weights_words.hex"),.ACCEL_TILE_ROWS(4),.ACCEL_TILE_COLS(8),.PACKED_WINDOW_LOADER(1),.ACCEL_MAX_K(192),.ALLOW_LOADER_OVERLAP(1),.PIPELINED_POSTPROCESS(1),.DIRECT_WEIGHT_FEED(1),.CHAINED_POSTPROCESS(1),.INCREMENTAL_WEIGHT_ADDRESS(1),.AUTONOMOUS_LAYER(1),.LAYER_INPUT_OVERLAP(1),.PACKED_READ_PIPELINE(1),.OVERLAP_GEMM_WRITEBACK(1),.ZERO_LANE_ADVANCE_OPT(1)) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.host_write(),.host_value(),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq());
 reg[31:0] inputs[0:127],expected[0:7],v;integer i,j,n;
 task cmd(input reg wr,input[11:0] a,input[31:0] x,output[31:0] y);begin @(negedge clk);write_cmd=wr;addr=a;data=x;toggle=~toggle;wait(ack==toggle);@(negedge clk);if(error)$fatal(1,"AXI error addr=%h",a);y=response;end endtask
 initial begin $readmemh("data/memory/classification_live/inputs.hex",inputs);$readmemh("data/memory/classification_live/expected_logits.hex",expected);repeat(5)@(negedge clk);rst_n=1;
  for(j=0;j<2;j=j+1)begin
   n=0;v=0;while(v!=1 && n<100000)begin cmd(0,12'h008,0,v);n=n+1;end if(v!=1)$fatal(1,"ready timeout");
   for(i=0;i<64;i=i+1)cmd(1,12'h100+i*4,inputs[j*64+i],v);
   cmd(1,12'h014,32'h98760000+j,v);cmd(1,12'h010,1,v);
   n=0;v=0;while(!v[3]&&n<50000)begin cmd(0,12'h008,0,v);if(v[4])$fatal(1,"job error");n=n+1;end if(!v[3])$fatal(1,"job timeout");
   cmd(0,12'h018,0,v);if(v!=32'h98760000+j)$fatal(1,"id mismatch");
   cmd(0,12'h040,0,v);if(v!==expected[j*4])$fatal(1,"logit0 mismatch");
   cmd(0,12'h044,0,v);if(v!==expected[j*4+1])$fatal(1,"logit1 mismatch");
   cmd(0,12'h048,0,v);if(v!==expected[j*4+2])$fatal(1,"logit2 mismatch");
   cmd(0,12'h04c,0,v);if(v!==expected[j*4+3])$fatal(1,"logit3 mismatch");
   cmd(0,12'h050,0,v);if(v!=44381)$fatal(1,"cycle mismatch");
   cmd(1,12'h010,2,v);$display("DYNAMIC_CLASS_CASE_PASS fixture=%d cycles=44381",j);
  end
  if(trap||fault)$fatal(1,"CPU fault");$display("DYNAMIC_CLASS_MASTER_PASS two_runtime_inputs");$finish;
 end
 initial begin #300000000;$fatal(1,"timeout");end
endmodule
