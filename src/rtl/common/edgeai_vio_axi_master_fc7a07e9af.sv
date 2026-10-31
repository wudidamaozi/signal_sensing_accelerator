`timescale 1ns/1ps
// One outstanding VIO command; payload remains stable until ack equals request.
module edgeai_vio_axi_master(
 input wire clk,rst_n, input wire command_toggle,command_write,
 input wire [11:0] command_addr, input wire [31:0] command_data,
 output reg acknowledge, output reg [31:0] response, output reg error,
 output reg [11:0] awaddr, output reg awvalid, input wire awready,
 output reg [31:0] wdata, output wire [3:0] wstrb, output reg wvalid,
 input wire wready, input wire [1:0] bresp, input wire bvalid, output reg bready,
 output reg [11:0] araddr, output reg arvalid, input wire arready,
 input wire [31:0] rdata, input wire [1:0] rresp, input wire rvalid, output reg rready
);
 assign wstrb=4'hf;
 localparam IDLE=0,WSEND=1,WRESP=2,RSEND=3,RRESP=4;
 reg [2:0] state=IDLE;reg active_toggle=0;
 always @(posedge clk) begin
  if(!rst_n)begin state<=IDLE;acknowledge<=0;active_toggle<=0;response<=0;error<=0;awaddr<=0;awvalid<=0;wdata<=0;wvalid<=0;bready<=0;araddr<=0;arvalid<=0;rready<=0;end
  else case(state)
   IDLE:if(command_toggle!=acknowledge)begin
    active_toggle<=command_toggle;error<=0;
    if(command_write)begin awaddr<=command_addr;wdata<=command_data;awvalid<=1;wvalid<=1;state<=WSEND;end
    else begin araddr<=command_addr;arvalid<=1;state<=RSEND;end
   end
   WSEND:begin
    if(awvalid&&awready)awvalid<=0;if(wvalid&&wready)wvalid<=0;
    if((!awvalid||awready)&&(!wvalid||wready))begin bready<=1;state<=WRESP;end
   end
   WRESP:if(bvalid&&bready)begin bready<=0;error<=bresp!=0;response<=0;acknowledge<=active_toggle;state<=IDLE;end
   RSEND:if(arvalid&&arready)begin arvalid<=0;rready<=1;state<=RRESP;end
   RRESP:if(rvalid&&rready)begin rready<=0;error<=rresp!=0;response<=rdata;acknowledge<=active_toggle;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
