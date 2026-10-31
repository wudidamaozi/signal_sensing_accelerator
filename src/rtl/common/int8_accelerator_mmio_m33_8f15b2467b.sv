`timescale 1ns/1ps

module int8_accelerator_mmio_core_m30 #(
    parameter integer MAX_M = 16,
    parameter integer MAX_N = 16,
    parameter integer MAX_K = 64,
    parameter integer ALLOW_LOADER_OVERLAP = 0,
    parameter integer PIPELINED_POSTPROCESS = 0,
    parameter integer DIRECT_WEIGHT_FEED = 0,
    parameter integer CHAINED_POSTPROCESS = 0,
    parameter integer INCREMENTAL_WEIGHT_ADDRESS = 0,
    parameter integer AUTONOMOUS_LAYER = 0,
    parameter integer LAYER_POST_OVERLAP = 1,
    parameter integer LAYER_INPUT_OVERLAP = 0,
    parameter integer PACKED_READ_PIPELINE = 0,
    parameter integer OVERLAP_GEMM_WRITEBACK = 0,
    parameter integer ZERO_LANE_ADVANCE_OPT = 0,
    parameter integer SHARED_WEIGHT_PORTS = 1,
    parameter integer ENABLE_STREAM_GAP = 0,
    parameter integer DIRECT_WEIGHT_ONLY = 1,
    parameter integer FUSED_LAYER_LAUNCH = 1,
    parameter integer TILE_ROWS = 4,
    parameter integer TILE_COLS = 4,
    parameter integer DATA_W = 8,
    parameter integer ACC_W = 32,
    parameter integer POST_MAX_POSITIONS = 128,
    parameter integer POST_MAX_CHANNELS = 64,
    parameter integer WEIGHT_BYTES = 23232,
    parameter integer PACKED_WINDOW_LOADER = 0,
    parameter WEIGHT_INIT_FILE = ""
) (
    input wire clk,
    input wire rst_n,
    input wire bus_valid,
    input wire [15:0] bus_addr,
    input wire [31:0] bus_wdata,
    input wire [3:0] bus_wstrb,
    output reg bus_ready,
    output reg [31:0] bus_rdata,
    output wire m30_active,
    output wire [31:0] m30_gemm, m30_compute, m30_post
);

    localparam integer M_W = $clog2(MAX_M + 1);
    localparam integer N_W = $clog2(MAX_N + 1);
    localparam integer K_W = $clog2(MAX_K + 1);
    localparam integer A_WORDS = ((MAX_M + 3) / 4) * MAX_K;
    localparam integer B_WORDS = ((MAX_N + 3) / 4) * MAX_K;
    localparam integer C_WORDS = MAX_M * MAX_N;
    localparam integer A_ADDR_W = $clog2(A_WORDS);
    localparam integer B_ADDR_W = $clog2(B_WORDS);
    localparam integer C_ADDR_W = $clog2(C_WORDS);
    localparam integer POST_POS_W = $clog2(POST_MAX_POSITIONS + 1);
    localparam integer POST_CH_W = $clog2(POST_MAX_CHANNELS + 1);
    localparam integer POST_C_ADDR_W = $clog2(POST_MAX_POSITIONS * POST_MAX_CHANNELS);
    localparam integer Q_BYTES = POST_MAX_POSITIONS * POST_MAX_CHANNELS;
    localparam integer Q_ADDR_W = $clog2(Q_BYTES);
    localparam integer Q_HOST_WORDS = Q_BYTES / 4;
    localparam integer Q_HOST_ADDR_W = $clog2(Q_HOST_WORDS);
    localparam integer WEIGHT_WORDS = (WEIGHT_BYTES + 3) / 4;
    localparam integer WEIGHT_ADDR_W = $clog2(WEIGHT_WORDS);
    reg [1:0] parameter_bank;
    localparam integer PARAM_ADDR_W = $clog2(POST_MAX_CHANNELS);
    reg [WEIGHT_ADDR_W-1:0] direct_weight_cursor;

    localparam [15:0] REG_CONTROL          = 16'h0000;
    localparam [15:0] REG_STATUS           = 16'h0004;
    localparam [15:0] REG_M                = 16'h0008;
    localparam [15:0] REG_N                = 16'h000c;
    localparam [15:0] REG_K                = 16'h0010;
    localparam [15:0] REG_TOTAL            = 16'h0014;
    localparam [15:0] REG_COMPUTE          = 16'h0018;
    localparam [15:0] REG_VERSION          = 16'h001c;
    localparam [15:0] REG_MODE             = 16'h0020;
    localparam [15:0] REG_POST_CONTROL     = 16'h0024;
    localparam [15:0] REG_POST_STATUS      = 16'h0028;
    localparam [15:0] REG_POST_POSITIONS   = 16'h002c;
    localparam [15:0] REG_POST_CHANNELS    = 16'h0030;
    localparam [15:0] REG_POST_OPTIONS     = 16'h0034;
    localparam [15:0] REG_POST_PARAM_BASE  = 16'h0038;
    localparam [15:0] REG_POST_Q_BASE      = 16'h003c;
    localparam [15:0] REG_POST_Q_STRIDE    = 16'h0040;
    localparam [15:0] REG_POST_TOTAL       = 16'h0044;
    localparam [15:0] REG_POST_OUTPUTS     = 16'h0048;
    localparam [15:0] REG_POST_SATURATIONS = 16'h004c;
    localparam [15:0] REG_LOAD_CONTROL     = 16'h0050;
    localparam [15:0] REG_LOAD_STATUS      = 16'h0054;
    localparam [15:0] REG_LOAD_OUTPUT_BASE = 16'h0058;
    localparam [15:0] REG_LOAD_INPUT_LENGTH= 16'h005c;
    localparam [15:0] REG_LOAD_KERNEL      = 16'h0060;
    localparam [15:0] REG_LOAD_PADDING     = 16'h0064;
    localparam [15:0] REG_LOAD_CHANNEL_BASE= 16'h0068;
    localparam [15:0] REG_LOAD_START_TAP   = 16'h006c;
    localparam [15:0] REG_WLOAD_CONTROL    = 16'h0070;
    localparam [15:0] REG_WLOAD_STATUS     = 16'h0074;
    localparam [15:0] REG_WLOAD_START_WORD = 16'h0078;
    localparam [15:0] REG_WLOAD_STRIDE     = 16'h007c;
    localparam [15:0] REG_GAP_CONTROL     = 16'h0080;
    localparam [15:0] REG_GAP_STATUS      = 16'h0084;
    localparam [15:0] REG_GAP_SOURCE_BASE = 16'h0088;
    localparam [15:0] REG_GAP_DEST_BASE   = 16'h008c;
    localparam [15:0] REG_GAP_LENGTH_LOG2 = 16'h0090;
    localparam [15:0] REG_GAP_CHANNELS    = 16'h0094;
    localparam [15:0] REG_DIRECT_WEIGHT   = 16'h0098;
    localparam [15:0] REG_CHAIN_CONTROL   = 16'h009c;
    localparam [15:0] REG_CHAIN_STATUS    = 16'h00a0;
    localparam [15:0] REG_LAYER_CONTROL   = 16'h00a4;
    localparam [15:0] REG_LAYER_STATUS    = 16'h00a8;
    localparam [15:0] REG_LAYER_M         = 16'h00ac;
    localparam [15:0] REG_LAYER_N         = 16'h00b0;
    localparam [15:0] REG_LAYER_TOTAL     = 16'h00b4;
    localparam [15:0] REG_LAYER_GEMM      = 16'h00b8;
    localparam [15:0] REG_LAYER_COMPUTE   = 16'h00bc;
    localparam [15:0] REG_LAYER_POST      = 16'h00c0;
    localparam [15:0] A_BASE               = 16'h1000;
    localparam [15:0] B_BASE               = 16'h2000;
    localparam [15:0] C_BASE               = 16'h3000;
    localparam [15:0] Q_BASE               = 16'h4000;
    localparam [15:0] WEIGHT_BASE          = 16'h6000;
    localparam [15:0] BIAS_BASE            = 16'hf800;
    localparam [15:0] SHIFT_BASE           = 16'hf900;

    reg [M_W-1:0] cfg_m;
    reg [N_W-1:0] cfg_n;
    reg [K_W-1:0] cfg_k;
    reg cfg_accumulate;
    reg cfg_direct_weight;
    reg [2:0] weight_stride_log2;
    localparam [1:0] CHAIN_IDLE = 2'd0, CHAIN_GEMM = 2'd1, CHAIN_POST = 2'd2;
    reg [1:0] chain_state;
    reg chain_done_sticky;
    reg chain_access_error;
    // Opt-in whole-16x16, complete-K layer loop. Every spatial tile loads A
    // once, then reuses it for all output-channel tiles. No new MACs/buffers.
    localparam [3:0] L_IDLE = 0, L_VALIDATE = 1, L_LOAD = 2,
                     L_LOAD_WAIT = 3, L_GEMM = 4, L_POST_WAIT = 5,
                     L_ADVANCE = 6, L_PREFETCH_WAIT = 7,
                     L_PIPE_DRAIN = 8, L_PIPE_ERROR = 9;
    reg [3:0] layer_state;
    reg layer_c_compute_bank, layer_c_post_bank;
    reg layer_gemm_finished;
    wire layer_post_overlap = LAYER_POST_OVERLAP && AUTONOMOUS_LAYER
        && PIPELINED_POSTPROCESS;
    reg [7:0] layer_m, layer_n, layer_m_offset, layer_n_offset;
    reg [K_W:0] layer_k_remaining;
    reg [16:0] layer_input_end;
    reg [15:0] layer_weight_base;
    reg [Q_ADDR_W-1:0] layer_row_q_base;
    reg layer_done_sticky, layer_access_error;
    reg [31:0] layer_total_cycles, layer_gemm_cycles;
    reg [31:0] layer_compute_cycles, layer_post_cycles;
    reg layer_compute_bank, layer_write_bank;
    reg layer_prefetch_ready, layer_prefetch_error;
    wire layer_busy = AUTONOMOUS_LAYER && layer_state != L_IDLE;
    wire chain_busy = CHAINED_POSTPROCESS && chain_state != CHAIN_IDLE;
    reg controller_start;
    reg done_sticky;
    reg access_error;

    reg [POST_POS_W-1:0] post_cfg_positions;
    reg [POST_CH_W-1:0] post_cfg_channels;
    reg post_cfg_pool_enable;
    reg post_cfg_relu_disable;
    reg [POST_CH_W-2:0] post_cfg_parameter_channel_base;
    reg [Q_ADDR_W-1:0] post_cfg_q_base;
    reg [POST_POS_W-1:0] post_cfg_q_channel_stride;
    reg post_start;
    reg post_done_sticky;
    reg post_access_error;
    reg c_read_pending;
    reg q_read_pending;
    reg weight_read_pending;
    reg [31:0] weight_low_rd0,weight_high_rd0,weight_low_rd1,weight_high_rd1;
    reg weight_sel0=0,weight_sel1=0,weight_pair_valid=0;
    wire [31:0] weight_host_rd_data=weight_sel0?weight_high_rd0:weight_low_rd0;
    wire [31:0] weight_pair_rd_data=!weight_pair_valid?32'd0:(weight_sel1?weight_high_rd1:weight_low_rd1);
    reg loader_start;
    reg loader_done_sticky;
    reg loader_access_error;
    reg [15:0] load_output_base;
    reg [15:0] load_input_length;
    reg [7:0] load_kernel;
    reg [7:0] load_padding;
    reg [15:0] load_channel_base;
    reg [7:0] load_start_tap;
    wire loader_busy;
    wire loader_done;
    wire loader_error;
    // M37: loader_done_sticky already records the same owned prefetch event.
    // Retain the independent error-event latch for transient fault recovery.
    wire layer_prefetch_complete = FUSED_LAYER_LAUNCH ? loader_done_sticky : layer_prefetch_ready;
    // M37: launch on the ready/descriptor-advance edge, not an empty L_GEMM cycle.
    // The registered start is consumed one edge later, after descriptors settle.
    wire layer_launch_gemm = FUSED_LAYER_LAUNCH
        ? ((layer_state == L_LOAD_WAIT && loader_done && !loader_error)
            || (layer_state == L_PREFETCH_WAIT && layer_prefetch_complete && !layer_prefetch_error)
            || (layer_state == L_ADVANCE && layer_n_offset + 8'd16 < layer_n))
        : layer_state == L_GEMM;

    wire loader_q_rd_en;
    wire [Q_HOST_ADDR_W-1:0] loader_q_rd_addr;
    wire [Q_HOST_ADDR_W-1:0] gather_q_addr[0:3];
    wire loader_a_wr_en;
    wire [A_ADDR_W-1:0] loader_a_wr_addr;
    wire [31:0] loader_a_wr_data;
    reg weight_loader_start;
    reg weight_loader_done_sticky;
    reg weight_loader_access_error;
    reg [15:0] weight_load_start_word;
    reg [7:0] weight_load_stride_words;
    wire weight_loader_busy;
    wire weight_loader_done;
    wire weight_loader_error;
    wire weight_loader_rd_en;
    wire [WEIGHT_ADDR_W-1:0] weight_loader_rd_addr;
    wire weight_loader_b_wr_en;
    wire [B_ADDR_W-1:0] weight_loader_b_wr_addr;
    wire [31:0] weight_loader_b_wr_data;
    reg gap_enable;
    reg gap_skip_source_write;
    reg gap_clear;
    reg gap_finalize;
    reg gap_done_sticky;
    reg gap_access_error;
    reg [Q_ADDR_W-1:0] gap_source_base;
    reg [Q_ADDR_W-1:0] gap_dest_base;
    reg [2:0] gap_length_log2;
    reg [POST_CH_W-1:0] gap_channels;
    wire gap_busy;
    wire gap_done;
    wire gap_error;
    wire gap_q_wr_en;
    wire [Q_ADDR_W-1:0] gap_q_wr_addr;
    wire [7:0] gap_q_wr_data;

    wire controller_busy;
    wire controller_done;
    wire controller_error;
    wire [31:0] controller_total_cycles;
    wire [31:0] controller_compute_cycles;
    wire post_busy;
    wire [POST_CH_W-2:0] post_result_channel;
    wire post_done;
    wire post_error;
    wire [31:0] post_total_cycles;
    wire [31:0] post_output_count;
    wire [31:0] post_saturation_count;

    wire a_rd_en;
    wire [A_ADDR_W-1:0] a_rd_addr;
    wire [TILE_ROWS*DATA_W-1:0] a_rd_data;
    wire b_rd_en;
    wire [B_ADDR_W-1:0] b_rd_addr;
    wire [TILE_COLS*DATA_W-1:0] b_rd_data;
    wire [TILE_COLS*DATA_W-1:0] b_buffer_rd_data;
    wire [N_W-1:0] b_rd_column_tile;
    wire [K_W-1:0] b_rd_k;
    wire c_wr_en;
    wire [C_ADDR_W-1:0] c_wr_addr;
    wire [ACC_W-1:0] c_wr_data;
    wire c_controller_rd_en;
    wire [C_ADDR_W-1:0] c_controller_rd_addr;
    wire [31:0] c_memory_rd_data;

    wire post_c_rd_en;
    wire [POST_C_ADDR_W-1:0] post_c_rd_addr;
    wire [POST_CH_W-2:0] post_parameter_channel;
    wire signed [31:0] post_parameter_bias;
    wire [4:0] post_parameter_right_shift;
    wire post_q_wr_en;
    wire [Q_ADDR_W-1:0] post_q_wr_addr;
    wire signed [7:0] post_q_wr_data;

    localparam integer WEIGHT_SPLIT=8192;
    (* ram_style = "block" *) reg [31:0] weight_low [0:WEIGHT_SPLIT-1];
    (* ram_style = "block" *) reg [31:0] weight_high [0:2047];
    (* ram_style = "distributed" *) reg signed [31:0] bias_memory [0:4*POST_MAX_CHANNELS-1];
    (* ram_style = "distributed" *) reg [4:0] shift_memory [0:4*POST_MAX_CHANNELS-1];

    initial begin
        if (WEIGHT_INIT_FILE != "") begin
            $readmemh("data/memory/occupancy_native/weight_init_low.hex", weight_low);
            $readmemh("data/memory/occupancy_native/weight_init_high.hex", weight_high);
        end
    end

    wire accelerator_active = layer_busy || chain_busy || controller_busy || post_busy || loader_busy
        || weight_loader_busy || gap_busy;

    wire [16:0] layer_output_end = { {(17-Q_ADDR_W){1'b0}}, post_cfg_q_base }
        + post_cfg_q_channel_stride * layer_n;
    wire [16:0] layer_next_input_end = layer_input_end + {1'b0, load_input_length};
    wire [16:0] layer_weight_end = {1'b0, weight_load_start_word}
        + ({{(17-K_W){1'b0}}, cfg_k} << weight_stride_log2);
    wire layer_descriptor_invalid = !CHAINED_POSTPROCESS || !DIRECT_WEIGHT_FEED
        || !PACKED_WINDOW_LOADER || !cfg_direct_weight || cfg_accumulate
        || cfg_m != (layer_m<16 ? layer_m : 16) || cfg_n != (layer_n<16 ? layer_n : 16)
        || post_cfg_positions != cfg_m || post_cfg_channels != cfg_n
        || cfg_k == 0 || cfg_k > MAX_K
        || layer_m == 0 || layer_m > POST_MAX_POSITIONS || layer_n == 0
        || layer_n > POST_MAX_CHANNELS
        || load_output_base != 0 || load_start_tap != 0
        || load_kernel == 0 || load_padding >= load_kernel
        || load_padding != 0 || post_cfg_pool_enable || gap_enable
        || load_input_length < load_kernel || layer_m != load_input_length-load_kernel+1
        || post_cfg_q_channel_stride != (post_cfg_pool_enable ? layer_m >> 1 : layer_m)
        || post_cfg_parameter_channel_base != 0
        || weight_load_stride_words == 0 || (weight_load_stride_words & (weight_load_stride_words-1)) != 0 || weight_load_stride_words < ((layer_n+3)>>2)
        || layer_output_end > Q_BYTES || layer_weight_end > WEIGHT_WORDS;
    wire accepting_request = bus_valid && !bus_ready && !c_read_pending
        && !q_read_pending && !weight_read_pending;
    wire a_window = (bus_addr >= A_BASE) && (bus_addr < B_BASE) && (bus_addr < A_BASE + A_WORDS*4);
    wire b_window = (bus_addr >= B_BASE) && (bus_addr < C_BASE) && (bus_addr < B_BASE + B_WORDS*4);
    wire c_window = (bus_addr >= C_BASE) && (bus_addr < Q_BASE) && (bus_addr < C_BASE + C_WORDS*4);
    wire q_window = (bus_addr >= Q_BASE) && (bus_addr < WEIGHT_BASE);
    wire weight_window = (bus_addr >= WEIGHT_BASE)
        && (bus_addr < WEIGHT_BASE + WEIGHT_WORDS*4);
    wire bias_window = (bus_addr >= BIAS_BASE)
        && (bus_addr < BIAS_BASE + POST_MAX_CHANNELS*4);
    wire shift_window = (bus_addr >= SHIFT_BASE)
        && (bus_addr < SHIFT_BASE + POST_MAX_CHANNELS*4);

    wire a_host_wr_en = accepting_request && a_window
        && (bus_wstrb == 4'b1111) && !accelerator_active;
    wire b_host_wr_en = !DIRECT_WEIGHT_ONLY && accepting_request && b_window
        && (bus_wstrb == 4'b1111) && !accelerator_active;
    wire bias_host_wr_en = accepting_request && bias_window
        && (bus_wstrb == 4'b1111) && !accelerator_active;
    wire shift_host_wr_en = accepting_request && shift_window
        && (bus_wstrb == 4'b1111) && !accelerator_active;
    wire q_host_wr_en = accepting_request && q_window
        && (bus_wstrb != 4'b0000) && !accelerator_active;
    wire weight_host_wr_en = accepting_request && weight_window
        && (bus_wstrb == 4'b1111) && !accelerator_active;
    wire c_host_rd_en = accepting_request && c_window
        && (bus_wstrb == 4'b0000) && !accelerator_active;
    wire q_host_rd_en = accepting_request && q_window
        && (bus_wstrb == 4'b0000) && !accelerator_active;
    wire weight_host_rd_en = accepting_request && weight_window
        && (bus_wstrb == 4'b0000) && !accelerator_active;

    wire [A_ADDR_W-1:0] a_host_addr = (bus_addr - A_BASE) >> 2;
    wire [B_ADDR_W-1:0] b_host_addr = (bus_addr - B_BASE) >> 2;
    wire [C_ADDR_W-1:0] c_host_addr = (bus_addr - C_BASE) >> 2;
    wire [Q_HOST_ADDR_W-1:0] q_host_addr = (bus_addr - Q_BASE) >> 2;
    wire [WEIGHT_ADDR_W-1:0] weight_host_addr = (bus_addr - WEIGHT_BASE) >> 2;
    wire [PARAM_ADDR_W-1:0] bias_host_addr = (bus_addr - BIAS_BASE) >> 2;
    wire [PARAM_ADDR_W-1:0] shift_host_addr = (bus_addr - SHIFT_BASE) >> 2;
    wire q_memory_rd_en = q_host_rd_en || loader_q_rd_en;
    wire [Q_HOST_ADDR_W-1:0] q_memory_rd_addr = loader_busy
        ? loader_q_rd_addr : q_host_addr;
    wire a_memory_wr_en = a_host_wr_en || loader_a_wr_en;
    wire [A_ADDR_W-1:0] a_memory_wr_addr = loader_busy
        ? loader_a_wr_addr : a_host_addr;
    wire [31:0] a_memory_wr_data = loader_busy
        ? loader_a_wr_data : bus_wdata;
    wire b_memory_wr_en = b_host_wr_en || weight_loader_b_wr_en;
    wire [B_ADDR_W-1:0] b_memory_wr_addr = weight_loader_busy
        ? weight_loader_b_wr_addr : b_host_addr;
    wire [31:0] b_memory_wr_data = weight_loader_busy
        ? weight_loader_b_wr_data : bus_wdata;
    // Frozen weights are K-major: one packed four-channel word per read.
    // Power-of-two stride avoids a multiply/divide in the per-cycle address path.
    wire direct_weight_active = DIRECT_WEIGHT_FEED && cfg_direct_weight && controller_busy;
    wire [16:0] direct_weight_formula = {1'b0, weight_load_start_word}
        + ({{(17-K_W){1'b0}}, b_rd_k} << weight_stride_log2)
        + {{(17-N_W){1'b0}}, b_rd_column_tile};
    // First beat of every PE tile uses its column base. Further prefetches
    // advance the previous word address, avoiding K+1 plus a variable shift.
    wire [16:0] direct_weight_address = INCREMENTAL_WEIGHT_ADDRESS
        ? (b_rd_k == 0
            ? ({1'b0, weight_load_start_word} + {{(17-N_W){1'b0}}, b_rd_column_tile})
            : ({{(17-WEIGHT_ADDR_W){1'b0}}, direct_weight_cursor}
                + {9'd0, weight_load_stride_words}))
        : direct_weight_formula;
    wire [16:0] direct_last_word = {1'b0, weight_load_start_word}
        + (({{(17-K_W){1'b0}}, cfg_k} - 17'd1) << weight_stride_log2)
        + ((({{(17-N_W){1'b0}}, cfg_n} + 17'd3) >> 2) - 17'd1);
    wire direct_stride_valid = weight_load_stride_words != 0
        && (weight_load_stride_words & (weight_load_stride_words - 8'd1)) == 0;
    wire direct_descriptor_invalid = DIRECT_WEIGHT_FEED && cfg_direct_weight
        && (!direct_stride_valid || cfg_n == 0 || cfg_k == 0
            || weight_load_start_word >= WEIGHT_WORDS || direct_last_word >= WEIGHT_WORDS);
    wire chain_descriptor_invalid = direct_descriptor_invalid || post_cfg_pool_enable || gap_enable || (post_cfg_q_base + (post_cfg_channels-1)*post_cfg_q_channel_stride + post_cfg_positions > Q_BYTES)
        || post_cfg_positions == 0 || post_cfg_positions > MAX_M
        || post_cfg_channels == 0 || post_cfg_channels > MAX_N
        || post_cfg_positions != cfg_m || post_cfg_channels != cfg_n;
    wire weight_memory_rd_en = weight_host_rd_en || weight_loader_rd_en
        || (direct_weight_active && b_rd_en);
    wire [WEIGHT_ADDR_W-1:0] weight_memory_rd_addr = direct_weight_active
        ? direct_weight_address[WEIGHT_ADDR_W-1:0]
        : (weight_loader_busy ? weight_loader_rd_addr : weight_host_addr);
    assign b_rd_data[31:0] = (DIRECT_WEIGHT_ONLY || direct_weight_active) ? weight_host_rd_data : b_buffer_rd_data[31:0];

    wire c_memory_rd_en = c_controller_rd_en || post_c_rd_en || c_host_rd_en;
    wire [C_ADDR_W-1:0] c_memory_rd_addr = c_controller_rd_en
        ? c_controller_rd_addr
        : (post_c_rd_en ? post_c_rd_addr[C_ADDR_W-1:0] : c_host_addr);

    assign m30_active = accelerator_active;
    assign m30_gemm = bus_addr==16'h0004 ? controller_total_cycles : layer_gemm_cycles;
    assign m30_compute = bus_addr==16'h0004 ? controller_compute_cycles : layer_compute_cycles;
    assign m30_post = layer_post_cycles;
    assign post_parameter_bias = bias_memory[{parameter_bank, post_parameter_channel}];
    assign post_parameter_right_shift = shift_memory[{parameter_bank, post_parameter_channel}];

    wire post_q_materialize = post_q_wr_en
        && !(gap_enable && gap_skip_source_write);
    wire [M_W-1:0] fused_row;
    wire [N_W-1:0] fused_column;
    wire fused_in_valid=c_wr_en && chain_state==CHAIN_GEMM;
    wire fused_out_valid, fused_ready, fused_saturated;
    wire signed [7:0] fused_value;
    wire [POST_CH_W-2:0] fused_parameter=post_cfg_parameter_channel_base+fused_column;
    reg [Q_ADDR_W-1:0] fused_addr_0, fused_addr_1, fused_addr_2;
    reg [2:0] fused_pending;
    int8_requantize_relu fused_quant (
        .clk(clk), .rst_n(rst_n), .in_valid(fused_in_valid), .in_ready(fused_ready),
        .mac_value(c_wr_data), .bias_value(bias_memory[{parameter_bank,fused_parameter}]),
        .right_shift(shift_memory[{parameter_bank,fused_parameter}]),
        .relu_enable(!post_cfg_relu_disable), .out_valid(fused_out_valid),
        .out_ready(1'b1), .out_value(fused_value), .saturated(fused_saturated)
    );
    always @(posedge clk) begin
        if(!rst_n) begin fused_pending<=0;fused_addr_0<=0;fused_addr_1<=0;fused_addr_2<=0;end
        else begin
            fused_pending<={fused_pending[1:0],fused_in_valid};
            if(fused_in_valid) fused_addr_0<=post_cfg_q_base+fused_column*post_cfg_q_channel_stride+fused_row;
            fused_addr_1<=fused_addr_0;fused_addr_2<=fused_addr_1;
        end
    end
    wire q_engine_wr_en = fused_out_valid || gap_q_wr_en || post_q_materialize;
    wire [Q_ADDR_W-1:0] q_engine_wr_addr = gap_q_wr_en
        ? gap_q_wr_addr : fused_out_valid ? fused_addr_2 : post_q_wr_addr;
    wire [7:0] q_engine_wr_data = gap_q_wr_en
        ? gap_q_wr_data : fused_out_valid ? fused_value : post_q_wr_data;
    wire [Q_HOST_ADDR_W-1:0] q_write_addr = q_engine_wr_en
        ? q_engine_wr_addr[Q_ADDR_W-1:2] : q_host_addr;
    wire [7:0] q_write_data_0 = q_engine_wr_en ? q_engine_wr_data : bus_wdata[7:0];
    wire [7:0] q_write_data_1 = q_engine_wr_en ? q_engine_wr_data : bus_wdata[15:8];
    wire [7:0] q_write_data_2 = q_engine_wr_en ? q_engine_wr_data : bus_wdata[23:16];
    wire [7:0] q_write_data_3 = q_engine_wr_en ? q_engine_wr_data : bus_wdata[31:24];
    wire q_write_en_0 = (q_engine_wr_en && q_engine_wr_addr[1:0] == 2'd0)
        || (q_host_wr_en && bus_wstrb[0]);
    wire q_write_en_1 = (q_engine_wr_en && q_engine_wr_addr[1:0] == 2'd1)
        || (q_host_wr_en && bus_wstrb[1]);
    wire q_write_en_2 = (q_engine_wr_en && q_engine_wr_addr[1:0] == 2'd2)
        || (q_host_wr_en && bus_wstrb[2]);
    wire q_write_en_3 = (q_engine_wr_en && q_engine_wr_addr[1:0] == 2'd3)
        || (q_host_wr_en && bus_wstrb[3]);
    wire [7:0] q_read_data_0;
    wire [7:0] q_read_data_1;
    wire [7:0] q_read_data_2;
    wire [7:0] q_read_data_3;
    wire [31:0] q_host_rd_data = {
        q_read_data_3, q_read_data_2, q_read_data_1, q_read_data_0
    };

    simple_dual_port_bram_8 #(.DEPTH(Q_HOST_WORDS), .ADDR_W(Q_HOST_ADDR_W)) q_bank_0 (
        .clk(clk), .wr_en(q_write_en_0), .wr_addr(q_write_addr),
        .wr_data(q_write_data_0), .rd_en(q_memory_rd_en), .rd_addr(loader_busy ? gather_q_addr[0] : q_memory_rd_addr),
        .rd_data(q_read_data_0)
    );
    simple_dual_port_bram_8 #(.DEPTH(Q_HOST_WORDS), .ADDR_W(Q_HOST_ADDR_W)) q_bank_1 (
        .clk(clk), .wr_en(q_write_en_1), .wr_addr(q_write_addr),
        .wr_data(q_write_data_1), .rd_en(q_memory_rd_en), .rd_addr(loader_busy ? gather_q_addr[1] : q_memory_rd_addr),
        .rd_data(q_read_data_1)
    );
    simple_dual_port_bram_8 #(.DEPTH(Q_HOST_WORDS), .ADDR_W(Q_HOST_ADDR_W)) q_bank_2 (
        .clk(clk), .wr_en(q_write_en_2), .wr_addr(q_write_addr),
        .wr_data(q_write_data_2), .rd_en(q_memory_rd_en), .rd_addr(loader_busy ? gather_q_addr[2] : q_memory_rd_addr),
        .rd_data(q_read_data_2)
    );
    simple_dual_port_bram_8 #(.DEPTH(Q_HOST_WORDS), .ADDR_W(Q_HOST_ADDR_W)) q_bank_3 (
        .clk(clk), .wr_en(q_write_en_3), .wr_addr(q_write_addr),
        .wr_data(q_write_data_3), .rd_en(q_memory_rd_en), .rd_addr(loader_busy ? gather_q_addr[3] : q_memory_rd_addr),
        .rd_data(q_read_data_3)
    );

    generate
        if (LAYER_INPUT_OVERLAP) begin : banked_a
            // Bank stride is 2**A_ADDR_W, not A_WORDS (K192 is non-power-of-two).
            simple_dual_port_bram_32 #(.DEPTH(1 << (A_ADDR_W+1)), .ADDR_W(A_ADDR_W+1)) a_buffer (
                .clk(clk), .wr_en(a_memory_wr_en),
                .wr_addr({layer_busy && layer_write_bank, a_memory_wr_addr}),
                .wr_data(a_memory_wr_data), .rd_en(a_rd_en),
                .rd_addr({layer_busy && layer_compute_bank, a_rd_addr}), .rd_data(a_rd_data[31:0])
            );
        end else begin : unbanked_a
            simple_dual_port_bram_32 #(.DEPTH(A_WORDS), .ADDR_W(A_ADDR_W)) a_buffer (
                .clk(clk), .wr_en(a_memory_wr_en), .wr_addr(a_memory_wr_addr),
                .wr_data(a_memory_wr_data), .rd_en(a_rd_en),
                .rd_addr(a_rd_addr), .rd_data(a_rd_data[31:0])
            );
        end
    endgenerate

    generate
        if (PACKED_WINDOW_LOADER != 0) begin : packed_window
            int8_input_window_loader_gather #(
                .MAX_M(MAX_M), .MAX_K(MAX_K), .Q_BYTES(Q_BYTES),
                .Q_WORD_ADDR_W(Q_HOST_ADDR_W), .A_ADDR_W(A_ADDR_W)
            ) input_window_loader (
                .clk(clk), .rst_n(rst_n), .start(loader_start),
                .cfg_tile_m(layer_busy ? (layer_m-load_output_base<16 ? layer_m-load_output_base : 8'd16) : {{(8-M_W){1'b0}}, cfg_m}),
                .cfg_tile_k({{(16-K_W){1'b0}}, cfg_k}),
                .cfg_output_base(load_output_base),
                .cfg_input_length(load_input_length), .cfg_kernel(load_kernel),
                .cfg_padding(load_padding), .cfg_channel_base(load_channel_base),
                .cfg_start_tap(load_start_tap), .busy(loader_busy),
                .done(loader_done), .error(loader_error),
                .q_rd_en(loader_q_rd_en), .q_rd_addr(loader_q_rd_addr),
                .q_rd_addr_0(gather_q_addr[0]), .q_rd_addr_1(gather_q_addr[1]),
                .q_rd_addr_2(gather_q_addr[2]), .q_rd_addr_3(gather_q_addr[3]),
                .q_rd_data(q_host_rd_data), .a_wr_en(loader_a_wr_en),
                .a_wr_addr(loader_a_wr_addr), .a_wr_data(loader_a_wr_data)
            );
        end else begin : serial_window
            int8_input_window_loader #(
                .MAX_M(MAX_M), .MAX_K(MAX_K), .Q_BYTES(Q_BYTES),
                .Q_WORD_ADDR_W(Q_HOST_ADDR_W), .A_ADDR_W(A_ADDR_W)
            ) input_window_loader (
                .clk(clk), .rst_n(rst_n), .start(loader_start),
                .cfg_tile_m(layer_busy ? (layer_m-load_output_base<16 ? layer_m-load_output_base : 8'd16) : {{(8-M_W){1'b0}}, cfg_m}),
                .cfg_tile_k({{(16-K_W){1'b0}}, cfg_k}),
                .cfg_output_base(load_output_base),
                .cfg_input_length(load_input_length), .cfg_kernel(load_kernel),
                .cfg_padding(load_padding), .cfg_channel_base(load_channel_base),
                .cfg_start_tap(load_start_tap), .busy(loader_busy),
                .done(loader_done), .error(loader_error),
                .q_rd_en(loader_q_rd_en), .q_rd_addr(loader_q_rd_addr),
                .q_rd_data(q_host_rd_data), .a_wr_en(loader_a_wr_en),
                .a_wr_addr(loader_a_wr_addr), .a_wr_data(loader_a_wr_data)
            );
        end
    endgenerate

    generate if (!DIRECT_WEIGHT_ONLY) begin: buffered_weights
    simple_dual_port_bram_32 #(.DEPTH(B_WORDS), .ADDR_W(B_ADDR_W)) b_buffer (
        .clk(clk), .wr_en(b_memory_wr_en), .wr_addr(b_memory_wr_addr),
        .wr_data(b_memory_wr_data),
        .rd_en(b_rd_en && !direct_weight_active), .rd_addr(b_rd_addr), .rd_data(b_buffer_rd_data[31:0])
    );

    end else begin: unbuffered_weights
        assign b_buffer_rd_data[31:0]=32'd0;
    end endgenerate

    // M29: preserve the four-byte software/loader layout and one-cycle reads.
    // Extra read replicas add bandwidth without repacking weights or inputs.
    // Physical resource reports must include this replication cost.
    genvar extra_a, extra_b;
    generate for (extra_a=1; extra_a<TILE_ROWS/4; extra_a=extra_a+1) begin: expanded_a
        wire [A_ADDR_W-1:0] read_address = a_rd_addr + extra_a*MAX_K;
        if (LAYER_INPUT_OVERLAP) begin: pingpong
            simple_dual_port_bram_32 #(.DEPTH(1 << (A_ADDR_W+1)), .ADDR_W(A_ADDR_W+1)) replica (
                .clk(clk), .wr_en(a_memory_wr_en),
                .wr_addr({layer_busy && layer_write_bank,a_memory_wr_addr}), .wr_data(a_memory_wr_data),
                .rd_en(a_rd_en), .rd_addr({layer_busy && layer_compute_bank,read_address}),
                .rd_data(a_rd_data[extra_a*32 +: 32]));
        end else begin: single_bank
            simple_dual_port_bram_32 #(.DEPTH(A_WORDS), .ADDR_W(A_ADDR_W)) replica (
                .clk(clk), .wr_en(a_memory_wr_en), .wr_addr(a_memory_wr_addr), .wr_data(a_memory_wr_data),
                .rd_en(a_rd_en), .rd_addr(read_address), .rd_data(a_rd_data[extra_a*32 +: 32]));
        end
    end
    for (extra_b=1; extra_b<TILE_COLS/4; extra_b=extra_b+1) begin: expanded_b
        wire [B_ADDR_W-1:0] read_address = b_rd_addr + extra_b*MAX_K;
        if (!DIRECT_WEIGHT_ONLY) begin: buffered_weights
        simple_dual_port_bram_32 #(.DEPTH(B_WORDS), .ADDR_W(B_ADDR_W)) replica (
            .clk(clk), .wr_en(b_memory_wr_en), .wr_addr(b_memory_wr_addr), .wr_data(b_memory_wr_data),
            .rd_en(b_rd_en && !direct_weight_active), .rd_addr(read_address),
            .rd_data(b_buffer_rd_data[extra_b*32 +: 32]));
        end else begin: unbuffered_weights
            assign b_buffer_rd_data[extra_b*32 +: 32]=32'd0;
        end
        if (SHARED_WEIGHT_PORTS && TILE_COLS==8) begin: shared_weight_port
            assign b_rd_data[extra_b*32 +: 32] = (DIRECT_WEIGHT_ONLY || direct_weight_active)
                ? weight_pair_rd_data : b_buffer_rd_data[extra_b*32 +: 32];
        end else begin: replicated_weight_port
            (* ram_style = "block" *) reg [31:0] weights [0:WEIGHT_WORDS-1];
            reg [31:0] read_data;
            wire [WEIGHT_ADDR_W:0] weight_address = {1'b0,weight_memory_rd_addr} + extra_b;
            initial if (WEIGHT_INIT_FILE != "") $readmemh(WEIGHT_INIT_FILE,weights);
            always @(posedge clk) begin
                if(weight_host_wr_en) weights[weight_host_addr] <= bus_wdata;
                if(weight_memory_rd_en) read_data <= weight_address < WEIGHT_WORDS ? weights[weight_address] : 32'd0;
            end
            assign b_rd_data[extra_b*32 +: 32] = (DIRECT_WEIGHT_ONLY || direct_weight_active) ? read_data : b_buffer_rd_data[extra_b*32 +: 32];
        end
    end endgenerate

    generate if (!DIRECT_WEIGHT_ONLY) begin: buffered_weight_loader
    int8_weight_tile_loader #(
        .MAX_N(MAX_N), .MAX_K(MAX_K), .WEIGHT_WORDS(WEIGHT_WORDS),
        .WEIGHT_ADDR_W(WEIGHT_ADDR_W), .B_ADDR_W(B_ADDR_W)
    ) weight_tile_loader (
        .clk(clk), .rst_n(rst_n), .start(weight_loader_start),
        .cfg_tile_n({{(8-N_W){1'b0}}, cfg_n}),
        .cfg_tile_k({{(16-K_W){1'b0}}, cfg_k}),
        .cfg_start_word(weight_load_start_word),
        .cfg_stride_words(weight_load_stride_words),
        .busy(weight_loader_busy), .done(weight_loader_done),
        .error(weight_loader_error), .weight_rd_en(weight_loader_rd_en),
        .weight_rd_addr(weight_loader_rd_addr),
        .weight_rd_data(weight_host_rd_data),
        .b_wr_en(weight_loader_b_wr_en),
        .b_wr_addr(weight_loader_b_wr_addr),
        .b_wr_data(weight_loader_b_wr_data)
    );

    end else begin: disabled_weight_loader
        assign weight_loader_busy=1'b0; assign weight_loader_done=1'b0;
        assign weight_loader_error=1'b0; assign weight_loader_rd_en=1'b0;
        assign weight_loader_rd_addr={WEIGHT_ADDR_W{1'b0}};
        assign weight_loader_b_wr_en=1'b0;
        assign weight_loader_b_wr_addr={B_ADDR_W{1'b0}};
        assign weight_loader_b_wr_data=32'd0;
    end endgenerate

    // Separate C banks: the next tile writes while the previous tile reads.
    // Legacy/manual commands always use bank zero. Only overwrite layers overlap.
    localparam integer C_BANK_BITS = LAYER_POST_OVERLAP ? 1 : 0;
    wire c_write_bank = layer_post_overlap && layer_busy && layer_c_compute_bank;
    wire c_read_bank = layer_post_overlap && layer_busy && post_c_rd_en
        && layer_c_post_bank;
    wire [C_ADDR_W+C_BANK_BITS-1:0] banked_c_write_addr = {c_write_bank,c_wr_addr};
    wire [C_ADDR_W+C_BANK_BITS-1:0] banked_c_read_addr = {c_read_bank,c_memory_rd_addr};
    simple_dual_port_bram_32 #(.DEPTH(C_WORDS << C_BANK_BITS),
        .ADDR_W(C_ADDR_W+C_BANK_BITS)) c_buffer (
        .clk(clk), .wr_en(c_wr_en), .wr_addr(banked_c_write_addr), .wr_data(c_wr_data),
        .rd_en(c_memory_rd_en), .rd_addr(banked_c_read_addr), .rd_data(c_memory_rd_data)
    );

    int8_gemm_controller #(
        .OVERLAP_WRITEBACK(OVERLAP_GEMM_WRITEBACK),
        .FUSED_TILE_HANDOFF(1),
        .DATA_W(DATA_W), .ACC_W(ACC_W), .TILE_ROWS(TILE_ROWS),
        .TILE_COLS(TILE_COLS), .MAX_M(MAX_M), .MAX_N(MAX_N), .MAX_K(MAX_K)
    ) controller (
        .clk(clk), .rst_n(rst_n), .start(controller_start), .cfg_m(cfg_m),
        .cfg_n(cfg_n), .cfg_k(cfg_k), .cfg_accumulate(cfg_accumulate),
        .busy(controller_busy), .done(controller_done), .error(controller_error),
        .a_rd_en(a_rd_en), .a_rd_addr(a_rd_addr), .a_rd_data(a_rd_data),
        .b_rd_en(b_rd_en), .b_rd_addr(b_rd_addr), .b_rd_data(b_rd_data),
        .b_rd_column_tile(b_rd_column_tile), .b_rd_k(b_rd_k),
        .c_wr_en(c_wr_en), .c_wr_addr(c_wr_addr), .c_wr_data(c_wr_data), .c_wr_row(fused_row), .c_wr_column(fused_column),
        .c_rd_en(c_controller_rd_en), .c_rd_addr(c_controller_rd_addr),
        .c_rd_data(c_memory_rd_data), .total_cycles(controller_total_cycles),
        .compute_cycles(controller_compute_cycles)
    );

    int8_layer_postprocess_controller #(
        .PIPELINED(PIPELINED_POSTPROCESS),
        .MAX_POSITIONS(POST_MAX_POSITIONS), .MAX_CHANNELS(POST_MAX_CHANNELS)
    ) postprocess_controller (
        .clk(clk), .rst_n(rst_n), .start(post_start),
        .cfg_positions(post_cfg_positions), .cfg_channels(post_cfg_channels),
        .cfg_pool_enable(post_cfg_pool_enable), .cfg_relu_disable(post_cfg_relu_disable),
        .cfg_parameter_channel_base(post_cfg_parameter_channel_base),
        .cfg_q_base(post_cfg_q_base),
        .cfg_q_channel_stride(post_cfg_q_channel_stride),
        .busy(post_busy), .done(post_done), .error(post_error),
        .c_rd_en(post_c_rd_en), .c_rd_addr(post_c_rd_addr),
        .c_rd_data(c_memory_rd_data), .parameter_channel(post_parameter_channel),
        .result_parameter_channel(post_result_channel),
        .parameter_bias(post_parameter_bias),
        .parameter_right_shift(post_parameter_right_shift),
        .q_wr_en(post_q_wr_en), .q_wr_addr(post_q_wr_addr),
        .q_wr_data(post_q_wr_data), .total_cycles(post_total_cycles),
        .output_count(post_output_count), .saturation_count(post_saturation_count)
    );

    generate if (ENABLE_STREAM_GAP) begin: enabled_stream_gap
    int8_stream_gap #(
        .Q_BYTES(Q_BYTES), .MAX_CHANNELS(POST_MAX_CHANNELS)
    ) stream_gap (
        .clk(clk), .rst_n(rst_n), .clear(gap_clear), .enable(gap_enable),
        .finalize(gap_finalize), .cfg_source_base(gap_source_base),
        .cfg_dest_base(gap_dest_base), .cfg_length_log2(gap_length_log2),
        .cfg_channels(gap_channels), .in_valid(post_q_wr_en),
        .in_addr(post_q_wr_addr),
        .in_channel({1'b0, post_result_channel}),
        .in_data(post_q_wr_data),
        .busy(gap_busy), .done(gap_done), .error(gap_error),
        .out_wr_en(gap_q_wr_en), .out_wr_addr(gap_q_wr_addr),
        .out_wr_data(gap_q_wr_data)
    );

    end else begin: disabled_stream_gap
        assign gap_busy=1'b0; assign gap_done=1'b0; assign gap_error=1'b0;
        assign gap_q_wr_en=1'b0; assign gap_q_wr_addr={Q_ADDR_W{1'b0}};
        assign gap_q_wr_data=8'sd0;
    end endgenerate

    // One logical image, two physical BRAM ports. Host writes are accepted
    // only while ALL engines are idle, so the read-address selector already
    // equals weight_host_addr on every accepted write. Sharing this address
    // is essential for a true dual-port inference, rather than three ports.
    generate if (SHARED_WEIGHT_PORTS && TILE_COLS==8) begin: shared_weight_ram
        wire [WEIGHT_ADDR_W:0] pair_address = {1'b0,weight_memory_rd_addr}+1'b1;
        always @(posedge clk) begin
            if(weight_host_wr_en && !weight_memory_rd_addr[13])weight_low[weight_memory_rd_addr[12:0]]<=bus_wdata;
            if(weight_host_wr_en && weight_memory_rd_addr[13])weight_high[weight_memory_rd_addr[10:0]]<=bus_wdata;
            if(weight_memory_rd_en) begin
                weight_sel0<=weight_memory_rd_addr[13];
                weight_low_rd0<=weight_low[weight_memory_rd_addr[12:0]];
                weight_high_rd0<=weight_high[weight_memory_rd_addr[10:0]];
            end
        end
        always @(posedge clk) begin
            if(direct_weight_active && b_rd_en) begin
                weight_sel1<=pair_address[13];weight_pair_valid<=pair_address<WEIGHT_WORDS;
                weight_low_rd1<=weight_low[pair_address[12:0]];
                weight_high_rd1<=weight_high[pair_address[10:0]];
            end
        end
    end else begin: legacy_weight_ram
        always @(posedge clk) begin
            if(weight_host_wr_en && !weight_host_addr[13])weight_low[weight_host_addr[12:0]]<=bus_wdata;
            if(weight_host_wr_en && weight_host_addr[13])weight_high[weight_host_addr[10:0]]<=bus_wdata;
            if(weight_memory_rd_en) begin
                weight_sel0<=weight_memory_rd_addr[13];
                weight_low_rd0<=weight_low[weight_memory_rd_addr[12:0]];
                weight_high_rd0<=weight_high[weight_memory_rd_addr[10:0]];
            end
        end
    end endgenerate

    always @(posedge clk) begin
        if (bias_host_wr_en)
            bias_memory[{parameter_bank, bias_host_addr}] <= bus_wdata;
        if (shift_host_wr_en)
            shift_memory[{parameter_bank, shift_host_addr}] <= bus_wdata[4:0];
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            cfg_m <= {M_W{1'b0}};
            parameter_bank <= 0;
            cfg_n <= {N_W{1'b0}};
            cfg_k <= {K_W{1'b0}};
            cfg_accumulate <= 1'b0;
            cfg_direct_weight <= (DIRECT_WEIGHT_ONLY != 0);
            weight_stride_log2 <= 3'd0;
            direct_weight_cursor <= {WEIGHT_ADDR_W{1'b0}};
            chain_state <= CHAIN_IDLE;
            chain_done_sticky <= 1'b0;
            chain_access_error <= 1'b0;
            layer_state <= L_IDLE;
            layer_c_compute_bank <= 0; layer_c_post_bank <= 0;
            layer_gemm_finished <= 0;
            layer_m <= 0; layer_n <= 0;
            layer_m_offset <= 0; layer_n_offset <= 0;
            layer_k_remaining <= 0; layer_input_end <= 0;
            layer_weight_base <= 0; layer_row_q_base <= 0;
            layer_done_sticky <= 0; layer_access_error <= 0;
            layer_total_cycles <= 0; layer_gemm_cycles <= 0;
            layer_compute_cycles <= 0; layer_post_cycles <= 0;
            layer_compute_bank <= 0; layer_write_bank <= 0;
            layer_prefetch_ready <= 0; layer_prefetch_error <= 0;
            controller_start <= 1'b0;
            done_sticky <= 1'b0;
            access_error <= 1'b0;
            post_cfg_positions <= {POST_POS_W{1'b0}};
            post_cfg_channels <= {POST_CH_W{1'b0}};
            post_cfg_pool_enable <= 1'b0; post_cfg_relu_disable <= 1'b0;
            post_cfg_parameter_channel_base <= {(POST_CH_W-1){1'b0}};
            post_cfg_q_base <= {Q_ADDR_W{1'b0}};
            post_cfg_q_channel_stride <= {POST_POS_W{1'b0}};
            post_start <= 1'b0;
            post_done_sticky <= 1'b0;
            post_access_error <= 1'b0;
            c_read_pending <= 1'b0;
            q_read_pending <= 1'b0;
            weight_read_pending <= 1'b0;
            loader_start <= 1'b0;
            loader_done_sticky <= 1'b0;
            loader_access_error <= 1'b0;
            load_output_base <= 16'd0;
            load_input_length <= 16'd0;
            load_kernel <= 8'd0;
            load_padding <= 8'd0;
            load_channel_base <= 16'd0;
            load_start_tap <= 8'd0;
            weight_loader_start <= 1'b0;
            weight_loader_done_sticky <= 1'b0;
            weight_loader_access_error <= 1'b0;
            weight_load_start_word <= 16'd0;
            weight_load_stride_words <= 8'd0;
            gap_enable <= 1'b0;
            gap_skip_source_write <= 1'b0;
            gap_clear <= 1'b0;
            gap_finalize <= 1'b0;
            gap_done_sticky <= 1'b0;
            gap_access_error <= 1'b0;
            gap_source_base <= {Q_ADDR_W{1'b0}};
            gap_dest_base <= {Q_ADDR_W{1'b0}};
            gap_length_log2 <= 3'd0;
            gap_channels <= {POST_CH_W{1'b0}};
            bus_ready <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            controller_start <= 1'b0;
            post_start <= 1'b0;
            loader_start <= 1'b0;
            weight_loader_start <= 1'b0;
            gap_clear <= 1'b0;
            gap_finalize <= 1'b0;
            bus_ready <= 1'b0;

            if (INCREMENTAL_WEIGHT_ADDRESS && direct_weight_active && b_rd_en)
                direct_weight_cursor <= direct_weight_address[WEIGHT_ADDR_W-1:0];

            if (controller_done)
                done_sticky <= 1'b1;
            if (post_done)
                post_done_sticky <= 1'b1;
            if (loader_done)
                loader_done_sticky <= 1'b1;
            if (loader_done && loader_error)
                loader_access_error <= 1'b1;
            if (weight_loader_done)
                weight_loader_done_sticky <= 1'b1;
            if (weight_loader_done && weight_loader_error)
                weight_loader_access_error <= 1'b1;
            if (gap_done)
                gap_done_sticky <= 1'b1;

            if (layer_busy) begin
                layer_total_cycles <= layer_total_cycles + 1'b1;
                if (loader_done) begin
                    if (!FUSED_LAYER_LAUNCH) layer_prefetch_ready <= 1;
                    if (loader_error) layer_prefetch_error <= 1;
                end
                if (controller_done) begin
                    layer_gemm_cycles <= layer_gemm_cycles + controller_total_cycles;
                    layer_compute_cycles <= layer_compute_cycles + controller_compute_cycles;
                end
                if (post_done) layer_post_cycles <= layer_post_cycles + post_total_cycles;
                case (layer_state)
                    L_VALIDATE: begin
                        // Count input channels without a divider. Validate the
                        // complete source/destination intervals before any write.
                        layer_input_end <= layer_next_input_end;
                        if (layer_next_input_end > Q_BYTES) begin
                            layer_access_error <= 1;
                            layer_done_sticky <= 1;
                            layer_state <= L_IDLE;
                        end else if (layer_k_remaining <= load_kernel) begin
                            if (load_channel_base < layer_output_end
                                && post_cfg_q_base < layer_next_input_end) begin
                                layer_access_error <= 1;
                                layer_done_sticky <= 1;
                                layer_state <= L_IDLE;
                            end else layer_state <= L_LOAD;
                        end else layer_k_remaining <= layer_k_remaining - load_kernel;
                    end
                    L_LOAD: begin
                        loader_start <= 1;
                        loader_done_sticky <= 0;
                        layer_state <= L_LOAD_WAIT;
                    end
                    L_LOAD_WAIT: if (loader_done) begin
                        if (loader_error) begin
                            layer_access_error <= 1;
                            layer_done_sticky <= !layer_post_overlap;
                            layer_state <= layer_post_overlap ? L_PIPE_ERROR : L_IDLE;
                        end else layer_state <= FUSED_LAYER_LAUNCH ? L_POST_WAIT : L_GEMM;
                    end
                    L_GEMM: begin end // legacy launch handled below
                    L_POST_WAIT: begin
                        if (layer_post_overlap) begin
                            if (!FUSED_LAYER_LAUNCH && controller_done) layer_gemm_finished <= 1;
                            if (controller_done && controller_error) begin
                                layer_access_error <= 1; layer_state <= L_PIPE_ERROR;
                            end else if ((FUSED_LAYER_LAUNCH
                                    ? (!controller_busy && !controller_start)
                                    : (controller_done || layer_gemm_finished))
                                && !post_busy && !post_start) begin
                                // Post captures all descriptors on the following edge,
                                // before L_ADVANCE changes them for the next GEMM.
                                layer_c_post_bank <= layer_c_compute_bank;
                                post_start <= 1; post_done_sticky <= 0;
                                layer_state <= L_ADVANCE;
                            end
                        end else if (controller_done && controller_error) begin
                            layer_access_error <= 1; layer_done_sticky <= 1;
                            layer_state <= L_IDLE;
                        end else if (chain_done_sticky) begin
                            if (chain_access_error) begin
                                layer_access_error <= 1; layer_done_sticky <= 1;
                                layer_state <= L_IDLE;
                            end else layer_state <= L_ADVANCE;
                        end
                    end
                    L_ADVANCE: begin
                        if (layer_post_overlap && (layer_n_offset + 8'd16 < layer_n
                            || layer_m_offset + 8'd16 < layer_m))
                            layer_c_compute_bank <= !layer_c_compute_bank;
                        if (layer_n_offset + 8'd16 < layer_n) begin
                            layer_n_offset <= layer_n_offset + 8'd16;
                            cfg_n <= layer_n-layer_n_offset-16<16 ? layer_n-layer_n_offset-16 : 16;
                            post_cfg_channels <= layer_n-layer_n_offset-16<16 ? layer_n-layer_n_offset-16 : 16;
                            weight_load_start_word <= weight_load_start_word + 16'd4;
                            post_cfg_parameter_channel_base <= post_cfg_parameter_channel_base + 16;
                            post_cfg_q_base <= post_cfg_q_base + (post_cfg_q_channel_stride << 4);
                            layer_state <= FUSED_LAYER_LAUNCH ? L_POST_WAIT : L_GEMM;
                        end else if (layer_m_offset + 8'd16 < layer_m) begin
                            layer_m_offset <= layer_m_offset + 8'd16;
                            cfg_m <= layer_m-layer_m_offset-16<16 ? layer_m-layer_m_offset-16 : 16;
                            post_cfg_positions <= layer_m-layer_m_offset-16<16 ? layer_m-layer_m_offset-16 : 16;
                            cfg_n <= layer_n<16 ? layer_n : 16;
                            post_cfg_channels <= layer_n<16 ? layer_n : 16;
                            layer_n_offset <= 0;
                            if (!LAYER_INPUT_OVERLAP)
                                load_output_base <= load_output_base + 16'd16;
                            weight_load_start_word <= layer_weight_base;
                            post_cfg_parameter_channel_base <= 0;
                            layer_row_q_base <= layer_row_q_base + (post_cfg_pool_enable ? 8 : 16);
                            post_cfg_q_base <= layer_row_q_base + (post_cfg_pool_enable ? 8 : 16);
                            if (LAYER_INPUT_OVERLAP) begin
                                layer_compute_bank <= !layer_compute_bank;
                                layer_state <= L_PREFETCH_WAIT;
                            end else layer_state <= L_LOAD;
                        end else if (layer_post_overlap) layer_state <= L_PIPE_DRAIN;
                        else begin
                            layer_done_sticky <= 1;
                            layer_state <= L_IDLE;
                        end
                    end
                    L_PIPE_DRAIN: if (post_done) begin
                        if (post_error) layer_access_error <= 1;
                        layer_done_sticky <= 1; layer_state <= L_IDLE;
                    end
                    L_PIPE_ERROR: if (!controller_busy && !post_busy && !post_start
                        && !loader_busy && !loader_start) begin
                        layer_done_sticky <= 1; layer_state <= L_IDLE;
                    end
                    L_PREFETCH_WAIT: if (layer_prefetch_complete) begin
                        if (layer_prefetch_error) begin
                            layer_access_error <= 1;
                            layer_done_sticky <= !layer_post_overlap;
                            layer_state <= layer_post_overlap ? L_PIPE_ERROR : L_IDLE;
                        end else layer_state <= FUSED_LAYER_LAUNCH ? L_POST_WAIT : L_GEMM;
                    end
                    default: begin layer_access_error <= 1; layer_done_sticky <= 1; layer_state <= L_IDLE; end
                endcase
                if (layer_launch_gemm) begin
                        controller_start <= 1;
                        done_sticky <= 0; post_done_sticky <= 0;
                        chain_done_sticky <= 0;
                        if (!layer_post_overlap) chain_state <= CHAIN_GEMM;
                        layer_gemm_finished <= 0;
                        if (LAYER_INPUT_OVERLAP && (!FUSED_LAYER_LAUNCH || layer_state != L_ADVANCE)
                            && layer_n_offset == 0
                            && layer_m_offset + 8'd16 < layer_m) begin
                            // Read the validated source Q while the current
                            // tile computes, writing only the inactive A bank.
                            layer_write_bank <= !layer_compute_bank;
                            load_output_base <= {8'd0, layer_m_offset} + 16'd16;
                            layer_prefetch_ready <= 0;
                            layer_prefetch_error <= 0;
                            loader_start <= 1;
                            loader_done_sticky <= 0;
                        end
                        layer_state <= L_POST_WAIT;
                end
                // Preserve C ownership while draining a failed overlapped tile.
                if (layer_post_overlap && post_done && post_error) begin
                    layer_access_error <= 1; layer_state <= L_PIPE_ERROR;
                    controller_start <= 0; post_start <= 0;
                end
            end

            // Keep ownership across the one-cycle GEMM -> POST handoff.
            // POST reads C only after the GEMM controller has finished writeback.
            if (CHAINED_POSTPROCESS) begin
                case (chain_state)
                    CHAIN_GEMM: if (controller_done) begin
                        if (controller_error) begin
                            chain_access_error <= 1'b1;
                            chain_done_sticky <= 1'b1;
                            chain_state <= CHAIN_IDLE;
                        end else begin
                            post_done_sticky <= 1'b0;
                            chain_state <= CHAIN_POST;
                        end
                    end
                    CHAIN_POST: if (fused_pending==0 && !fused_out_valid) begin
                        post_done_sticky <= 1'b1;
                        chain_done_sticky <= 1'b1;
                        chain_state <= CHAIN_IDLE;
                    end
                    default: begin end
                endcase
            end

            if (c_read_pending) begin
                bus_rdata <= c_memory_rd_data;
                bus_ready <= 1'b1;
                c_read_pending <= 1'b0;
            end else if (q_read_pending) begin
                bus_rdata <= q_host_rd_data;
                bus_ready <= 1'b1;
                q_read_pending <= 1'b0;
            end else if (weight_read_pending) begin
                bus_rdata <= weight_host_rd_data;
                bus_ready <= 1'b1;
                weight_read_pending <= 1'b0;
            end else if (accepting_request) begin
                if (bus_wstrb != 4'b0000) begin
                    bus_ready <= 1'b1;
                    if (layer_busy) begin
                        // Preserve ownership even between engines. An illegal
                        // host write is acknowledged/rejected, never forwarded.
                        layer_access_error <= 1'b1;
                    end else if (bus_addr == 16'h00c4) begin
                        if (!accelerator_active && bus_wstrb==4'hf && bus_wdata<4)
                            parameter_bank <= bus_wdata[1:0];
                        else post_access_error <= 1;
                    end else if (bus_addr == REG_LAYER_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (accelerator_active) layer_access_error <= 1;
                            else begin
                                if (bus_wdata[1]) begin
                                    layer_done_sticky <= 0; layer_access_error <= 0;
                                end
                                if (bus_wdata[0]) begin
                                    layer_done_sticky <= 0;
                                    layer_access_error <= 0;
                                    layer_total_cycles <= 0; layer_gemm_cycles <= 0;
                                    layer_compute_cycles <= 0; layer_post_cycles <= 0;
                                    if (!AUTONOMOUS_LAYER || layer_descriptor_invalid) begin
                                        layer_done_sticky <= 1; layer_access_error <= 1;
                                    end else begin
                                        layer_m_offset <= 0; layer_n_offset <= 0;
                                        layer_k_remaining <= {1'b0, cfg_k};
                                        layer_input_end <= {1'b0, load_channel_base};
                                        layer_weight_base <= weight_load_start_word;
                                        layer_row_q_base <= post_cfg_q_base;
                                        layer_compute_bank <= 0; layer_write_bank <= 0;
                                        layer_c_compute_bank <= 0; layer_c_post_bank <= 0;
                                        layer_gemm_finished <= 0;
                                        layer_prefetch_ready <= 0; layer_prefetch_error <= 0;
                                        layer_state <= L_VALIDATE;
                                    end
                                end
                            end
                        end
                    end else if (bus_addr == REG_LAYER_M) begin
                        if (!accelerator_active) layer_m <= bus_wdata[7:0];
                        else layer_access_error <= 1;
                    end else if (bus_addr == REG_LAYER_N) begin
                        if (!accelerator_active) layer_n <= bus_wdata[7:0];
                        else layer_access_error <= 1;
                    end else if (bus_addr == REG_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (bus_wdata[1] && !chain_busy) begin
                                done_sticky <= 1'b0;
                                access_error <= 1'b0;
                            end
                            if (chain_busy) access_error <= 1'b1;
                            if (bus_wdata[0]) begin
                                if (chain_busy || post_busy || loader_busy || weight_loader_busy || gap_busy)
                                    access_error <= 1'b1;
                                else if (direct_descriptor_invalid) begin
                                    done_sticky <= 1'b1;
                                    access_error <= 1'b1;
                                end else begin
                                    controller_start <= 1'b1;
                                    done_sticky <= 1'b0;
                                end
                            end
                        end
                    end else if (bus_addr == REG_POST_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (bus_wdata[1] && !chain_busy) begin
                                post_done_sticky <= 1'b0;
                                post_access_error <= 1'b0;
                            end
                            if (chain_busy) post_access_error <= 1'b1;
                            if (bus_wdata[0]) begin
                                if (chain_busy || controller_busy || post_busy || loader_busy
                                    || weight_loader_busy || gap_busy
                                    || (post_cfg_positions == 0)
                                    || (post_cfg_positions > MAX_M)
                                    || (post_cfg_channels == 0)
                                    || (post_cfg_channels > MAX_N)) begin
                                    post_done_sticky <= 1'b1;
                                    post_access_error <= 1'b1;
                                end else begin
                                    post_start <= 1'b1;
                                    post_done_sticky <= 1'b0;
                                end
                            end
                        end
                    end else if (bus_addr == REG_CHAIN_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (accelerator_active) chain_access_error <= 1'b1;
                            else begin
                                if (bus_wdata[1]) begin
                                    chain_done_sticky <= 1'b0;
                                    chain_access_error <= 1'b0;
                                end
                                if (bus_wdata[0]) begin
                                    if (!CHAINED_POSTPROCESS || chain_descriptor_invalid) begin
                                        chain_done_sticky <= 1'b1;
                                        chain_access_error <= 1'b1;
                                    end else begin
                                        controller_start <= 1'b1;
                                        done_sticky <= 1'b0;
                                        post_done_sticky <= 1'b0;
                                        chain_done_sticky <= 1'b0;
                                        chain_state <= CHAIN_GEMM;
                                    end
                                end
                            end
                        end
                    end else if (bus_addr == REG_M) begin
                        if (!accelerator_active) cfg_m <= bus_wdata[M_W-1:0];
                        else access_error <= 1'b1;
                    end else if (bus_addr == REG_N) begin
                        if (!accelerator_active) cfg_n <= bus_wdata[N_W-1:0];
                        else access_error <= 1'b1;
                    end else if (bus_addr == REG_K) begin
                        if (!accelerator_active) cfg_k <= bus_wdata[K_W-1:0];
                        else access_error <= 1'b1;
                    end else if (bus_addr == REG_MODE) begin
                        if (!accelerator_active) cfg_accumulate <= bus_wdata[0];
                        else access_error <= 1'b1;
                    end else if (bus_addr == REG_DIRECT_WEIGHT) begin
                        if (!accelerator_active && (!DIRECT_WEIGHT_ONLY || bus_wdata[0]) && (!bus_wdata[0] || DIRECT_WEIGHT_FEED))
                            cfg_direct_weight <= bus_wdata[0];
                        else access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_POSITIONS) begin
                        if (!accelerator_active) post_cfg_positions <= bus_wdata[POST_POS_W-1:0];
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_CHANNELS) begin
                        if (!accelerator_active) post_cfg_channels <= bus_wdata[POST_CH_W-1:0];
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_OPTIONS) begin
                        if (!accelerator_active) begin post_cfg_pool_enable <= bus_wdata[0]; post_cfg_relu_disable <= bus_wdata[1]; end
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_PARAM_BASE) begin
                        if (!accelerator_active)
                            post_cfg_parameter_channel_base <= bus_wdata[POST_CH_W-2:0];
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_Q_BASE) begin
                        if (!accelerator_active) post_cfg_q_base <= bus_wdata[Q_ADDR_W-1:0];
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_POST_Q_STRIDE) begin
                        if (!accelerator_active)
                            post_cfg_q_channel_stride <= bus_wdata[POST_POS_W-1:0];
                        else post_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (bus_wdata[1]) begin
                                loader_done_sticky <= 1'b0;
                                loader_access_error <= 1'b0;
                            end
                            if (bus_wdata[0]) begin
                                // A loader owns Q-read/A-write; the weight loader
                                // owns weight-read/B-write. Their ports are disjoint.
                                if (chain_busy || controller_busy || post_busy || gap_busy
                                    || loader_busy || loader_start
                                    || (!ALLOW_LOADER_OVERLAP && weight_loader_busy)) begin
                                    loader_done_sticky <= 1'b1;
                                    loader_access_error <= 1'b1;
                                end else begin
                                    loader_start <= 1'b1;
                                    loader_done_sticky <= 1'b0;
                                end
                            end
                        end
                    end else if (bus_addr == REG_LOAD_OUTPUT_BASE) begin
                        if (!accelerator_active) load_output_base <= bus_wdata[15:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_INPUT_LENGTH) begin
                        if (!accelerator_active) load_input_length <= bus_wdata[15:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_KERNEL) begin
                        if (!accelerator_active) load_kernel <= bus_wdata[7:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_PADDING) begin
                        if (!accelerator_active) load_padding <= bus_wdata[7:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_CHANNEL_BASE) begin
                        if (!accelerator_active) load_channel_base <= bus_wdata[15:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_LOAD_START_TAP) begin
                        if (!accelerator_active) load_start_tap <= bus_wdata[7:0];
                        else loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_WLOAD_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (bus_wdata[1]) begin
                                weight_loader_done_sticky <= 1'b0;
                                weight_loader_access_error <= 1'b0;
                            end
                            if (bus_wdata[0]) begin
                                if (DIRECT_WEIGHT_ONLY || chain_busy || controller_busy || post_busy || gap_busy
                                    || weight_loader_busy || weight_loader_start
                                    || (!ALLOW_LOADER_OVERLAP && loader_busy)) begin
                                    weight_loader_done_sticky <= 1'b1;
                                    weight_loader_access_error <= 1'b1;
                                end else begin
                                    weight_loader_start <= 1'b1;
                                    weight_loader_done_sticky <= 1'b0;
                                end
                            end
                        end
                    end else if (bus_addr == REG_WLOAD_START_WORD) begin
                        if (!accelerator_active)
                            weight_load_start_word <= bus_wdata[15:0];
                        else weight_loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_WLOAD_STRIDE) begin
                        if (!accelerator_active) begin
                            weight_load_stride_words <= bus_wdata[7:0];
                            case (bus_wdata[7:0])
                                8'd2: weight_stride_log2 <= 3'd1;
                                8'd4: weight_stride_log2 <= 3'd2;
                                8'd8: weight_stride_log2 <= 3'd3;
                                8'd16: weight_stride_log2 <= 3'd4;
                                8'd32: weight_stride_log2 <= 3'd5;
                                8'd64: weight_stride_log2 <= 3'd6;
                                8'd128: weight_stride_log2 <= 3'd7;
                                default: weight_stride_log2 <= 3'd0;
                            endcase
                        end else weight_loader_access_error <= 1'b1;
                    end else if (bus_addr == REG_GAP_CONTROL) begin
                        if (bus_wstrb[0]) begin
                            if (!ENABLE_STREAM_GAP) begin
                                if (bus_wdata[1]) gap_access_error <= 1'b0;
                                if (bus_wdata[0] || bus_wdata[2] || bus_wdata[3]) gap_access_error <= 1'b1;
                            end else if (accelerator_active) gap_access_error <= 1'b1;
                            else begin
                                gap_enable <= bus_wdata[0];
                                gap_skip_source_write <= bus_wdata[3];
                                if (bus_wdata[1]) begin
                                    gap_clear <= 1'b1;
                                    gap_done_sticky <= 1'b0;
                                    gap_access_error <= 1'b0;
                                end
                                if (bus_wdata[2]) begin
                                    gap_finalize <= 1'b1;
                                    gap_done_sticky <= 1'b0;
                                end
                            end
                        end
                    end else if (bus_addr == REG_GAP_SOURCE_BASE) begin
                        if (!accelerator_active) gap_source_base <= bus_wdata[Q_ADDR_W-1:0];
                        else gap_access_error <= 1'b1;
                    end else if (bus_addr == REG_GAP_DEST_BASE) begin
                        if (!accelerator_active) gap_dest_base <= bus_wdata[Q_ADDR_W-1:0];
                        else gap_access_error <= 1'b1;
                    end else if (bus_addr == REG_GAP_LENGTH_LOG2) begin
                        if (!accelerator_active) gap_length_log2 <= bus_wdata[2:0];
                        else gap_access_error <= 1'b1;
                    end else if (bus_addr == REG_GAP_CHANNELS) begin
                        if (!accelerator_active) gap_channels <= bus_wdata[POST_CH_W-1:0];
                        else gap_access_error <= 1'b1;
                    end else if (a_window || b_window) begin
                        if ((DIRECT_WEIGHT_ONLY && b_window) || accelerator_active || (bus_wstrb != 4'b1111))
                            access_error <= 1'b1;
                    end else if (q_window) begin
                        if (accelerator_active)
                            post_access_error <= 1'b1;
                    end else if (weight_window) begin
                        if (accelerator_active || (bus_wstrb != 4'b1111))
                            access_error <= 1'b1;
                    end else if (bias_window || shift_window) begin
                        if (accelerator_active || (bus_wstrb != 4'b1111))
                            post_access_error <= 1'b1;
                    end else begin
                        access_error <= 1'b1;
                    end
                end else if (c_window) begin
                    if (accelerator_active) begin
                        bus_ready <= 1'b1;
                        bus_rdata <= 32'd0;
                        access_error <= 1'b1;
                    end else
                        c_read_pending <= 1'b1;
                end else if (q_window) begin
                    if (accelerator_active) begin
                        bus_ready <= 1'b1;
                        bus_rdata <= 32'd0;
                        post_access_error <= 1'b1;
                    end else
                        q_read_pending <= 1'b1;
                end else if (weight_window) begin
                    if (accelerator_active) begin
                        bus_ready <= 1'b1;
                        bus_rdata <= 32'd0;
                        access_error <= 1'b1;
                    end else
                        weight_read_pending <= 1'b1;
                end else begin
                    bus_ready <= 1'b1;
                    if (bus_addr == 16'h00c4) bus_rdata <= {30'd0,parameter_bank};
                    else if (bus_addr == REG_STATUS)
                        bus_rdata <= {29'd0, (controller_error | access_error),
                                      done_sticky, controller_busy};
                    else if (bus_addr == REG_M)
                        bus_rdata <= {{(32-M_W){1'b0}}, cfg_m};
                    else if (bus_addr == REG_N)
                        bus_rdata <= {{(32-N_W){1'b0}}, cfg_n};
                    else if (bus_addr == REG_K)
                        bus_rdata <= {{(32-K_W){1'b0}}, cfg_k};
                    else if (bus_addr == REG_TOTAL)
                        bus_rdata <= controller_total_cycles;
                    else if (bus_addr == REG_COMPUTE)
                        bus_rdata <= controller_compute_cycles;
                    else if (bus_addr == REG_VERSION)
                        bus_rdata <= 32'h52414934;
                    else if (bus_addr == REG_MODE)
                        bus_rdata <= {31'd0, cfg_accumulate};
                    else if (bus_addr == REG_POST_STATUS)
                        bus_rdata <= {29'd0, (post_error | post_access_error),
                                      post_done_sticky, post_busy};
                    else if (bus_addr == REG_POST_POSITIONS)
                        bus_rdata <= {{(32-POST_POS_W){1'b0}}, post_cfg_positions};
                    else if (bus_addr == REG_POST_CHANNELS)
                        bus_rdata <= {{(32-POST_CH_W){1'b0}}, post_cfg_channels};
                    else if (bus_addr == REG_POST_OPTIONS)
                        bus_rdata <= {30'd0, post_cfg_relu_disable, post_cfg_pool_enable};
                    else if (bus_addr == REG_POST_PARAM_BASE)
                        bus_rdata <= {{(33-POST_CH_W){1'b0}}, post_cfg_parameter_channel_base};
                    else if (bus_addr == REG_POST_Q_BASE)
                        bus_rdata <= {{(32-Q_ADDR_W){1'b0}}, post_cfg_q_base};
                    else if (bus_addr == REG_POST_Q_STRIDE)
                        bus_rdata <= {{(32-POST_POS_W){1'b0}}, post_cfg_q_channel_stride};
                    else if (bus_addr == REG_POST_TOTAL)
                        bus_rdata <= post_total_cycles;
                    else if (bus_addr == REG_POST_OUTPUTS)
                        bus_rdata <= post_output_count;
                    else if (bus_addr == REG_POST_SATURATIONS)
                        bus_rdata <= post_saturation_count;
                    else if (bus_addr == REG_LOAD_STATUS)
                        bus_rdata <= {29'd0, loader_access_error,
                                      loader_done_sticky, loader_busy};
                    else if (bus_addr == REG_LOAD_OUTPUT_BASE)
                        bus_rdata <= {16'd0, load_output_base};
                    else if (bus_addr == REG_LOAD_INPUT_LENGTH)
                        bus_rdata <= {16'd0, load_input_length};
                    else if (bus_addr == REG_LOAD_KERNEL)
                        bus_rdata <= {24'd0, load_kernel};
                    else if (bus_addr == REG_LOAD_PADDING)
                        bus_rdata <= {24'd0, load_padding};
                    else if (bus_addr == REG_LOAD_CHANNEL_BASE)
                        bus_rdata <= {16'd0, load_channel_base};
                    else if (bus_addr == REG_LOAD_START_TAP)
                        bus_rdata <= {24'd0, load_start_tap};
                    else if (bus_addr == REG_WLOAD_STATUS)
                        bus_rdata <= {29'd0, weight_loader_access_error,
                                      weight_loader_done_sticky, weight_loader_busy};
                    else if (bus_addr == REG_WLOAD_START_WORD)
                        bus_rdata <= {16'd0, weight_load_start_word};
                    else if (bus_addr == REG_WLOAD_STRIDE)
                        bus_rdata <= {24'd0, weight_load_stride_words};
                    else if (bus_addr == REG_GAP_STATUS)
                        bus_rdata <= {29'd0, (gap_error | gap_access_error),
                                      gap_done_sticky, gap_busy};
                    else if (bus_addr == REG_GAP_SOURCE_BASE)
                        bus_rdata <= {{(32-Q_ADDR_W){1'b0}}, gap_source_base};
                    else if (bus_addr == REG_GAP_DEST_BASE)
                        bus_rdata <= {{(32-Q_ADDR_W){1'b0}}, gap_dest_base};
                    else if (bus_addr == REG_GAP_LENGTH_LOG2)
                        bus_rdata <= {29'd0, gap_length_log2};
                    else if (bus_addr == REG_GAP_CHANNELS)
                        bus_rdata <= {{(32-POST_CH_W){1'b0}}, gap_channels};
                    else if (bus_addr == REG_DIRECT_WEIGHT)
                        bus_rdata <= {DIRECT_WEIGHT_FEED != 0, 30'd0, cfg_direct_weight};
                    else if (bus_addr == REG_CHAIN_CONTROL)
                        bus_rdata <= {CHAINED_POSTPROCESS != 0, 31'd0};
                    else if (bus_addr == REG_CHAIN_STATUS)
                        bus_rdata <= {29'd0, (chain_access_error | controller_error
                                      | post_error | access_error | post_access_error),
                                      chain_done_sticky, chain_busy};
                    else if (bus_addr == REG_LAYER_CONTROL)
                        bus_rdata <= {AUTONOMOUS_LAYER != 0, 31'd0};
                    else if (bus_addr == REG_LAYER_STATUS)
                        bus_rdata <= {29'd0, layer_access_error, layer_done_sticky, layer_busy};
                    else if (bus_addr == REG_LAYER_M) bus_rdata <= {24'd0, layer_m};
                    else if (bus_addr == REG_LAYER_N) bus_rdata <= {24'd0, layer_n};
                    else if (bus_addr == REG_LAYER_TOTAL) bus_rdata <= layer_total_cycles;
                    else if (bus_addr == REG_LAYER_GEMM) bus_rdata <= layer_gemm_cycles;
                    else if (bus_addr == REG_LAYER_COMPUTE) bus_rdata <= layer_compute_cycles;
                    else if (bus_addr == REG_LAYER_POST) bus_rdata <= layer_post_cycles;
                    else begin
                        bus_rdata <= 32'd0;
                        access_error <= 1'b1;
                    end
                end
            end
        end
    end

endmodule

`timescale 1ns/1ps

module int8_accelerator_mmio #(
    parameter integer MAX_M = 16,
    parameter integer MAX_N = 16,
    parameter integer MAX_K = 64,
    parameter integer ALLOW_LOADER_OVERLAP = 0,
    parameter integer PIPELINED_POSTPROCESS = 0,
    parameter integer DIRECT_WEIGHT_FEED = 0,
    parameter integer CHAINED_POSTPROCESS = 0,
    parameter integer INCREMENTAL_WEIGHT_ADDRESS = 0,
    parameter integer AUTONOMOUS_LAYER = 0,
    parameter integer LAYER_POST_OVERLAP = 1,
    parameter integer LAYER_INPUT_OVERLAP = 0,
    parameter integer PACKED_READ_PIPELINE = 0,
    parameter integer OVERLAP_GEMM_WRITEBACK = 0,
    parameter integer ZERO_LANE_ADVANCE_OPT = 0,
    parameter integer SHARED_WEIGHT_PORTS = 1,
    parameter integer ENABLE_STREAM_GAP = 0,
    parameter integer DIRECT_WEIGHT_ONLY = 1,
    parameter integer FUSED_LAYER_LAUNCH = 1,
    parameter integer TILE_ROWS = 4,
    parameter integer TILE_COLS = 4,
    parameter integer DATA_W = 8,
    parameter integer ACC_W = 32,
    parameter integer POST_MAX_POSITIONS = 128,
    parameter integer POST_MAX_CHANNELS = 64,
    parameter integer WEIGHT_BYTES = 23232,
    parameter integer PACKED_WINDOW_LOADER = 0,
    parameter WEIGHT_INIT_FILE = ""
) (
    input wire clk,
    input wire rst_n,
    input wire bus_valid,
    input wire [15:0] bus_addr,
    input wire [31:0] bus_wdata,
    input wire [3:0] bus_wstrb,
    output wire bus_ready,
    output wire [31:0] bus_rdata
);

    wire core_valid,core_ready,core_active;
    wire [15:0] core_addr;
    wire [31:0] core_wdata,core_rdata,core_gemm,core_compute,core_post;
    wire [3:0] core_wstrb;
    m30_network_replay scheduler (
        .clk(clk),.rst_n(rst_n),.host_valid(bus_valid),.host_addr(bus_addr),
        .host_wdata(bus_wdata),.host_wstrb(bus_wstrb),.host_ready(bus_ready),
        .host_rdata(bus_rdata),.core_valid(core_valid),.core_addr(core_addr),
        .core_wdata(core_wdata),.core_wstrb(core_wstrb),.core_ready(core_ready),
        .core_rdata(core_rdata),.core_active(core_active),.core_gemm(core_gemm),
        .core_compute(core_compute),.core_post(core_post)
    );
    int8_accelerator_mmio_core_m30 #(
        .MAX_M(MAX_M),
        .MAX_N(MAX_N),
        .MAX_K(MAX_K),
        .ALLOW_LOADER_OVERLAP(ALLOW_LOADER_OVERLAP),
        .PIPELINED_POSTPROCESS(PIPELINED_POSTPROCESS),
        .DIRECT_WEIGHT_FEED(DIRECT_WEIGHT_FEED),
        .CHAINED_POSTPROCESS(CHAINED_POSTPROCESS),
        .INCREMENTAL_WEIGHT_ADDRESS(INCREMENTAL_WEIGHT_ADDRESS),
        .AUTONOMOUS_LAYER(AUTONOMOUS_LAYER),
        .LAYER_POST_OVERLAP(LAYER_POST_OVERLAP),
        .LAYER_INPUT_OVERLAP(LAYER_INPUT_OVERLAP),
        .PACKED_READ_PIPELINE(PACKED_READ_PIPELINE),
        .OVERLAP_GEMM_WRITEBACK(OVERLAP_GEMM_WRITEBACK),
        .ZERO_LANE_ADVANCE_OPT(ZERO_LANE_ADVANCE_OPT),
        .SHARED_WEIGHT_PORTS(SHARED_WEIGHT_PORTS),
        .ENABLE_STREAM_GAP(ENABLE_STREAM_GAP),
        .DIRECT_WEIGHT_ONLY(DIRECT_WEIGHT_ONLY),
        .FUSED_LAYER_LAUNCH(FUSED_LAYER_LAUNCH),
        .TILE_ROWS(TILE_ROWS),
        .TILE_COLS(TILE_COLS),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .POST_MAX_POSITIONS(POST_MAX_POSITIONS),
        .POST_MAX_CHANNELS(POST_MAX_CHANNELS),
        .WEIGHT_BYTES(WEIGHT_BYTES),
        .PACKED_WINDOW_LOADER(PACKED_WINDOW_LOADER),
        .WEIGHT_INIT_FILE(WEIGHT_INIT_FILE)
    ) core (
        .clk(clk),.rst_n(rst_n),.bus_valid(core_valid),.bus_addr(core_addr),
        .bus_wdata(core_wdata),.bus_wstrb(core_wstrb),.bus_ready(core_ready),
        .bus_rdata(core_rdata),.m30_active(core_active),.m30_gemm(core_gemm),
        .m30_compute(core_compute),.m30_post(core_post)
    );
endmodule
