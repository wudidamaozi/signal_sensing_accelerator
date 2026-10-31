`timescale 1ns/1ps
// Current R14 HLS fixed fixture: firmware verifies all four logits twice.
module pynq_r14_hls_usb_top(input wire sys_clk_125);
 wire in_clk,clk,clk_raw,fb_raw,fb,locked; IBUF inbuf(.I(sys_clk_125),.O(in_clk));
 MMCME2_BASE #(.CLKIN1_PERIOD(8.0),.DIVCLK_DIVIDE(1),.CLKFBOUT_MULT_F(8.0),.CLKOUT0_DIVIDE_F(20.0),.STARTUP_WAIT("FALSE")) mmcm(.CLKIN1(in_clk),.CLKFBIN(fb),.CLKFBOUT(fb_raw),.CLKOUT0(clk_raw),.LOCKED(locked),.PWRDWN(1'b0),.RST(1'b0),.CLKFBOUTB(),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6());
 BUFG fbbuf(.I(fb_raw),.O(fb)); BUFG clkbuf(.I(clk_raw),.O(clk));
 wire reset_request; (* ASYNC_REG="TRUE" *) reg [1:0] lock_pipe=0;reg [1:0] reset_pipe=3;
 always @(posedge clk) begin lock_pipe<={lock_pipe[0],locked};if(!lock_pipe[1])reset_pipe<=3;else reset_pipe<={reset_pipe[0],reset_request};end
 wire rst_n=!reset_pipe[1];wire trap,host_write;wire[31:0]host_value;
 hls_picorv32_soc #(.MEM_INIT_FILE("data/memory/classification_hls4ml/hls_network.hex")) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.host_write(host_write),.host_value(host_value));
 reg [31:0] heartbeat=0,cycles0=0,cycles1=0,failure_code=0,frames_done=0;
 reg finished=0,failed=0,pending=0;reg[7:0] metric=0;reg seen0=0,seen1=0;
 always @(posedge clk)begin
  if(!rst_n)begin heartbeat<=0;cycles0<=0;cycles1<=0;failure_code<=0;frames_done<=0;finished<=0;failed<=0;pending<=0;metric<=0;seen0<=0;seen1<=0;end
  else begin heartbeat<=heartbeat+1;
   if(host_write&&!finished)begin
    if(pending)begin
     pending<=0;
     if(metric==14)begin cycles0<=host_value;seen0<=1;end
     if(metric==30)begin cycles1<=host_value;seen1<=1;end
    end else if(host_value[31:16]==16'ha500)begin pending<=1;metric<=host_value[7:0];end
    else begin finished<=1;failure_code<=host_value;
     if(host_value==1 && seen0 && seen1 && cycles0==46283 && cycles1==46283)frames_done<=2;
     else failed<=1;
    end
   end
  end
 end
 edgeai_o55_usb_vio debug_io(.clk(clk),.probe_out0(reset_request),.probe_in0(heartbeat),.probe_in1({27'd0,1'b0,trap,locked,failed,finished}),.probe_in2(failure_code),.probe_in3(frames_done),.probe_in4(cycles0),.probe_in5(cycles1),.probe_in6(32'd0),.probe_in7(32'd0),.probe_in8(32'd0),.probe_in9(32'd0));
endmodule
