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
    (* use_dsp = "yes" *)
    reg  signed [ACC_W-1:0]  accumulator [0:ROWS-1][0:COLS-1];

    genvar lane_index;
    generate
        for (lane_index = 0; lane_index < ROWS; lane_index = lane_index + 1) begin : gen_a_lanes
            assign a_lane[lane_index] = a_vec[lane_index*DATA_W +: DATA_W];
        end
        for (lane_index = 0; lane_index < COLS; lane_index = lane_index + 1) begin : gen_b_lanes
            assign b_lane[lane_index] = b_vec[lane_index*DATA_W +: DATA_W];
        end
    endgenerate

    assign in_ready = busy;

    function automatic signed [ACC_W-1:0] multiply_extended;
        input signed [DATA_W-1:0] lhs;
        input signed [DATA_W-1:0] rhs;
        reg   signed [(2*DATA_W)-1:0] product;
        begin
            product = lhs * rhs;
            multiply_extended = {{(ACC_W-(2*DATA_W)){product[(2*DATA_W)-1]}}, product};
        end
    endfunction

    integer row_index;
    integer column_index;
    always @(posedge clk) begin
        if (!rst_n) begin
            busy          <= 1'b0;
            done          <= 1'b0;
            c_mat         <= {(ROWS*COLS*ACC_W){1'b0}};
            total_cycles  <= 32'd0;
            active_cycles <= 32'd0;
            for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
                for (column_index = 0; column_index < COLS; column_index = column_index + 1) begin
                    accumulator[row_index][column_index] <= {ACC_W{1'b0}};
                end
            end
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy          <= 1'b1;
                total_cycles  <= 32'd0;
                active_cycles <= 32'd0;
                for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
                    for (column_index = 0; column_index < COLS; column_index = column_index + 1) begin
                        accumulator[row_index][column_index] <= {ACC_W{1'b0}};
                    end
                end
            end else if (busy) begin
                total_cycles <= total_cycles + 1'b1;

                if (in_valid && in_ready) begin
                    active_cycles <= active_cycles + 1'b1;
                    for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
                        for (column_index = 0; column_index < COLS; column_index = column_index + 1) begin
                            accumulator[row_index][column_index] <=
                                accumulator[row_index][column_index]
                                + multiply_extended(a_lane[row_index], b_lane[column_index]);

                            if (in_last) begin
                                c_mat[((row_index*COLS+column_index)*ACC_W) +: ACC_W] <=
                                    accumulator[row_index][column_index]
                                    + multiply_extended(a_lane[row_index], b_lane[column_index]);
                            end
                        end
                    end

                    if (in_last) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
