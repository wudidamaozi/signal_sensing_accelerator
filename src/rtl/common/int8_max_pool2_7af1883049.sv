`timescale 1ns/1ps

module int8_max_pool2 (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 in_valid,
    output wire                 in_ready,
    input  wire signed [7:0]    value_even,
    input  wire signed [7:0]    value_odd,

    output reg                  out_valid,
    input  wire                 out_ready,
    output reg signed [7:0]     out_value
);

    assign in_ready = !out_valid || out_ready;

    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_value <= 8'sd0;
        end else if (in_ready) begin
            out_valid <= in_valid;
            if (in_valid)
                out_value <= ($signed(value_even) >= $signed(value_odd))
                    ? value_even : value_odd;
        end
    end

endmodule
