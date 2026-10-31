`timescale 1ns/1ps

module int8_requantize_relu (
    input  wire               clk,
    input  wire               rst_n,

    input  wire               in_valid,
    output wire               in_ready,
    input  wire signed [31:0] mac_value,
    input  wire signed [31:0] bias_value,
    input  wire [4:0]         right_shift,
    input  wire               relu_enable,

    output reg                out_valid,
    input  wire               out_ready,
    output reg signed [7:0]   out_value,
    output reg                saturated
);

    reg stage1_valid;
    reg signed [32:0] stage1_sum;
    reg [4:0] stage1_right_shift;
    reg stage1_relu_enable;

    reg stage2_valid;
    reg [32:0] stage2_magnitude;
    reg stage2_negative;
    reg stage2_relu_enable;

    reg [32:0] magnitude_comb;
    reg [32:0] rounded_magnitude_comb;
    reg signed [7:0] result_comb;
    reg saturation_comb;
    reg signed [8:0] negative_result_comb;

    wire output_stage_ready = !out_valid || out_ready;
    wire stage2_ready = !stage2_valid || output_stage_ready;
    wire stage1_ready = !stage1_valid || stage2_ready;
    assign in_ready = stage1_ready;

    always @* begin
        if (stage1_sum < 0)
            magnitude_comb = (~stage1_sum) + 1'b1;
        else
            magnitude_comb = stage1_sum[32:0];

        if (stage1_right_shift == 0)
            rounded_magnitude_comb = magnitude_comb;
        else
            rounded_magnitude_comb =
                (magnitude_comb + (33'd1 << (stage1_right_shift - 1'b1)))
                >> stage1_right_shift;

    end

    always @* begin
        negative_result_comb = -$signed({1'b0, stage2_magnitude[7:0]});
        result_comb = stage2_magnitude[7:0];
        saturation_comb = 1'b0;
        if (stage2_relu_enable && stage2_negative) begin
            result_comb = 8'sd0;
        end else if (!stage2_negative && (stage2_magnitude > 33'd127)) begin
            result_comb = 8'sd127;
            saturation_comb = 1'b1;
        end else if (stage2_negative && (stage2_magnitude > 33'd128)) begin
            result_comb = -8'sd128;
            saturation_comb = 1'b1;
        end else if (stage2_negative) begin
            result_comb = negative_result_comb[7:0];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            stage1_sum <= 33'sd0;
            stage1_right_shift <= 5'd0;
            stage1_relu_enable <= 1'b0;
            stage2_valid <= 1'b0;
            stage2_magnitude <= 33'd0;
            stage2_negative <= 1'b0;
            stage2_relu_enable <= 1'b0;
            out_valid <= 1'b0;
            out_value <= 8'sd0;
            saturated <= 1'b0;
        end else begin
            if (output_stage_ready) begin
                out_valid <= stage2_valid;
                if (stage2_valid) begin
                    out_value <= result_comb;
                    saturated <= saturation_comb;
                end
            end

            if (stage2_ready) begin
                stage2_valid <= stage1_valid;
                if (stage1_valid) begin
                    stage2_magnitude <= rounded_magnitude_comb;
                    stage2_negative <= stage1_sum < 0;
                    stage2_relu_enable <= stage1_relu_enable;
                end
            end

            if (stage1_ready) begin
                stage1_valid <= in_valid;
                if (in_valid) begin
                    stage1_sum <= {mac_value[31], mac_value}
                        + {bias_value[31], bias_value};
                    stage1_right_shift <= right_shift;
                    stage1_relu_enable <= relu_enable;
                end
            end
        end
    end

endmodule
