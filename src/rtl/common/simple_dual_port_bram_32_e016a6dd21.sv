`timescale 1ns/1ps

module simple_dual_port_bram_32 #(
    parameter integer DEPTH = 256,
    parameter integer ADDR_W = $clog2(DEPTH)
) (
    input  wire              clk,
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [31:0]       wr_data,
    input  wire              rd_en,
    input  wire [ADDR_W-1:0] rd_addr,
    output reg  [31:0]       rd_data
);

    (* ram_style = "block" *) reg [31:0] memory [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en)
            memory[wr_addr] <= wr_data;
    end

    always @(posedge clk) begin
        if (rd_en)
            rd_data <= memory[rd_addr];
    end

endmodule

