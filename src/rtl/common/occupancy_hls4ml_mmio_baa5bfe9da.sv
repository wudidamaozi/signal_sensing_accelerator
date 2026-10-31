`timescale 1ns/1ps

// Occupancy hls4ml stream adapter; canonical 256-byte IQ input, two INT32 outputs. CPU inputs retain the same channel-major
// 256-byte IQ layout as the shared accelerator; the bridge interleaves I/Q.
module occupancy_hls4ml_mmio (
    input wire clk, rst_n,
    input wire bus_valid,
    input wire [15:0] bus_addr,
    input wire [31:0] bus_wdata,
    input wire [3:0] bus_wstrb,
    output reg bus_ready,
    output reg [31:0] bus_rdata
);
    (* ram_style="distributed" *) reg [31:0] input_i [0:31];
    (* ram_style="distributed" *) reg [31:0] input_q [0:31];
    reg [31:0] output_words [0:1];
    reg [63:0] input_written;
    reg busy, done, error, start;
    reg [7:0] sent;
    reg [31:0] cycles;
    wire input_window=bus_addr>=16'h1000 && bus_addr<16'h1100;
    wire output_window=bus_addr>=16'h2000 && bus_addr<16'h2008 && bus_addr[1:0]==0;
    wire [5:0] input_word=(bus_addr-16'h1000)>>2;
    wire [31:0] i_word=input_i[sent[6:2]];
    wire [31:0] q_word=input_q[sent[6:2]];
    wire [15:0] stream_input={q_word[sent[1:0]*8+:8],i_word[sent[1:0]*8+:8]};
    wire stream_input_valid=busy && sent<128;
    wire stream_input_ready, stream_output_valid, hls_done, hls_ready, hls_idle;
    wire [63:0] stream_output;
    integer channel;

    occupancy_hls4ml kernel(
        .ap_clk(clk),.ap_rst_n(rst_n),.ap_start(start),
        .iq_V_TDATA(stream_input),.iq_V_TVALID(stream_input_valid),.iq_V_TREADY(stream_input_ready),
        .layer9_out_V_TDATA(stream_output),.layer9_out_V_TVALID(stream_output_valid),.layer9_out_V_TREADY(busy),
        .ap_done(hls_done),.ap_ready(hls_ready),.ap_idle(hls_idle));

    always @(posedge clk) begin
        if (!rst_n) begin
            bus_ready<=0; bus_rdata<=0; input_written<=0;
            busy<=0; done<=0; error<=0; start<=0; sent<=0; cycles<=0;
            for(channel=0;channel<2;channel=channel+1)output_words[channel]<=0;
        end else begin
            bus_ready<=0;
            if(start && hls_ready)start<=0;
            if(busy)cycles<=cycles+1;
            if(stream_input_valid && stream_input_ready)sent<=sent+1;
            if(busy && stream_output_valid)begin
                if(sent!=128)error<=1;
                for(channel=0;channel<2;channel=channel+1)output_words[channel]<=stream_output[channel*32+:32];
                busy<=0; done<=1;
            end
            if(bus_valid && !bus_ready)begin
                bus_ready<=1;
                if(bus_wstrb!=0)begin
                    if(bus_wstrb!=4'b1111 || bus_addr[1:0]!=0)error<=1;
                    else if(input_window)begin
                        if(busy)error<=1;
                        else begin
                            if(input_word[5])input_q[input_word[4:0]]<=bus_wdata;
                            else input_i[input_word[4:0]]<=bus_wdata;
                            input_written[input_word]<=1;
                        end
                    end else if(bus_addr==0)begin
                        if(busy)error<=1;
                        else if(bus_wdata[0])begin
                            if(input_written!=64'hffffffffffffffff)begin error<=1;done<=1;end
                            else begin
                                busy<=1; done<=0; error<=0; start<=1; sent<=0; cycles<=0;
                            end
                        end else if(bus_wdata[1])begin done<=0;error<=0;end
                    end else error<=1;
                end else if(bus_addr==16'h0004)bus_rdata<={29'd0,error,done,busy};
                else if(bus_addr==16'h0008)bus_rdata<=cycles;
                else if(bus_addr==16'h000c)bus_rdata<=sent;
                else if(output_window)begin
                    if(busy)begin error<=1;bus_rdata<=0;end
                    else bus_rdata<=output_words[bus_addr[3:2]];
                end else if(input_window && !busy)begin
                    bus_rdata<=input_word[5]?input_q[input_word[4:0]]:input_i[input_word[4:0]];
                end else begin error<=1;bus_rdata<=0;end
            end
        end
    end
endmodule
