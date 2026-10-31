`timescale 1ns/1ps

// Builds the packed A tile for a channel-major, same-padded 1-D convolution.
// One byte is read at a time so padding and tail positions need no special
// memory alignment assumptions. The Q and A ports are exclusively owned while
// busy; the MMIO wrapper arbitrates them against the CPU and GEMM engine.
module int8_input_window_loader #(
    parameter integer MAX_M = 16,
    parameter integer MAX_K = 64,
    parameter integer Q_BYTES = 8192,
    parameter integer Q_WORD_ADDR_W = $clog2(Q_BYTES / 4),
    parameter integer A_ADDR_W = $clog2(((MAX_M + 3) / 4) * MAX_K)
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] cfg_tile_m,
    input wire [7:0] cfg_tile_k,
    input wire [15:0] cfg_output_base,
    input wire [15:0] cfg_input_length,
    input wire [7:0] cfg_kernel,
    input wire [7:0] cfg_padding,
    input wire [15:0] cfg_channel_base,
    input wire [7:0] cfg_start_tap,
    output reg busy,
    output reg done,
    output reg error,
    output wire q_rd_en,
    output wire [Q_WORD_ADDR_W-1:0] q_rd_addr,
    input wire [31:0] q_rd_data,
    output wire a_wr_en,
    output wire [A_ADDR_W-1:0] a_wr_addr,
    output wire [31:0] a_wr_data
);
    localparam [1:0] S_IDLE = 2'd0, S_READ = 2'd1,
                     S_CAPTURE = 2'd2, S_WRITE = 2'd3;

    reg [1:0] state;
    reg [$clog2((MAX_M+3)/4)-1:0] row_tile;
    reg [7:0] local_k;
    reg [1:0] lane;
    reg [7:0] tap;
    reg [15:0] channel_base;
    reg [31:0] packed_word;

    wire [7:0] row_count = (cfg_tile_m + 8'd3) >> 2;
    wire [15:0] local_position = ({13'd0, row_tile} << 2) + {14'd0, lane};
    wire signed [17:0] input_position =
        $signed({2'b00, cfg_output_base})
        + $signed({2'b00, local_position})
        + $signed({10'd0, tap})
        - $signed({10'd0, cfg_padding});
    wire position_valid = (local_position < cfg_tile_m)
        && (input_position >= 0)
        && (input_position < $signed({2'b00, cfg_input_length}));
    wire [17:0] byte_index = {2'b00, channel_base} + input_position;
    wire address_valid = (byte_index >= 0) && (byte_index < Q_BYTES);
    wire read_valid = position_valid && address_valid;

    assign q_rd_en = busy && state == S_READ && read_valid;
    assign q_rd_addr = byte_index[Q_WORD_ADDR_W+1:2];
    assign a_wr_en = busy && state == S_WRITE;
    assign a_wr_addr = row_tile * MAX_K + local_k;
    assign a_wr_data = packed_word;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            row_tile <= 3'd0;
            local_k <= 8'd0;
            lane <= 2'd0;
            tap <= 8'd0;
            channel_base <= 16'd0;
            packed_word <= 32'd0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                error <= 1'b0;
                if (cfg_tile_m == 0 || cfg_tile_m > MAX_M
                    || cfg_tile_k == 0 || cfg_tile_k > MAX_K
                    || cfg_kernel == 0 || cfg_start_tap >= cfg_kernel
                    || cfg_input_length == 0 || cfg_input_length > 128
                    || cfg_padding >= cfg_kernel
                    || cfg_channel_base >= Q_BYTES) begin
                    error <= 1'b1;
                    done <= 1'b1;
                end else begin
                    row_tile <= 3'd0;
                    local_k <= 8'd0;
                    lane <= 2'd0;
                    tap <= cfg_start_tap;
                    channel_base <= cfg_channel_base;
                    packed_word <= 32'd0;
                    busy <= 1'b1;
                    state <= S_READ;
                end
            end else if (busy) begin
                case (state)
                    S_READ: begin
                        if (position_valid && !address_valid) begin
                            error <= 1'b1;
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            state <= S_CAPTURE;
                        end
                    end
                    S_CAPTURE: begin
                        if (read_valid)
                            packed_word <= packed_word
                                | (((q_rd_data >> (byte_index[1:0] * 8)) & 32'hff)
                                   << (lane * 8));
                        if (lane == 2'd3) begin
                            state <= S_WRITE;
                        end else begin
                            lane <= lane + 2'd1;
                            state <= S_READ;
                        end
                    end
                    S_WRITE: begin
                        lane <= 2'd0;
                        packed_word <= 32'd0;
                        if (local_k + 8'd1 == cfg_tile_k) begin
                            local_k <= 8'd0;
                            tap <= cfg_start_tap;
                            channel_base <= cfg_channel_base;
                            if (row_tile + 3'd1 == row_count) begin
                                done <= 1'b1;
                                busy <= 1'b0;
                                state <= S_IDLE;
                            end else begin
                                row_tile <= row_tile + 3'd1;
                                state <= S_READ;
                            end
                        end else begin
                            local_k <= local_k + 8'd1;
                            if (tap + 8'd1 == cfg_kernel) begin
                                tap <= 8'd0;
                                channel_base <= channel_base + cfg_input_length;
                            end else begin
                                tap <= tap + 8'd1;
                            end
                            state <= S_READ;
                        end
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule

// M21 candidate: consume one or two packed Q words for each four-byte A word.
// The original byte-serial module above remains the M20 switch-off baseline.
module int8_input_window_loader_packed #(
    parameter integer EARLY_Q_READ = 1, // M34: issue a miss while calculating/writing metadata.
    parameter integer ZERO_LANE_ADVANCE_OPT = 0,
    parameter integer WORD_CACHE = 0,
    parameter integer FAST_READ_PIPELINE = 0,
    parameter integer MAX_M = 16,
    parameter integer MAX_K = 64,
    parameter integer Q_BYTES = 8192,
    parameter integer Q_WORD_ADDR_W = $clog2(Q_BYTES / 4),
    parameter integer A_ADDR_W = $clog2(((MAX_M + 3) / 4) * MAX_K)
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] cfg_tile_m,
    input wire [7:0] cfg_tile_k,
    input wire [15:0] cfg_output_base,
    input wire [15:0] cfg_input_length,
    input wire [7:0] cfg_kernel,
    input wire [7:0] cfg_padding,
    input wire [15:0] cfg_channel_base,
    input wire [7:0] cfg_start_tap,
    output reg busy,
    output reg done,
    output reg error,
    output wire q_rd_en,
    output wire [Q_WORD_ADDR_W-1:0] q_rd_addr,
    input wire [31:0] q_rd_data,
    output wire a_wr_en,
    output wire [A_ADDR_W-1:0] a_wr_addr,
    output wire [31:0] a_wr_data
);
    localparam [2:0] S_IDLE = 3'd0, S_CALC = 3'd1,
                     S_READ0 = 3'd2, S_CAPTURE0 = 3'd3,
                     S_READ1 = 3'd4, S_CAPTURE1 = 3'd5,
                     S_WRITE = 3'd6;

    reg [2:0] state;
    reg [$clog2((MAX_M+3)/4)-1:0] row_tile;
    reg [7:0] local_k;
    reg [7:0] tap;
    reg [15:0] channel_base;
    reg [31:0] first_word;
    reg [31:0] second_word;
    reg [Q_WORD_ADDR_W-1:0] first_word_address_r;
    reg [Q_WORD_ADDR_W-1:0] last_word_address_r;
    reg needs_second_word_r;
    reg [3:0] lane_valid_r;
    reg [3:0] lane_second_r;
    reg [1:0] lane_offset_r [0:3];
    reg [A_ADDR_W-1:0] fast_write_address;
    reg fast_last_word;
    // Two direct-mapped entries; a four-byte window spans at most two adjacent
    // Q words. They are invalidated on EVERY start, not retained across inputs.
    reg [1:0] cache_valid;
    reg [Q_WORD_ADDR_W-1:0] cache_tag [0:1];
    reg [31:0] cache_data [0:1];

    wire [7:0] row_count = (cfg_tile_m + 8'd3) >> 2;
    wire [15:0] row_position = {11'd0, row_tile, 2'b00};
    wire signed [18:0] first_position =
        $signed({3'b000, cfg_output_base})
        + $signed({3'b000, row_position})
        + $signed({11'd0, tap})
        - $signed({11'd0, cfg_padding});
    wire signed [18:0] lane_position [0:3];
    wire signed [18:0] lane_address [0:3];
    wire [3:0] lane_valid;
    wire [3:0] lane_address_error;
    wire [7:0] lane_byte [0:3];

    genvar lane;
    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : packed_lane
            assign lane_position[lane] = first_position + lane;
            assign lane_address[lane] =
                $signed({3'b000, channel_base}) + lane_position[lane];
            assign lane_valid[lane] = (row_position + lane < cfg_tile_m)
                && (lane_position[lane] >= 0)
                && (lane_position[lane] < $signed({3'b000, cfg_input_length}));
            assign lane_address_error[lane] = lane_valid[lane]
                && ((lane_address[lane] < 0) || (lane_address[lane] >= Q_BYTES));
        end
    endgenerate

    wire any_valid = |lane_valid;
    wire address_error = |lane_address_error;
    // If no lane is valid, each (lane_valid && bounds_error) is zero.
    // Removing the redundant address_error term cuts the channel-address
    // carry/comparison chain out of tap/local-K register enables.
    wire zero_lane_advance = !any_valid && (ZERO_LANE_ADVANCE_OPT || !address_error);
    wire [18:0] first_address = lane_valid[0] ? lane_address[0]
                              : lane_valid[1] ? lane_address[1]
                              : lane_valid[2] ? lane_address[2] : lane_address[3];
    wire [18:0] last_address = lane_valid[3] ? lane_address[3]
                             : lane_valid[2] ? lane_address[2]
                             : lane_valid[1] ? lane_address[1] : lane_address[0];
    wire [Q_WORD_ADDR_W-1:0] first_word_address =
        first_address[Q_WORD_ADDR_W+1:2];
    wire [Q_WORD_ADDR_W-1:0] last_word_address =
        last_address[Q_WORD_ADDR_W+1:2];
    wire needs_second_word = first_word_address != last_word_address;
    wire cache_first_hit = cache_valid[first_word_address[0]]
        && cache_tag[first_word_address[0]] == first_word_address;
    wire cache_last_hit = cache_valid[last_word_address[0]]
        && cache_tag[last_word_address[0]] == last_word_address;
    wire cache_complete = WORD_CACHE && FAST_READ_PIPELINE && any_valid
        && cache_first_hit && (!needs_second_word || cache_last_hit);
    wire cache_first_available = WORD_CACHE && FAST_READ_PIPELINE && any_valid && cache_first_hit;
    wire cache_last_available_r = WORD_CACHE && FAST_READ_PIPELINE
        && cache_valid[last_word_address_r[0]]
        && cache_tag[last_word_address_r[0]] == last_word_address_r;

    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : packed_select
            wire [31:0] source_word = lane_second_r[lane] ? second_word : first_word;
            assign lane_byte[lane] = lane_valid_r[lane]
                ? (source_word >> (lane_offset_r[lane] * 8)) & 8'hff
                : 8'h00;
        end
    endgenerate

    // Q and A are separate memories: the next Q request can be accepted on
    // the same edge that captures its metadata or writes the previous A word.
    // Never speculate beyond the final word, padding-only words, or an error.
    wire early_q_read = EARLY_Q_READ && FAST_READ_PIPELINE && busy
        && (state == S_CALC || (state == S_WRITE && !fast_last_word))
        && any_valid && !address_error && !cache_complete;
    assign q_rd_en = early_q_read || (busy && (state == S_READ0 || state == S_READ1
        || (FAST_READ_PIPELINE && state == S_CAPTURE0 && needs_second_word_r && !cache_last_available_r)));
    assign q_rd_addr = early_q_read
        ? (cache_first_available ? last_word_address : first_word_address)
        : ((state == S_READ1 || (FAST_READ_PIPELINE && state == S_CAPTURE0))
            ? last_word_address_r : first_word_address_r);
    assign a_wr_en = busy && state == S_WRITE;
    assign a_wr_addr = FAST_READ_PIPELINE ? fast_write_address : row_tile * MAX_K + local_k;
    assign a_wr_data = {lane_byte[3], lane_byte[2], lane_byte[1], lane_byte[0]};

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            row_tile <= 3'd0;
            local_k <= 8'd0;
            tap <= 8'd0;
            channel_base <= 16'd0;
            first_word <= 32'd0;
            second_word <= 32'd0;
            first_word_address_r <= 0;
            last_word_address_r <= 0;
            needs_second_word_r <= 1'b0;
            fast_write_address <= 0; fast_last_word <= 0; cache_valid <= 0;
            lane_valid_r <= 4'd0;
            lane_second_r <= 4'd0;
            for (integer i = 0; i < 4; i = i + 1)
                lane_offset_r[i] <= 2'd0;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                cache_valid <= 0;
                error <= 1'b0;
                if (cfg_tile_m == 0 || cfg_tile_m > MAX_M
                    || cfg_tile_k == 0 || cfg_tile_k > MAX_K
                    || cfg_kernel == 0 || cfg_start_tap >= cfg_kernel
                    || cfg_input_length == 0 || cfg_input_length > 128
                    || cfg_padding >= cfg_kernel
                    || cfg_channel_base >= Q_BYTES) begin
                    error <= 1'b1;
                    done <= 1'b1;
                end else begin
                    row_tile <= 3'd0;
                    local_k <= 8'd0;
                    tap <= cfg_start_tap;
                    channel_base <= cfg_channel_base;
                    first_word <= 32'd0;
                    second_word <= 32'd0;
                    busy <= 1'b1;
                    fast_last_word <= 0;
                    state <= S_CALC;
                end
            end else if (busy) begin
                if (WORD_CACHE && FAST_READ_PIPELINE) begin
                    if (state == S_CAPTURE0) begin
                        cache_valid[first_word_address_r[0]] <= 1;
                        cache_tag[first_word_address_r[0]] <= first_word_address_r;
                        cache_data[first_word_address_r[0]] <= q_rd_data;
                    end
                    if (state == S_CAPTURE1) begin
                        cache_valid[last_word_address_r[0]] <= 1;
                        cache_tag[last_word_address_r[0]] <= last_word_address_r;
                        cache_data[last_word_address_r[0]] <= q_rd_data;
                    end
                end
                // Metadata for the next packed word is captured while the
                // current registered word writes A. The indices advance one
                // cycle earlier, so the bounds/address path stays registered.
                if (state == S_CALC || (FAST_READ_PIPELINE && state == S_WRITE)) begin
                    first_word_address_r <= first_word_address;
                    last_word_address_r <= last_word_address;
                    needs_second_word_r <= needs_second_word;
                    lane_valid_r <= lane_valid;
                    fast_write_address <= row_tile * MAX_K + local_k;
                    if (cache_first_available)
                        first_word <= cache_data[first_word_address[0]];
                    if (WORD_CACHE && FAST_READ_PIPELINE && cache_last_hit)
                        second_word <= cache_data[last_word_address[0]];
                    for (integer i = 0; i < 4; i = i + 1) begin
                        lane_second_r[i] <= lane_address[i][Q_WORD_ADDR_W+1:2] != first_word_address;
                        lane_offset_r[i] <= lane_address[i][1:0];
                    end
                end
                if (FAST_READ_PIPELINE && (
                    state == S_CAPTURE1 || (state == S_CAPTURE0 && (!needs_second_word_r || cache_last_available_r))
                    || ((state == S_CALC || (state == S_WRITE && !fast_last_word))
                        && (zero_lane_advance || cache_complete)))) begin
                    fast_last_word <= local_k + 8'd1 == cfg_tile_k
                        && row_tile + 3'd1 == row_count;
                    if (local_k + 8'd1 == cfg_tile_k) begin
                        local_k <= 0; tap <= cfg_start_tap; channel_base <= cfg_channel_base;
                        if (row_tile + 3'd1 != row_count) row_tile <= row_tile + 1'b1;
                    end else begin
                        local_k <= local_k + 1'b1;
                        if (tap + 8'd1 == cfg_kernel) begin
                            tap <= 0; channel_base <= channel_base + cfg_input_length;
                        end else tap <= tap + 1'b1;
                    end
                end
                case (state)
                    S_CALC: begin
                        // Capture speculative addresses with a state-only enable.
                        // An invalid address aborts before either memory port is used.
                        // Keep the bounds-check chain off the address-register CE.
                        if (address_error) begin
                            error <= 1'b1;
                            done <= 1'b1;
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            state <= !any_valid || cache_complete ? S_WRITE
                                : (cache_first_available
                                    ? (EARLY_Q_READ && FAST_READ_PIPELINE ? S_CAPTURE1 : S_READ1)
                                    : (EARLY_Q_READ && FAST_READ_PIPELINE ? S_CAPTURE0 : S_READ0));
                        end
                    end
                    S_READ0: state <= S_CAPTURE0;
                    S_CAPTURE0: begin
                        first_word <= q_rd_data;
                        if (cache_last_available_r)
                            second_word <= cache_data[last_word_address_r[0]];
                        state <= needs_second_word_r && !cache_last_available_r
                            ? (FAST_READ_PIPELINE ? S_CAPTURE1 : S_READ1) : S_WRITE;
                    end
                    S_READ1: state <= S_CAPTURE1;
                    S_CAPTURE1: begin
                        second_word <= q_rd_data;
                        state <= S_WRITE;
                    end
                    S_WRITE: begin
                        if (FAST_READ_PIPELINE) begin
                            if (fast_last_word) begin
                                done <= 1; busy <= 0; state <= S_IDLE;
                            end else if (address_error) begin
                                error <= 1; done <= 1; busy <= 0; state <= S_IDLE;
                            end else state <= !any_valid || cache_complete ? S_WRITE
                                : (cache_first_available
                                    ? (EARLY_Q_READ && FAST_READ_PIPELINE ? S_CAPTURE1 : S_READ1)
                                    : (EARLY_Q_READ && FAST_READ_PIPELINE ? S_CAPTURE0 : S_READ0));
                        end else if (local_k + 8'd1 == cfg_tile_k) begin
                            local_k <= 8'd0;
                            tap <= cfg_start_tap;
                            channel_base <= cfg_channel_base;
                            if (row_tile + 3'd1 == row_count) begin
                                done <= 1'b1;
                                busy <= 1'b0;
                                state <= S_IDLE;
                            end else begin
                                row_tile <= row_tile + 3'd1;
                                state <= S_CALC;
                            end
                        end else begin
                            local_k <= local_k + 8'd1;
                            if (tap + 8'd1 == cfg_kernel) begin
                                tap <= 8'd0;
                                channel_base <= channel_base + cfg_input_length;
                            end else begin
                                tap <= tap + 8'd1;
                            end
                            state <= S_CALC;
                        end
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end
endmodule
