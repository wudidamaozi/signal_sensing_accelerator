`timescale 1ns/1ps
module edgeai_o55_live_top(input wire sys_clk_125);
 wire in_clk,clk,clk_raw,fb_raw,fb,locked; IBUF inbuf(.I(sys_clk_125),.O(in_clk));
 MMCME2_BASE #(.CLKIN1_PERIOD(8.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(8.0),.CLKOUT0_DIVIDE_F(20.0),.STARTUP_WAIT("FALSE")) mmcm(.CLKIN1(in_clk),.CLKFBIN(fb),.CLKFBOUT(fb_raw),.CLKOUT0(clk_raw),.LOCKED(locked),.PWRDWN(1'b0),.RST(1'b0),.CLKFBOUTB(),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6());
 BUFG fbbuf(.I(fb_raw),.O(fb));BUFG clkbuf(.I(clk_raw),.O(clk));
 wire reset_request,command_toggle,command_write;wire[11:0] command_addr;wire[31:0] command_data;
 (* ASYNC_REG="TRUE" *) reg[1:0] lock_pipe=0;reg[1:0] reset_pipe=3;
 always @(posedge clk)begin lock_pipe<={lock_pipe[0],locked};if(!lock_pipe[1])reset_pipe<=3;else reset_pipe<={reset_pipe[0],reset_request};end
 wire rst_n=!reset_pipe[1];wire ack,error,trap,fault;wire[31:0]response;wire[11:0]awaddr,araddr;wire awvalid,awready,wvalid,wready,bvalid,bready,arvalid,arready,rvalid,rready;wire[31:0]wdata,rdata;wire[3:0]wstrb;wire[1:0]bresp,rresp;
 edgeai_vio_axi_master master(.clk(clk),.rst_n(rst_n),.command_toggle(command_toggle),.command_write(command_write),.command_addr(command_addr),.command_data(command_data),.acknowledge(ack),.response(response),.error(error),.awaddr(awaddr),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready),.araddr(araddr),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rready(rready));
 occupancy_service_soc #(.MEM_INIT_FILE("data/memory/occupancy_live/program.hex"),.JOB_TIMEOUT_CYCLES(60000000)) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.address_fault(fault),.host_valid(),.host_data(),.s_axi_awaddr(awaddr),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.irq());
 edgeai_live_vio vio(.clk(clk),.probe_out0(reset_request),.probe_out1(command_toggle),.probe_out2(command_write),.probe_out3(command_addr),.probe_out4(command_data),.probe_in0({27'd0,fault,trap,locked,error,ack}),.probe_in1(response));
endmodule
