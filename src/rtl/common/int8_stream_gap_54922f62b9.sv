`timescale 1ns/1ps

// Consumes quantized post-process output as it is produced. The source tensor
// can optionally be kept in Q for layer-by-layer verification.
module int8_stream_gap #(
    parameter integer Q_BYTES = 8192,
    parameter integer MAX_CHANNELS = 64,
    parameter integer Q_ADDR_W = $clog2(Q_BYTES),
    parameter integer CH_W = $clog2(MAX_CHANNELS + 1)
) (
    input wire clk,
    input wire rst_n,
    input wire clear,
    input wire enable,
    input wire finalize,
    input wire [Q_ADDR_W-1:0] cfg_source_base,
    input wire [Q_ADDR_W-1:0] cfg_dest_base,
    input wire [2:0] cfg_length_log2,
    input wire [CH_W-1:0] cfg_channels,
    input wire in_valid,
    input wire [Q_ADDR_W-1:0] in_addr,
    input wire [CH_W-1:0] in_channel,
    input wire signed [7:0] in_data,
    output reg busy,
    output reg done,
    output reg error,
    output wire out_wr_en,
    output wire [Q_ADDR_W-1:0] out_wr_addr,
    output wire [7:0] out_wr_data
);
    // A valid bit marks an initialized channel. Clearing the small bitmap
    // avoids a reset/clear network across every sum and count register.
    reg [MAX_CHANNELS-1:0] channel_valid;
    reg [13:0] sums [0:MAX_CHANNELS-1];
    reg [7:0] counts [0:MAX_CHANNELS-1];
    reg [CH_W-1:0] output_channel;
    wire [7:0] length = 8'd1 << cfg_length_log2;
    wire [Q_ADDR_W:0] source_span = cfg_channels << cfg_length_log2;
    wire [Q_ADDR_W:0] delta = {1'b0, in_addr} - {1'b0, cfg_source_base};
    wire source_valid = in_addr >= cfg_source_base && delta < source_span;
    wire [7:0] input_count = channel_valid[in_channel]
        ? counts[in_channel] : 8'd0;
    wire [13:0] input_sum = channel_valid[in_channel]
        ? sums[in_channel] : 14'd0;
    wire [13:0] rounded_sum = sums[output_channel]
        + (14'd1 << (cfg_length_log2 - 1'b1));

    assign out_wr_en = busy && !error && channel_valid[output_channel]
        && counts[output_channel] == length;
    assign out_wr_addr = cfg_dest_base + output_channel;
    assign out_wr_data = rounded_sum >> cfg_length_log2;

    always @(posedge clk) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            output_channel <= {CH_W{1'b0}};
            channel_valid <= {MAX_CHANNELS{1'b0}};
        end else begin
            done <= 1'b0;
            if (clear) begin
                busy <= 1'b0;
                error <= 1'b0;
                output_channel <= {CH_W{1'b0}};
                channel_valid <= {MAX_CHANNELS{1'b0}};
                if (cfg_length_log2 == 0 || cfg_length_log2 > 7
                    || cfg_channels == 0 || cfg_channels > MAX_CHANNELS
                    || ({1'b0, cfg_source_base} + source_span > Q_BYTES)
                    || ({1'b0, cfg_dest_base} + cfg_channels > Q_BYTES))
                    error <= 1'b1;
            end else if (busy) begin
                if (!channel_valid[output_channel]
                    || counts[output_channel] != length)
                    error <= 1'b1;
                if (output_channel + 1'b1 == cfg_channels) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else
                    output_channel <= output_channel + 1'b1;
            end else if (finalize) begin
                if (!enable || error)
                    error <= 1'b1;
                else begin
                    busy <= 1'b1;
                    output_channel <= {CH_W{1'b0}};
                end
            end else if (in_valid && enable) begin
                if (!source_valid || in_channel >= cfg_channels
                    || in_data[7] || input_count >= length)
                    error <= 1'b1;
                // The channel comes directly from the post-process scheduler.
                // Keep address validation off the accumulator write-enable path.
                if (in_channel < cfg_channels && !in_data[7]
                    && input_count < length) begin
                    sums[in_channel] <= input_sum + {6'd0, in_data[7:0]};
                    counts[in_channel] <= input_count + 1'b1;
                    channel_valid[in_channel] <= 1'b1;
                end
            end
        end
    end
endmodule
