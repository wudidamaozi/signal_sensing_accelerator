`timescale 1ns/1ps
// One read and one write outstanding. AW/W are captured independently.
module edgeai_axi_lite_bridge(
    input wire clk,input wire rst_n,
    input wire [11:0] s_awaddr,input wire s_awvalid,output wire s_awready,
    input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wvalid,output wire s_wready,
    output reg [1:0] s_bresp,output reg s_bvalid,input wire s_bready,
    input wire [11:0] s_araddr,input wire s_arvalid,output wire s_arready,
    output reg [31:0] s_rdata,output reg [1:0] s_rresp,output reg s_rvalid,input wire s_rready,
    output wire h_valid,output wire h_write,output wire [11:0] h_addr,
    output wire [31:0] h_wdata,output wire [3:0] h_wstrb,
    input wire h_ready,input wire [31:0] h_rdata,input wire h_error
);
    reg aw_hold=0,w_hold=0,ar_hold=0;
    reg [11:0] aw_address=0,ar_address=0;
    reg [31:0] w_data=0;reg [3:0] w_strobe=0;
    wire write_request=aw_hold && w_hold && !s_bvalid;
    wire read_request=ar_hold && !s_rvalid && !write_request;
    assign s_awready=rst_n && !aw_hold && !s_bvalid;
    assign s_wready=rst_n && !w_hold && !s_bvalid;
    assign s_arready=rst_n && !ar_hold && !s_rvalid;
    assign h_valid=rst_n && (write_request||read_request);
    assign h_write=write_request;
    assign h_addr=write_request?aw_address:ar_address;
    assign h_wdata=w_data;assign h_wstrb=w_strobe;
    always @(posedge clk)begin
        if(!rst_n)begin
            aw_hold<=0;w_hold<=0;ar_hold<=0;s_bvalid<=0;s_rvalid<=0;
            s_bresp<=0;s_rresp<=0;s_rdata<=0;
        end else begin
            if(s_bvalid && s_bready)s_bvalid<=0;
            if(s_rvalid && s_rready)s_rvalid<=0;
            if(s_awvalid && s_awready)begin aw_hold<=1;aw_address<=s_awaddr;end
            if(s_wvalid && s_wready)begin w_hold<=1;w_data<=s_wdata;w_strobe<=s_wstrb;end
            if(s_arvalid && s_arready)begin ar_hold<=1;ar_address<=s_araddr;end
            if(h_valid && h_ready)begin
                if(write_request)begin aw_hold<=0;w_hold<=0;s_bvalid<=1;s_bresp<=h_error?2'b10:2'b00;end
                else begin ar_hold<=0;s_rvalid<=1;s_rdata<=h_rdata;s_rresp<=h_error?2'b10:2'b00;end
            end
        end
    end
endmodule
