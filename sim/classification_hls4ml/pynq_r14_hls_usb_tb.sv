`timescale 1ns/1ps
module edgeai_o55_usb_vio(input wire clk,input wire[31:0] probe_in0,probe_in1,probe_in2,probe_in3,probe_in4,probe_in5,probe_in6,probe_in7,probe_in8,probe_in9,output reg probe_out0=1);
 initial begin #1000;probe_out0=0;end
endmodule
module pynq_r14_hls_usb_tb;
 reg sys_clk_125=0;always #4 sys_clk_125=~sys_clk_125;
 pynq_r14_hls_usb_top dut(.sys_clk_125(sys_clk_125));
 initial begin wait(dut.finished);#1;
 if(dut.failed||dut.trap||dut.frames_done!=2||dut.cycles0!=46283||dut.cycles1!=46283)$fatal(1,"HLS_BOARD_TOP_FAIL result=%h cycles=%d/%d",dut.failure_code,dut.cycles0,dut.cycles1);
 $display("R14_HLS_USB_TOP_PASS calls=2 cycles0=%0d cycles1=%0d firmware_verified_all_logits",dut.cycles0,dut.cycles1);$finish;end
 initial begin #100000000;$fatal(1,"HLS_BOARD_TOP_TIMEOUT");end
endmodule
