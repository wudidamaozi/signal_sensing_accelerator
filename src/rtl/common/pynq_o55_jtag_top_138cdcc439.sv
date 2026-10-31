`timescale 1ns/1ps
// PYNQ-Z2 PL-only test: 125MHz board oscillator -> MMCM50MHz, VIO reset/readback.
// No PS boot, SD card, Ethernet, Flash write or external host needed during inference.
module pynq_o55_jtag_top(input wire sys_clk_125);
 wire in_clk,clk,clk_raw,fb_raw,fb,locked; IBUF inbuf(.I(sys_clk_125),.O(in_clk));
 MMCME2_BASE #(.CLKIN1_PERIOD(8.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(8.0),.CLKOUT0_DIVIDE_F(20.0),.STARTUP_WAIT("FALSE")) mmcm(
  .CLKIN1(in_clk),.CLKFBIN(fb),.CLKFBOUT(fb_raw),.CLKOUT0(clk_raw),.LOCKED(locked),.PWRDWN(1'b0),.RST(1'b0),
  .CLKFBOUTB(),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6());
 BUFG fbbuf(.I(fb_raw),.O(fb)); BUFG clkbuf(.I(clk_raw),.O(clk));
 wire reset_request;(* ASYNC_REG="TRUE" *) reg [1:0] lock_pipe=2'b00;
 reg [1:0] reset_pipe=2'b11;
 // Keep RAM-control reset fully synchronous; initial state holds reset until
 // the MMCM LOCKED indication has passed the two-flop synchronizer.
 always @(posedge clk)begin
  lock_pipe<={lock_pipe[0],locked};
  if(!lock_pipe[1])reset_pipe<=2'b11;else reset_pipe<={reset_pipe[0],reset_request};
 end
 wire rst_n=!reset_pipe[1];
 wire[11:0] awaddr,araddr;wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;
 wire[31:0] wdata,rdata;wire[3:0]wstrb;wire[1:0]bresp,rresp;
 wire finished,failed,trap,address_fault;wire[31:0] failure_code,frames_done,cycles0,cycles1,logits00,logits01,logits10,logits11;
 reg [31:0] heartbeat=0;always @(posedge clk)if(!rst_n)heartbeat<=0;else heartbeat<=heartbeat+1;
 pynq_o55_jtag_stimulus master(.clk(clk),.rst_n(rst_n),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),.araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rready(rready),.finished(finished),.failed(failed),.failure_code(failure_code),.frames_done(frames_done),.cycles0(cycles0),.cycles1(cycles1),.logits00(logits00),.logits01(logits01),.logits10(logits10),.logits11(logits11));
 occupancy_service_soc #(.MEM_INIT_FILE("data/memory/occupancy_hls4ml/program.hex"),.JOB_TIMEOUT_CYCLES(60000000)) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.address_fault(address_fault),.host_valid(),.host_data(),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq());
 edgeai_o55_usb_vio debug_io(.clk(clk),.probe_out0(reset_request),.probe_in0(heartbeat),
  .probe_in1({27'd0,address_fault,trap,locked,failed,finished}),.probe_in2(failure_code),.probe_in3(frames_done),
  .probe_in4(cycles0),.probe_in5(cycles1),.probe_in6(logits00),.probe_in7(logits01),.probe_in8(logits10),.probe_in9(logits11));
endmodule
