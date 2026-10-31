`timescale 1ns/1ps

module int8_layer_postprocess_controller #(
    parameter integer PIPELINED = 0,
    parameter integer MAX_POSITIONS = 128,
    parameter integer MAX_CHANNELS  = 64,
    parameter integer POS_W         = $clog2(MAX_POSITIONS + 1),
    parameter integer CH_W          = $clog2(MAX_CHANNELS + 1),
    parameter integer C_ADDR_W      = $clog2(MAX_POSITIONS * MAX_CHANNELS),
    parameter integer Q_ADDR_W      = $clog2(MAX_POSITIONS * MAX_CHANNELS)
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         start,
    input  wire [POS_W-1:0]             cfg_positions,
    input  wire [CH_W-1:0]              cfg_channels,
    input  wire                         cfg_pool_enable,
    input  wire [CH_W-2:0]              cfg_parameter_channel_base,
    input  wire [Q_ADDR_W-1:0]          cfg_q_base,
    input  wire [POS_W-1:0]             cfg_q_channel_stride,
    output reg                          busy,
    output reg                          done,
    output reg                          error,

    output reg                          c_rd_en,
    output reg [C_ADDR_W-1:0]           c_rd_addr,
    input  wire signed [31:0]           c_rd_data,

    output wire [CH_W-2:0]              parameter_channel,
    output wire [CH_W-2:0]              result_parameter_channel,
    input  wire signed [31:0]           parameter_bias,
    input  wire [4:0]                   parameter_right_shift,

    output reg                          q_wr_en,
    output reg [Q_ADDR_W-1:0]           q_wr_addr,
    output reg signed [7:0]             q_wr_data,

    output reg [31:0]                   total_cycles,
    output reg [31:0]                   output_count,
    output reg [31:0]                   saturation_count
);

    generate if (PIPELINED) begin : continuous
        int8_layer_postprocess_pipeline #(
            .MAX_POSITIONS(MAX_POSITIONS), .MAX_CHANNELS(MAX_CHANNELS),
            .POS_W(POS_W), .CH_W(CH_W), .C_ADDR_W(C_ADDR_W), .Q_ADDR_W(Q_ADDR_W)
        ) engine (.*);
    end else begin : serial
    localparam [2:0] STATE_IDLE      = 3'd0;
    localparam [2:0] STATE_REQUEST   = 3'd1;
    localparam [2:0] STATE_FEED      = 3'd2;
    localparam [2:0] STATE_POST_WAIT = 3'd3;
    localparam [2:0] STATE_POOL_WAIT = 3'd4;

    reg [2:0] state;
    reg [POS_W-1:0] positions_reg;
    reg [CH_W-1:0] channels_reg;
    reg pool_enable_reg;
    reg [CH_W-2:0] parameter_channel_base_reg;
    reg [Q_ADDR_W-1:0] q_channel_base;
    reg [POS_W-1:0] q_channel_stride_reg;
    reg signed [31:0] parameter_bias_reg;
    reg [4:0] parameter_right_shift_reg;
    reg [POS_W-1:0] position_index;
    reg [CH_W-1:0] channel_index;
    reg [C_ADDR_W-1:0] c_index;
    reg signed [7:0] even_value;

    reg post_in_valid;
    wire post_in_ready;
    wire post_out_valid;
    reg post_out_ready;
    wire signed [7:0] post_out_value;
    wire post_saturated;

    reg pool_in_valid;
    wire pool_in_ready;
    wire pool_out_valid;
    reg pool_out_ready;
    wire signed [7:0] pool_out_value;

    assign parameter_channel =
        parameter_channel_base_reg + channel_index[CH_W-2:0];
    assign result_parameter_channel = parameter_channel;

    int8_requantize_relu postprocess (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(post_in_valid),
        .in_ready(post_in_ready),
        .mac_value(c_rd_data),
        .bias_value(parameter_bias_reg),
        .right_shift(parameter_right_shift_reg),
        .relu_enable(1'b1),
        .out_valid(post_out_valid),
        .out_ready(post_out_ready),
        .out_value(post_out_value),
        .saturated(post_saturated)
    );

    int8_max_pool2 pool (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(pool_in_valid),
        .in_ready(pool_in_ready),
        .value_even(even_value),
        .value_odd(post_out_value),
        .out_valid(pool_out_valid),
        .out_ready(pool_out_ready),
        .out_value(pool_out_value)
    );

    always @* begin
        c_rd_en = 1'b0;
        c_rd_addr = c_index;
        q_wr_en = 1'b0;
        q_wr_addr = q_channel_base
            + (pool_enable_reg ? (position_index >> 1) : position_index);
        q_wr_data = 8'sd0;
        post_in_valid = 1'b0;
        post_out_ready = 1'b0;
        pool_in_valid = 1'b0;
        pool_out_ready = 1'b0;

        case (state)
            STATE_REQUEST: begin
                c_rd_en = 1'b1;
            end

            STATE_FEED: begin
                post_in_valid = 1'b1;
            end

            STATE_POST_WAIT: begin
                if (!pool_enable_reg) begin
                    post_out_ready = 1'b1;
                    if (post_out_valid) begin
                        q_wr_en = 1'b1;
                        q_wr_data = post_out_value;
                    end
                end else if (!position_index[0]) begin
                    post_out_ready = 1'b1;
                end else begin
                    pool_in_valid = post_out_valid;
                    post_out_ready = pool_in_ready;
                end
            end

            STATE_POOL_WAIT: begin
                pool_out_ready = 1'b1;
                if (pool_out_valid) begin
                    q_wr_en = 1'b1;
                    q_wr_data = pool_out_value;
                end
            end

            default: begin
            end
        endcase
    end

    task automatic advance_position;
        begin
            if (position_index + 1'b1 < positions_reg) begin
                position_index <= position_index + 1'b1;
                c_index <= c_index + channels_reg;
                state <= STATE_REQUEST;
            end else if (channel_index + 1'b1 < channels_reg) begin
                channel_index <= channel_index + 1'b1;
                position_index <= {POS_W{1'b0}};
                c_index <= channel_index + 1'b1;
                q_channel_base <= q_channel_base + q_channel_stride_reg;
                state <= STATE_REQUEST;
            end else begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= STATE_IDLE;
            end
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            positions_reg <= {POS_W{1'b0}};
            channels_reg <= {CH_W{1'b0}};
            pool_enable_reg <= 1'b0;
            parameter_channel_base_reg <= {(CH_W-1){1'b0}};
            q_channel_base <= {Q_ADDR_W{1'b0}};
            q_channel_stride_reg <= {POS_W{1'b0}};
            parameter_bias_reg <= 32'sd0;
            parameter_right_shift_reg <= 5'd0;
            position_index <= {POS_W{1'b0}};
            channel_index <= {CH_W{1'b0}};
            c_index <= {C_ADDR_W{1'b0}};
            even_value <= 8'sd0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            total_cycles <= 32'd0;
            output_count <= 32'd0;
            saturation_count <= 32'd0;
        end else begin
            done <= 1'b0;

            if (start && busy)
                error <= 1'b1;
            if (busy)
                total_cycles <= total_cycles + 1'b1;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        total_cycles <= 32'd0;
                        output_count <= 32'd0;
                        saturation_count <= 32'd0;
                        if ((cfg_positions == 0) || (cfg_positions > MAX_POSITIONS)
                            || (cfg_channels == 0) || (cfg_channels > MAX_CHANNELS)
                            || (cfg_pool_enable && cfg_positions[0])
                            || (cfg_q_channel_stride == 0)
                            || ({1'b0, cfg_parameter_channel_base} + cfg_channels > MAX_CHANNELS)) begin
                            error <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            positions_reg <= cfg_positions;
                            channels_reg <= cfg_channels;
                            pool_enable_reg <= cfg_pool_enable;
                            parameter_channel_base_reg <= cfg_parameter_channel_base;
                            q_channel_base <= cfg_q_base;
                            q_channel_stride_reg <= cfg_q_channel_stride;
                            position_index <= {POS_W{1'b0}};
                            channel_index <= {CH_W{1'b0}};
                            c_index <= {C_ADDR_W{1'b0}};
                            error <= 1'b0;
                            busy <= 1'b1;
                            state <= STATE_REQUEST;
                        end
                    end
                end

                STATE_REQUEST: begin
                    parameter_bias_reg <= parameter_bias;
                    parameter_right_shift_reg <= parameter_right_shift;
                    state <= STATE_FEED;
                end

                STATE_FEED: begin
                    if (post_in_valid && post_in_ready)
                        state <= STATE_POST_WAIT;
                end

                STATE_POST_WAIT: begin
                    if (post_out_valid && post_out_ready) begin
                        if (post_saturated)
                            saturation_count <= saturation_count + 1'b1;
                        if (!pool_enable_reg) begin
                            output_count <= output_count + 1'b1;
                            advance_position();
                        end else if (!position_index[0]) begin
                            even_value <= post_out_value;
                            advance_position();
                        end else begin
                            state <= STATE_POOL_WAIT;
                        end
                    end
                end

                STATE_POOL_WAIT: begin
                    if (pool_out_valid && pool_out_ready) begin
                        output_count <= output_count + 1'b1;
                        advance_position();
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    busy <= 1'b0;
                    error <= 1'b1;
                end
            endcase
        end
    end
    end endgenerate

endmodule

// The existing requantizer accepts one value per cycle. Carry address/parity/
// last tags through its three stages, instead of draining it after each value.
// C is a synchronous one-cycle read port; Q has no backpressure.
module int8_layer_postprocess_pipeline #(
    parameter integer MAX_POSITIONS = 128,
    parameter integer MAX_CHANNELS = 64,
    parameter integer POS_W = $clog2(MAX_POSITIONS+1),
    parameter integer CH_W = $clog2(MAX_CHANNELS+1),
    parameter integer C_ADDR_W = $clog2(MAX_POSITIONS*MAX_CHANNELS),
    parameter integer Q_ADDR_W = $clog2(MAX_POSITIONS*MAX_CHANNELS)
) (
    input wire clk, rst_n, start,
    input wire [POS_W-1:0] cfg_positions,
    input wire [CH_W-1:0] cfg_channels,
    input wire cfg_pool_enable,
    input wire [CH_W-2:0] cfg_parameter_channel_base,
    input wire [Q_ADDR_W-1:0] cfg_q_base,
    input wire [POS_W-1:0] cfg_q_channel_stride,
    output reg busy, done, error,
    output wire c_rd_en,
    output wire [C_ADDR_W-1:0] c_rd_addr,
    input wire signed [31:0] c_rd_data,
    output wire [CH_W-2:0] parameter_channel,
    output wire [CH_W-2:0] result_parameter_channel,
    input wire signed [31:0] parameter_bias,
    input wire [4:0] parameter_right_shift,
    output wire q_wr_en,
    output wire [Q_ADDR_W-1:0] q_wr_addr,
    output wire signed [7:0] q_wr_data,
    output reg [31:0] total_cycles, output_count, saturation_count
);
    reg [POS_W-1:0] positions_r, position_r, stride_r;
    reg [CH_W-1:0] channels_r, channel_r;
    reg [CH_W-2:0] parameter_base_r;
    reg [Q_ADDR_W-1:0] q_channel_base_r;
    reg [C_ADDR_W-1:0] c_index_r;
    reg pool_r, issued_all, read_valid;
    reg signed [31:0] read_bias;
    reg [4:0] read_shift;
    reg [Q_ADDR_W-1:0] read_address;
    reg read_odd, read_last;
    reg [CH_W-2:0] read_channel;
    reg [CH_W-2:0] channel_pipe [0:2];
    reg [Q_ADDR_W-1:0] address_pipe [0:2];
    reg [2:0] odd_pipe, last_pipe;
    reg signed [7:0] even_value;
    wire rq_in_ready, rq_out_valid, rq_saturated;
    wire signed [7:0] rq_value;
    wire issue = busy && !issued_all;
    wire last_request = position_r+1'b1 == positions_r && channel_r+1'b1 == channels_r;
    assign c_rd_en = issue;
    assign c_rd_addr = c_index_r;
    assign parameter_channel = parameter_base_r+channel_r[CH_W-2:0];
    assign result_parameter_channel = channel_pipe[2];
    assign q_wr_en = busy && rq_out_valid && (!pool_r || odd_pipe[2]);
    assign q_wr_addr = address_pipe[2];
    assign q_wr_data = pool_r && $signed(even_value) > $signed(rq_value) ? even_value : rq_value;

    int8_requantize_relu requantizer (
        .clk(clk), .rst_n(rst_n), .in_valid(read_valid), .in_ready(rq_in_ready),
        .mac_value(c_rd_data), .bias_value(read_bias), .right_shift(read_shift),
        .relu_enable(1'b1), .out_valid(rq_out_valid), .out_ready(1'b1),
        .out_value(rq_value), .saturated(rq_saturated)
    );

    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            busy <= 0; done <= 0; error <= 0;
            positions_r <= 0; position_r <= 0; stride_r <= 0;
            channels_r <= 0; channel_r <= 0; parameter_base_r <= 0;
            q_channel_base_r <= 0; c_index_r <= 0; pool_r <= 0;
            issued_all <= 0; read_valid <= 0; read_bias <= 0; read_shift <= 0;
            read_address <= 0; read_odd <= 0; read_last <= 0;
            read_channel <= 0;
            odd_pipe <= 0; last_pipe <= 0; even_value <= 0;
            for (i=0; i<3; i=i+1) begin address_pipe[i] <= 0; channel_pipe[i] <= 0; end
            total_cycles <= 0; output_count <= 0; saturation_count <= 0;
        end else begin
            done <= 0;
            read_valid <= issue;
            address_pipe[0] <= read_address;
            address_pipe[1] <= address_pipe[0];
            address_pipe[2] <= address_pipe[1];
            channel_pipe[0] <= read_channel;
            channel_pipe[1] <= channel_pipe[0];
            channel_pipe[2] <= channel_pipe[1];
            odd_pipe <= {odd_pipe[1:0], read_odd};
            last_pipe <= {last_pipe[1:0], read_last};
            if (start && busy) error <= 1;
            if (busy) total_cycles <= total_cycles+1'b1;
            if (issue) begin
                read_bias <= parameter_bias;
                read_shift <= parameter_right_shift;
                read_address <= q_channel_base_r+(pool_r ? position_r >> 1 : position_r);
                read_odd <= position_r[0];
                read_last <= last_request;
                read_channel <= parameter_channel;
                if (last_request) issued_all <= 1;
                else if (position_r+1'b1 < positions_r) begin
                    position_r <= position_r+1'b1;
                    c_index_r <= c_index_r+channels_r;
                end else begin
                    position_r <= 0;
                    channel_r <= channel_r+1'b1;
                    c_index_r <= channel_r+1'b1;
                    q_channel_base_r <= q_channel_base_r+stride_r;
                end
            end
            if (busy && rq_out_valid) begin
                if (rq_saturated) saturation_count <= saturation_count+1'b1;
                if (pool_r && !odd_pipe[2]) even_value <= rq_value;
                if (q_wr_en) output_count <= output_count+1'b1;
                if (last_pipe[2]) begin
                    busy <= 0;
                    done <= 1;
                end
            end
            if (start && !busy) begin
                total_cycles <= 0; output_count <= 0; saturation_count <= 0;
                if (cfg_positions == 0 || cfg_positions > MAX_POSITIONS
                    || cfg_channels == 0 || cfg_channels > MAX_CHANNELS
                    || (cfg_pool_enable && cfg_positions[0]) || cfg_q_channel_stride == 0
                    || {1'b0,cfg_parameter_channel_base}+cfg_channels > MAX_CHANNELS) begin
                    done <= 1; error <= 1;
                end else begin
                    positions_r <= cfg_positions; channels_r <= cfg_channels;
                    stride_r <= cfg_q_channel_stride; pool_r <= cfg_pool_enable;
                    parameter_base_r <= cfg_parameter_channel_base;
                    q_channel_base_r <= cfg_q_base; c_index_r <= 0;
                    position_r <= 0; channel_r <= 0; issued_all <= 0;
                    error <= 0; busy <= 1;
                end
            end
        end
    end
endmodule
