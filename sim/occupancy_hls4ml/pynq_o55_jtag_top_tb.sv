`timescale 1ns/1ps
module edgeai_o55_usb_vio(input wire clk,input wire[31:0] probe_in0,probe_in1,probe_in2,probe_in3,probe_in4,probe_in5,probe_in6,probe_in7,probe_in8,probe_in9,output reg probe_out0=1);
 initial begin #1000;probe_out0=0;end
endmodule
module pynq_o55_jtag_top_tb;
 reg sys_clk_125=0;always #4 sys_clk_125=~sys_clk_125;
 pynq_o55_jtag_top dut(.sys_clk_125(sys_clk_125));
 initial begin wait(dut.finished);#1;
  if(dut.failed || dut.trap || dut.address_fault || dut.frames_done!=2 || dut.cycles0!=37552 || dut.cycles1!=37552)$fatal(1,"USB_TOP_FAIL code=%h frames=%d cycles=%d/%d",dut.failure_code,dut.frames_done,dut.cycles0,dut.cycles1);
  $display("USB_TOP_FIRST_PASS frames=%0d cycles0=%0d cycles1=%0d logits=%h,%h,%h,%h",dut.frames_done,dut.cycles0,dut.cycles1,dut.logits00,dut.logits01,dut.logits10,dut.logits11);
  force dut.reset_request=1'b1;repeat(6)@(posedge dut.clk);#1;
  if(dut.finished || dut.frames_done!=0)$fatal(1,"USB_TOP_RESET_FAILED");
  release dut.reset_request;wait(dut.finished);#1;
  if(dut.failed || dut.trap || dut.address_fault || dut.frames_done!=2 || dut.cycles0!=37552 || dut.cycles1!=37552)$fatal(1,"USB_TOP_REPLAY_FAIL code=%h",dut.failure_code);
  $display("USB_TOP_PASS frames=%0d cycles0=%0d cycles1=%0d logits=%h,%h,%h,%h reset_replay=1",dut.frames_done,dut.cycles0,dut.cycles1,dut.logits00,dut.logits01,dut.logits10,dut.logits11);$finish;end
 initial begin #300000000;$fatal(1,"USB_TOP_TIMEOUT locked=%b reset=%b state=%d",dut.locked,dut.rst_n,dut.master.state);end
endmodule
