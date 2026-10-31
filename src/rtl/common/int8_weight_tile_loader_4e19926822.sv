`timescale 1ns/1ps

// Gather one packed 4-channel weight word per K and output-channel tile.
// The frozen weight store is K-major with a configurable row stride. Firmware
// supplies only a starting word index and stride; this engine owns the weight
// read port and B write port until completion.
module int8_weight_tile_loader #(
    parameter integer MAX_N = 16,
    parameter integer MAX_K = 64,
    parameter integer WEIGHT_WORDS = 5808,
    parameter integer WEIGHT_ADDR_W = $clog2(WEIGHT_WORDS),
    parameter integer B_ADDR_W = $clog2(((MAX_N + 3) / 4) * MAX_K)
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] cfg_tile_n,
    input wire [7:0] cfg_tile_k,
    input wire [15:0] cfg_start_word,
    input wire [7:0] cfg_stride_words,
    output reg busy,
    output reg done,
    output reg error,
    output wire weight_rd_en,
    output wire [WEIGHT_ADDR_W-1:0] weight_rd_addr,
    input wire [31:0] weight_rd_data,
    output wire b_wr_en,
    output wire [B_ADDR_W-1:0] b_wr_addr,
    output wire [31:0] b_wr_data
);
    localparam [1:0] S_IDLE = 2'd0, S_READ = 2'd1, S_WRITE = 2'd2;
    reg [1:0] state;
    reg [2:0] column_tile;
    reg [7:0] local_k;
    reg [15:0] source_word;
    wire [7:0] column_count = (cfg_tile_n + 8'd3) >> 2;

    assign weight_rd_en = busy && state == S_READ && source_word < WEIGHT_WORDS;
    assign weight_rd_addr = source_word[WEIGHT_ADDR_W-1:0];
    assign b_wr_en = busy && state == S_WRITE;
    assign b_wr_addr = column_tile * MAX_K + local_k;
    assign b_wr_data = weight_rd_data;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            column_tile <= 3'd0;
            local_k <= 8'd0;
            source_word <= 16'd0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                error <= 1'b0;
                if (cfg_tile_n == 0 || cfg_tile_n > MAX_N
                    || cfg_tile_k == 0 || cfg_tile_k > MAX_K
                    || cfg_stride_words == 0
                    || cfg_start_word >= WEIGHT_WORDS) begin
                    error <= 1'b1;
                    done <= 1'b1;
                end else begin
                    column_tile <= 3'd0;
                    local_k <= 8'd0;
                    source_word <= cfg_start_word;
                    busy <= 1'b1;
                    state <= S_READ;
                end
            end else if (busy) begin
                case (state)
                    S_READ: begin
                        if (source_word >= WEIGHT_WORDS) begin
                            error <= 1'b1;
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            state <= S_WRITE;
                        end
                    end
                    S_WRITE: begin
                        if (local_k + 8'd1 == cfg_tile_k) begin
                            local_k <= 8'd0;
                            if (column_tile + 3'd1 == column_count) begin
                                done <= 1'b1;
                                busy <= 1'b0;
                                state <= S_IDLE;
                            end else begin
                                column_tile <= column_tile + 3'd1;
                                source_word <= cfg_start_word + column_tile + 16'd1;
                                state <= S_READ;
                            end
                        end else begin
                            local_k <= local_k + 8'd1;
                            source_word <= source_word + cfg_stride_words;
                            state <= S_READ;
                        end
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
