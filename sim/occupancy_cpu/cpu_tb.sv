`timescale 1ns/1ps
module cpu_tb;reg clk=0;always #10 clk=~clk;reg rst_n=0;initial #100 rst_n=1;wire trap,hv;wire[31:0] hd;

wire[11:0] awaddr,araddr;wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;wire[31:0] wdata,rdata;wire[3:0] wstrb;wire[1:0] bresp,rresp;wire failed,finished;wire[31:0] failure_code,frames_done,cycles0,cycles1,l0,l1,l2,l3;
pynq_o55_jtag_stimulus master(.clk(clk),.rst_n(rst_n),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),.araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rready(rready),.finished(finished),.failed(failed),.failure_code(failure_code),.frames_done(frames_done),.cycles0(cycles0),.cycles1(cycles1),.logits00(l0),.logits01(l1),.logits10(l2),.logits11(l3));
occupancy_service_soc #(.MEM_INIT_FILE("data/memory/occupancy_cpu/program.hex"),.JOB_TIMEOUT_CYCLES(60000000)) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.address_fault(),.host_valid(hv),.host_data(hd),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq());
always @(posedge clk)if(finished)begin if(failed||trap)$fatal(1,"CPU_OCC_FAIL %h",failure_code);$display("CPU_SIM_PASS cycles0=%0d cycles1=%0d",cycles0,cycles1);$finish;end

reg pending=0;reg[7:0] metric=0;
always @(posedge clk)begin
 if(trap)$fatal(1,"CPU_TRAP");
 if(hv)begin
  if(pending)begin $display("CPU_METRIC %0d %0d",metric,hd);pending<=0;end
  else if(hd[31:16]==16'ha500)begin metric<=hd[7:0];pending<=1;end
  else if(hd==1)begin $display("CPU_SIM_PASS");$finish;end
  else if(hd[31:16]==16'hdead)$fatal(1,"CPU_FAIL %h",hd);
 end
end
initial begin #(64'd5000000000);$fatal(1,"CPU_TIMEOUT");end
endmodule
