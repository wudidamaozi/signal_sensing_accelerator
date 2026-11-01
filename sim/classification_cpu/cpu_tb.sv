`timescale 1ns/1ps
module cpu_tb;reg clk=0;always #10 clk=~clk;reg rst_n=0;initial #100 rst_n=1;wire trap,hv;wire[31:0] hd;
picorv32_accel_soc #(.MEM_WORDS(32768),.MEM_INIT_FILE("data/memory/classification_cpu/full_network.hex")) dut(.clk(clk),.rst_n(rst_n),.trap(trap),.host_write(hv),.host_value(hd));
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
