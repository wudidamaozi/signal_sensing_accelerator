`timescale 1ns/1ps

module int8_outer_product_4x4 #(
    parameter integer DATA_W = 8,
    parameter integer ACC_W  = 32,
    parameter integer ROWS   = 4,
    parameter integer COLS   = 4
) (
    input  wire                             clk,
    input  wire                             rst_n,

    input  wire                             start,
    output reg                              busy,
    output reg                              done,

    input  wire                             in_valid,
    output wire                             in_ready,
    input  wire                             in_last,
    input  wire [ROWS*DATA_W-1:0]           a_vec,
    input  wire [COLS*DATA_W-1:0]           b_vec,

    output reg  [ROWS*COLS*ACC_W-1:0]       c_mat,
    output reg  [31:0]                      total_cycles,
    output reg  [31:0]                      active_cycles
);

    wire signed [DATA_W-1:0] a_lane [0:ROWS-1];
    wire signed [DATA_W-1:0] b_lane [0:COLS-1];
    assign in_ready = busy;
    genvar r,c;
    generate
        for(r=0;r<ROWS;r=r+1)begin:row
            assign a_lane[r]=a_vec[r*DATA_W +: DATA_W];
            for(c=0;c<COLS;c=c+1)begin:col
                if(r==0)begin:input_lane
                    assign b_lane[c]=b_vec[c*DATA_W +: DATA_W];
                end
                if((r*COLS+c)<24)begin:dsp_lane
                    (* use_dsp="yes" *) reg signed [ACC_W-1:0] acc;
                    (* use_dsp="yes" *) wire signed [(2*DATA_W)-1:0] product=a_lane[r]*b_lane[c];
                    wire signed [ACC_W-1:0] extended={{(ACC_W-2*DATA_W){product[2*DATA_W-1]}},product};
                    always @(posedge clk)begin
                        if(!rst_n)begin acc<=0;c_mat[(r*COLS+c)*ACC_W +: ACC_W]<=0;end
                        else if(start && !busy)acc<=0;
                        else if(busy && in_valid && in_ready)begin
                            acc<=acc+extended;
                            if(in_last)c_mat[(r*COLS+c)*ACC_W +: ACC_W]<=acc+extended;
                        end
                    end
                end else begin:lut_lane
                    (* use_dsp="no" *) reg signed [ACC_W-1:0] acc;
                    (* use_dsp="no" *) wire signed [(2*DATA_W)-1:0] product=a_lane[r]*b_lane[c];
                    wire signed [ACC_W-1:0] extended={{(ACC_W-2*DATA_W){product[2*DATA_W-1]}},product};
                    always @(posedge clk)begin
                        if(!rst_n)begin acc<=0;c_mat[(r*COLS+c)*ACC_W +: ACC_W]<=0;end
                        else if(start && !busy)acc<=0;
                        else if(busy && in_valid && in_ready)begin
                            acc<=acc+extended;
                            if(in_last)c_mat[(r*COLS+c)*ACC_W +: ACC_W]<=acc+extended;
                        end
                    end
                end
            end
        end
    endgenerate
    always @(posedge clk)begin
        if(!rst_n)begin busy<=0;done<=0;total_cycles<=0;active_cycles<=0;end
        else begin
            done<=0;
            if(start && !busy)begin busy<=1;total_cycles<=0;active_cycles<=0;end
            else if(busy)begin
                total_cycles<=total_cycles+1'b1;
                if(in_valid && in_ready)begin
                    active_cycles<=active_cycles+1'b1;
                    if(in_last)begin busy<=0;done<=1;end
                end
            end
        end
    end
endmodule
