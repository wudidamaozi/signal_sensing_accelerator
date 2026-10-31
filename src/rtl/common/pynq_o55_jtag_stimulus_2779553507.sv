`timescale 1ns/1ps
// Synthesizable fixed-fixture AXI master. No CPU/PS, SD, network or JTAG host in the timed interval.
module pynq_o55_jtag_stimulus #(
 parameter INPUT_FILE="data/memory/classification_live/inputs.hex", parameter EXPECTED_FILE="data/memory/classification_live/expected_logits.hex"
)(
 input wire clk, input wire rst_n,
 output reg [11:0] awaddr, output reg awvalid, input wire awready,
 output reg [31:0] wdata, output wire [3:0] wstrb, output reg wvalid, input wire wready,
 input wire [1:0] bresp, input wire bvalid, output reg bready,
 output reg [11:0] araddr, output reg arvalid, input wire arready,
 input wire [31:0] rdata, input wire [1:0] rresp, input wire rvalid, output reg rready,
 output reg finished, output reg failed, output reg [31:0] failure_code,
 output reg [31:0] frames_done, output reg [31:0] cycles0, cycles1,
 output reg [31:0] logits00, logits01, logits10, logits11
);
 reg [31:0] inputs[0:127]; reg [31:0] expected[0:7];
 initial begin $readmemh(INPUT_FILE,inputs); $readmemh(EXPECTED_FILE,expected); end
 assign wstrb=4'hf;
 localparam E_IDLE=0,E_W_SEND=1,E_W_RESP=2,E_R_SEND=3,E_R_RESP=4;
 reg [2:0] engine=E_IDLE; reg req=0,req_write=0; reg [11:0] req_addr=0;reg [31:0] req_data=0;
 reg transaction_done=0,transaction_error=0;reg [31:0] response=0;
 always @(posedge clk) begin
  if(!rst_n)begin engine<=E_IDLE;awvalid<=0;wvalid<=0;bready<=0;arvalid<=0;rready<=0;transaction_done<=0;transaction_error<=0;response<=0;awaddr<=0;araddr<=0;wdata<=0;end
  else begin
   transaction_done<=0;
   case(engine)
    E_IDLE:if(req)begin transaction_error<=0;
     if(req_write)begin awaddr<=req_addr;wdata<=req_data;awvalid<=1;wvalid<=1;engine<=E_W_SEND;end
     else begin araddr<=req_addr;arvalid<=1;engine<=E_R_SEND;end
    end
    E_W_SEND:begin
     if(awvalid&&awready)awvalid<=0;
     if(wvalid&&wready)wvalid<=0;
     if((!awvalid||awready)&&(!wvalid||wready))begin bready<=1;engine<=E_W_RESP;end
    end
    E_W_RESP:if(bvalid&&bready)begin bready<=0;transaction_error<=bresp!=0;transaction_done<=1;engine<=E_IDLE;end
    E_R_SEND:if(arvalid&&arready)begin arvalid<=0;rready<=1;engine<=E_R_RESP;end
    E_R_RESP:if(rvalid&&rready)begin response<=rdata;rready<=0;transaction_error<=rresp!=0;transaction_done<=1;engine<=E_IDLE;end
    default:engine<=E_IDLE;
   endcase
  end
 end
 localparam H_READY_REQ=0,H_READY_CHECK=1,H_SIZE=2,H_UPLOAD=3,H_ID=4,H_START=5,H_POLL_REQ=6,H_POLL_CHECK=7,
 H_ID_REQ=8,H_ID_CHECK=9,H_L0_REQ=10,H_L0_CHECK=11,H_L1_REQ=12,H_L1_CHECK=13,H_CYCLE_REQ=14,H_CYCLE_CHECK=15,
 H_ACK=16,H_ADVANCE=17,H_WAIT=18,H_FINISH=19,H_L2_REQ=20,H_L2_CHECK=21,H_L3_REQ=22,H_L3_CHECK=23;
 reg [5:0] state=H_READY_REQ,after=H_READY_REQ;reg [6:0] index=0;reg fixture=0;
 reg [31:0] timeout=0;
 task issue(input write_op,input [11:0] address,input [31:0] data,input [5:0] next_state);
 begin req<=1;req_write<=write_op;req_addr<=address;req_data<=data;after<=next_state;state<=H_WAIT;end endtask
 task fail(input [31:0] code);begin failed<=1;finished<=1;failure_code<=code;state<=H_FINISH;end endtask
 always @(posedge clk)begin
  if(!rst_n)begin state<=H_READY_REQ;req<=0;after<=H_READY_REQ;index<=0;fixture<=0;finished<=0;failed<=0;failure_code<=0;frames_done<=0;cycles0<=0;cycles1<=0;logits00<=0;logits01<=0;logits10<=0;logits11<=0;timeout<=0;end
  else begin
   req<=0;
   if(!finished)timeout<=timeout+1;
   if(timeout==32'd50000000 && !finished)fail(32'hff);
   else case(state)
    H_READY_REQ:issue(0,12'h008,0,H_READY_CHECK);
    H_READY_CHECK:if(response==1)state<=H_SIZE;else state<=H_READY_REQ;
    H_SIZE:state<=H_UPLOAD;
    H_UPLOAD:begin issue(1,12'h100+({5'd0,index}<<2),inputs[{fixture,index[5:0]}],index==63?H_ID:H_UPLOAD);if(index==63)index<=0;else index<=index+1;end
    H_ID:issue(1,12'h014,32'h60000001+fixture,H_START);
    H_START:issue(1,12'h010,1,H_POLL_REQ);
    H_POLL_REQ:issue(0,12'h008,0,H_POLL_CHECK);
    H_POLL_CHECK:if(response[4])fail(32'h10);else if(response[3])state<=H_ID_REQ;else state<=H_POLL_REQ;
    H_ID_REQ:issue(0,12'h018,0,H_ID_CHECK);
    H_ID_CHECK:if(response!=32'h60000001+fixture)fail(32'h11);else state<=H_L0_REQ;
    H_L0_REQ:issue(0,12'h040,0,H_L0_CHECK);
    H_L0_CHECK:begin if(!fixture)logits00<=response;else logits10<=response;if(response!==expected[{fixture,2'b00}])fail(32'h20);else state<=H_L1_REQ;end
    H_L1_REQ:issue(0,12'h044,0,H_L1_CHECK);
    H_L1_CHECK:begin if(!fixture)logits01<=response;else logits11<=response;if(response!==expected[{fixture,2'b01}])fail(32'h21);else state<=H_L2_REQ;end
    H_L2_REQ:issue(0,12'h048,0,H_L2_CHECK);
    H_L2_CHECK:if(response!==expected[{fixture,2'b10}])fail(32'h22);else state<=H_L3_REQ;
    H_L3_REQ:issue(0,12'h04c,0,H_L3_CHECK);
    H_L3_CHECK:if(response!==expected[{fixture,2'b11}])fail(32'h23);else state<=H_CYCLE_REQ;
    H_CYCLE_REQ:issue(0,12'h050,0,H_CYCLE_CHECK);
    H_CYCLE_CHECK:begin if(!fixture)cycles0<=response;else cycles1<=response;if(response!=44381)fail(32'h30);else state<=H_ACK;end
    H_ACK:issue(1,12'h010,2,H_ADVANCE);
    H_ADVANCE:begin frames_done<=frames_done+1;if(fixture)begin finished<=1;state<=H_FINISH;end else begin fixture<=1;state<=H_READY_REQ;end end
    H_WAIT:if(transaction_done)begin if(transaction_error)fail(32'h40);else state<=after;end
    H_FINISH:state<=H_FINISH;
    default:fail(32'hfe);
   endcase
  end
 end
endmodule
