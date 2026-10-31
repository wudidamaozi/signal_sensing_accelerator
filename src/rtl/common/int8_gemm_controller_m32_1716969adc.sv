`timescale 1ns/1ps

module int8_gemm_controller #(
    parameter integer OVERLAP_WRITEBACK = 0,
    parameter integer FUSED_TILE_HANDOFF = 0,
    parameter integer DATA_W       = 8,
    parameter integer ACC_W        = 32,
    parameter integer TILE_ROWS    = 4,
    parameter integer TILE_COLS    = 4,
    parameter integer MAX_M        = 16,
    parameter integer MAX_N        = 16,
    parameter integer MAX_K        = 64,
    parameter integer M_W          = $clog2(MAX_M + 1),
    parameter integer N_W          = $clog2(MAX_N + 1),
    parameter integer K_W          = $clog2(MAX_K + 1),
    parameter integer A_ADDR_W     = $clog2(((MAX_M + 3) / 4) * MAX_K),
    parameter integer B_ADDR_W     = $clog2(((MAX_N + 3) / 4) * MAX_K),
    parameter integer C_ADDR_W     = $clog2(MAX_M * MAX_N)
) (
    input  wire                                  clk,
    input  wire                                  rst_n,

    input  wire                                  start,
    input  wire [M_W-1:0]                        cfg_m,
    input  wire [N_W-1:0]                        cfg_n,
    input  wire [K_W-1:0]                        cfg_k,
    input  wire                                  cfg_accumulate,
    output wire                                   busy,
    output wire                                   done,
    output wire                                   error,

    output wire                                   a_rd_en,
    output wire  [A_ADDR_W-1:0]                   a_rd_addr,
    input  wire [TILE_ROWS*DATA_W-1:0]           a_rd_data,
    output wire                                   b_rd_en,
    output wire  [B_ADDR_W-1:0]                   b_rd_addr,
    output wire  [N_W-1:0]                        b_rd_column_tile,
    output wire  [K_W-1:0]                        b_rd_k,
    input  wire [TILE_COLS*DATA_W-1:0]           b_rd_data,

    output wire                                   c_wr_en,
    output wire  [C_ADDR_W-1:0]                   c_wr_addr,
    output wire  [ACC_W-1:0]                      c_wr_data,
    output wire                                   c_rd_en,
    output wire  [C_ADDR_W-1:0]                   c_rd_addr,
    input  wire [ACC_W-1:0]                      c_rd_data,

    output wire  [31:0]                           total_cycles,
    output wire  [31:0]                           compute_cycles
);

    generate if (OVERLAP_WRITEBACK) begin: overlap_path
    int8_gemm_writeback_overlap #(
        .FUSED_TILE_HANDOFF(FUSED_TILE_HANDOFF),        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .TILE_ROWS(TILE_ROWS),
        .TILE_COLS(TILE_COLS),
        .MAX_M(MAX_M),
        .MAX_N(MAX_N),
        .MAX_K(MAX_K),
        .M_W(M_W),
        .N_W(N_W),
        .K_W(K_W),
        .A_ADDR_W(A_ADDR_W),
        .B_ADDR_W(B_ADDR_W),
        .C_ADDR_W(C_ADDR_W)
    ) impl (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .cfg_m(cfg_m),
        .cfg_n(cfg_n),
        .cfg_k(cfg_k),
        .cfg_accumulate(cfg_accumulate),
        .busy(busy),
        .done(done),
        .error(error),
        .a_rd_en(a_rd_en),
        .a_rd_addr(a_rd_addr),
        .a_rd_data(a_rd_data),
        .b_rd_en(b_rd_en),
        .b_rd_addr(b_rd_addr),
        .b_rd_column_tile(b_rd_column_tile),
        .b_rd_k(b_rd_k),
        .b_rd_data(b_rd_data),
        .c_wr_en(c_wr_en),
        .c_wr_addr(c_wr_addr),
        .c_wr_data(c_wr_data),
        .c_rd_en(c_rd_en),
        .c_rd_addr(c_rd_addr),
        .c_rd_data(c_rd_data),
        .total_cycles(total_cycles),
        .compute_cycles(compute_cycles)
    );
    end else begin: serial_path
    int8_gemm_serial_controller #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .TILE_ROWS(TILE_ROWS),
        .TILE_COLS(TILE_COLS),
        .MAX_M(MAX_M),
        .MAX_N(MAX_N),
        .MAX_K(MAX_K),
        .M_W(M_W),
        .N_W(N_W),
        .K_W(K_W),
        .A_ADDR_W(A_ADDR_W),
        .B_ADDR_W(B_ADDR_W),
        .C_ADDR_W(C_ADDR_W)
    ) impl (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .cfg_m(cfg_m),
        .cfg_n(cfg_n),
        .cfg_k(cfg_k),
        .cfg_accumulate(cfg_accumulate),
        .busy(busy),
        .done(done),
        .error(error),
        .a_rd_en(a_rd_en),
        .a_rd_addr(a_rd_addr),
        .a_rd_data(a_rd_data),
        .b_rd_en(b_rd_en),
        .b_rd_addr(b_rd_addr),
        .b_rd_column_tile(b_rd_column_tile),
        .b_rd_k(b_rd_k),
        .b_rd_data(b_rd_data),
        .c_wr_en(c_wr_en),
        .c_wr_addr(c_wr_addr),
        .c_wr_data(c_wr_data),
        .c_rd_en(c_rd_en),
        .c_rd_addr(c_rd_addr),
        .c_rd_data(c_rd_data),
        .total_cycles(total_cycles),
        .compute_cycles(compute_cycles)
    );
    end endgenerate
endmodule

`timescale 1ns/1ps

module int8_gemm_serial_controller #(
    parameter integer DATA_W       = 8,
    parameter integer ACC_W        = 32,
    parameter integer TILE_ROWS    = 4,
    parameter integer TILE_COLS    = 4,
    parameter integer MAX_M        = 16,
    parameter integer MAX_N        = 16,
    parameter integer MAX_K        = 64,
    parameter integer M_W          = $clog2(MAX_M + 1),
    parameter integer N_W          = $clog2(MAX_N + 1),
    parameter integer K_W          = $clog2(MAX_K + 1),
    parameter integer A_ADDR_W     = $clog2(((MAX_M + 3) / 4) * MAX_K),
    parameter integer B_ADDR_W     = $clog2(((MAX_N + 3) / 4) * MAX_K),
    parameter integer C_ADDR_W     = $clog2(MAX_M * MAX_N)
) (
    input  wire                                  clk,
    input  wire                                  rst_n,

    input  wire                                  start,
    input  wire [M_W-1:0]                        cfg_m,
    input  wire [N_W-1:0]                        cfg_n,
    input  wire [K_W-1:0]                        cfg_k,
    input  wire                                  cfg_accumulate,
    output reg                                   busy,
    output reg                                   done,
    output reg                                   error,

    output reg                                   a_rd_en,
    output reg  [A_ADDR_W-1:0]                   a_rd_addr,
    input  wire [TILE_ROWS*DATA_W-1:0]           a_rd_data,
    output reg                                   b_rd_en,
    output reg  [B_ADDR_W-1:0]                   b_rd_addr,
    output reg  [N_W-1:0]                        b_rd_column_tile,
    output reg  [K_W-1:0]                        b_rd_k,
    input  wire [TILE_COLS*DATA_W-1:0]           b_rd_data,

    output reg                                   c_wr_en,
    output reg  [C_ADDR_W-1:0]                   c_wr_addr,
    output reg  [ACC_W-1:0]                      c_wr_data,
    output reg                                   c_rd_en,
    output reg  [C_ADDR_W-1:0]                   c_rd_addr,
    input  wire [ACC_W-1:0]                      c_rd_data,

    output reg  [31:0]                           total_cycles,
    output reg  [31:0]                           compute_cycles
);

    localparam [2:0] STATE_IDLE       = 3'd0;
    localparam [2:0] STATE_CORE_START = 3'd1;
    localparam [2:0] STATE_FEED       = 3'd2;
    localparam [2:0] STATE_CORE_WAIT  = 3'd3;
    localparam [2:0] STATE_WRITEBACK  = 3'd4;
    localparam [2:0] STATE_ACCUMULATE = 3'd5;

    reg [2:0] state;
    reg [M_W-1:0] m_reg;
    reg [N_W-1:0] n_reg;
    reg [K_W-1:0] k_reg;
    reg           accumulate_reg;
    reg [M_W-1:0] tile_row_base;
    reg [N_W-1:0] tile_column_base;
    reg [K_W-1:0] k_index;
    reg [$clog2(TILE_ROWS*TILE_COLS)-1:0] writeback_index;

    reg                              core_start;
    wire                             core_busy;
    wire                             core_done;
    reg                              core_in_valid;
    wire                             core_in_ready;
    reg                              core_in_last;
    wire [TILE_ROWS*TILE_COLS*ACC_W-1:0] core_c_mat;
    wire [31:0]                      core_total_cycles;
    wire [31:0]                      core_active_cycles;

    wire writeback_valid =
        (tile_row_base + (writeback_index / TILE_COLS) < m_reg)
        && (tile_column_base + (writeback_index % TILE_COLS) < n_reg);
    wire [C_ADDR_W-1:0] writeback_address =
        (tile_row_base + (writeback_index / TILE_COLS)) * n_reg
        + tile_column_base + (writeback_index % TILE_COLS);
    wire [ACC_W-1:0] writeback_partial =
        core_c_mat[(writeback_index*ACC_W) +: ACC_W];
    wire signed [ACC_W:0] accumulation_sum =
        $signed({c_rd_data[ACC_W-1], c_rd_data})
        + $signed({writeback_partial[ACC_W-1], writeback_partial});
    wire accumulation_overflow =
        accumulation_sum[ACC_W] != accumulation_sum[ACC_W-1];

    int8_outer_product_4x4 #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .ROWS(TILE_ROWS),
        .COLS(TILE_COLS)
    ) compute_core (
        .clk(clk),
        .rst_n(rst_n),
        .start(core_start),
        .busy(core_busy),
        .done(core_done),
        .in_valid(core_in_valid),
        .in_ready(core_in_ready),
        .in_last(core_in_last),
        .a_vec(a_rd_data),
        .b_vec(b_rd_data),
        .c_mat(core_c_mat),
        .total_cycles(core_total_cycles),
        .active_cycles(core_active_cycles)
    );

    always @* begin
        core_start   = 1'b0;
        core_in_valid = 1'b0;
        core_in_last = 1'b0;
        a_rd_en      = 1'b0;
        a_rd_addr    = {A_ADDR_W{1'b0}};
        b_rd_en      = 1'b0;
        b_rd_addr    = {B_ADDR_W{1'b0}};
        b_rd_column_tile = tile_column_base / 4;
        b_rd_k = {K_W{1'b0}};
        c_wr_en      = 1'b0;
        c_wr_addr    = {C_ADDR_W{1'b0}};
        c_wr_data    = {ACC_W{1'b0}};
        c_rd_en      = 1'b0;
        c_rd_addr    = {C_ADDR_W{1'b0}};

        case (state)
            STATE_CORE_START: begin
                core_start = 1'b1;
                a_rd_en = 1'b1;
                b_rd_en = 1'b1;
                a_rd_addr = ((tile_row_base / 4) * MAX_K);
                b_rd_addr = ((tile_column_base / 4) * MAX_K);
            end

            STATE_FEED: begin
                core_in_valid = 1'b1;
                core_in_last = (k_index == k_reg - 1'b1);
                if (k_index + 1'b1 < k_reg) begin
                    a_rd_en = 1'b1;
                    b_rd_en = 1'b1;
                    a_rd_addr = ((tile_row_base / 4) * MAX_K) + k_index + 1'b1;
                    b_rd_addr = ((tile_column_base / 4) * MAX_K) + k_index + 1'b1;
                    b_rd_k = k_index + 1'b1;
                end
            end

            STATE_WRITEBACK: begin
                if (writeback_valid) begin
                    if (accumulate_reg) begin
                        c_rd_en = 1'b1;
                        c_rd_addr = writeback_address;
                    end else begin
                        c_wr_en = 1'b1;
                        c_wr_addr = writeback_address;
                        c_wr_data = writeback_partial;
                    end
                end
            end

            STATE_ACCUMULATE: begin
                c_wr_en = 1'b1;
                c_wr_addr = writeback_address;
                c_wr_data = accumulation_sum[ACC_W-1:0];
            end

            default: begin
            end
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state            <= STATE_IDLE;
            m_reg            <= {M_W{1'b0}};
            n_reg            <= {N_W{1'b0}};
            k_reg            <= {K_W{1'b0}};
            accumulate_reg   <= 1'b0;
            tile_row_base    <= {M_W{1'b0}};
            tile_column_base <= {N_W{1'b0}};
            k_index          <= {K_W{1'b0}};
            writeback_index  <= 4'd0;
            busy             <= 1'b0;
            done             <= 1'b0;
            error            <= 1'b0;
            total_cycles     <= 32'd0;
            compute_cycles   <= 32'd0;
        end else begin
            done <= 1'b0;

            if (start && busy) begin
                error <= 1'b1;
            end

            if (busy) begin
                total_cycles <= total_cycles + 1'b1;
            end

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        total_cycles   <= 32'd0;
                        compute_cycles <= 32'd0;
                        if ((cfg_m == 0) || (cfg_m > MAX_M)
                            || (cfg_n == 0) || (cfg_n > MAX_N)
                            || (cfg_k == 0) || (cfg_k > MAX_K)) begin
                            error <= 1'b1;
                            done  <= 1'b1;
                        end else begin
                            m_reg            <= cfg_m;
                            n_reg            <= cfg_n;
                            k_reg            <= cfg_k;
                            accumulate_reg   <= cfg_accumulate;
                            tile_row_base    <= {M_W{1'b0}};
                            tile_column_base <= {N_W{1'b0}};
                            k_index          <= {K_W{1'b0}};
                            writeback_index  <= 4'd0;
                            error            <= 1'b0;
                            busy             <= 1'b1;
                            state            <= STATE_CORE_START;
                        end
                    end
                end

                STATE_CORE_START: begin
                    k_index <= {K_W{1'b0}};
                    state   <= STATE_FEED;
                end

                STATE_FEED: begin
                    if (core_in_valid && core_in_ready) begin
                        compute_cycles <= compute_cycles + 1'b1;
                        if (core_in_last) begin
                            state <= STATE_CORE_WAIT;
                        end else begin
                            k_index <= k_index + 1'b1;
                        end
                    end
                end

                STATE_CORE_WAIT: begin
                    if (core_done) begin
                        writeback_index <= 4'd0;
                        state <= STATE_WRITEBACK;
                    end
                end

                STATE_WRITEBACK: begin
                    if (accumulate_reg && writeback_valid) begin
                        state <= STATE_ACCUMULATE;
                    end else if (writeback_index == TILE_ROWS*TILE_COLS-1) begin
                        writeback_index <= 4'd0;
                        if (tile_column_base + TILE_COLS < n_reg) begin
                            tile_column_base <= tile_column_base + TILE_COLS;
                            k_index <= {K_W{1'b0}};
                            state <= STATE_CORE_START;
                        end else if (tile_row_base + TILE_ROWS < m_reg) begin
                            tile_row_base <= tile_row_base + TILE_ROWS;
                            tile_column_base <= {N_W{1'b0}};
                            k_index <= {K_W{1'b0}};
                            state <= STATE_CORE_START;
                        end else begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            state <= STATE_IDLE;
                        end
                    end else begin
                        writeback_index <= writeback_index + 1'b1;
                    end
                end

                STATE_ACCUMULATE: begin
                    if (accumulation_overflow)
                        error <= 1'b1;

                    if (writeback_index == TILE_ROWS*TILE_COLS-1) begin
                        writeback_index <= 4'd0;
                        if (tile_column_base + TILE_COLS < n_reg) begin
                            tile_column_base <= tile_column_base + TILE_COLS;
                            k_index <= {K_W{1'b0}};
                            state <= STATE_CORE_START;
                        end else if (tile_row_base + TILE_ROWS < m_reg) begin
                            tile_row_base <= tile_row_base + TILE_ROWS;
                            tile_column_base <= {N_W{1'b0}};
                            k_index <= {K_W{1'b0}};
                            state <= STATE_CORE_START;
                        end else begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            state <= STATE_IDLE;
                        end
                    end else begin
                        writeback_index <= writeback_index + 1'b1;
                        state <= STATE_WRITEBACK;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    busy  <= 1'b0;
                    error <= 1'b1;
                end
            endcase
        end
    end

endmodule

`timescale 1ns/1ps

module int8_gemm_writeback_overlap #(
    parameter integer FUSED_TILE_HANDOFF = 0,    parameter integer DATA_W       = 8,
    parameter integer ACC_W        = 32,
    parameter integer TILE_ROWS    = 4,
    parameter integer TILE_COLS    = 4,
    parameter integer MAX_M        = 16,
    parameter integer MAX_N        = 16,
    parameter integer MAX_K        = 64,
    parameter integer M_W          = $clog2(MAX_M + 1),
    parameter integer N_W          = $clog2(MAX_N + 1),
    parameter integer K_W          = $clog2(MAX_K + 1),
    parameter integer A_ADDR_W     = $clog2(((MAX_M + 3) / 4) * MAX_K),
    parameter integer B_ADDR_W     = $clog2(((MAX_N + 3) / 4) * MAX_K),
    parameter integer C_ADDR_W     = $clog2(MAX_M * MAX_N)
) (
    input  wire                                  clk,
    input  wire                                  rst_n,

    input  wire                                  start,
    input  wire [M_W-1:0]                        cfg_m,
    input  wire [N_W-1:0]                        cfg_n,
    input  wire [K_W-1:0]                        cfg_k,
    input  wire                                  cfg_accumulate,
    output reg                                   busy,
    output reg                                   done,
    output reg                                   error,

    output reg                                   a_rd_en,
    output reg  [A_ADDR_W-1:0]                   a_rd_addr,
    input  wire [TILE_ROWS*DATA_W-1:0]           a_rd_data,
    output reg                                   b_rd_en,
    output reg  [B_ADDR_W-1:0]                   b_rd_addr,
    output reg  [N_W-1:0]                        b_rd_column_tile,
    output reg  [K_W-1:0]                        b_rd_k,
    input  wire [TILE_COLS*DATA_W-1:0]           b_rd_data,

    output reg                                   c_wr_en,
    output reg  [C_ADDR_W-1:0]                   c_wr_addr,
    output reg  [ACC_W-1:0]                      c_wr_data,
    output reg                                   c_rd_en,
    output reg  [C_ADDR_W-1:0]                   c_rd_addr,
    input  wire [ACC_W-1:0]                      c_rd_data,

    output reg  [31:0]                           total_cycles,
    output reg  [31:0]                           compute_cycles
);


    // One compute array, one 16-word result snapshot. No extra C BRAM bank.
    localparam [2:0] S_IDLE=0,S_START=1,S_FEED=2,S_WAIT=3,S_CAPTURE=4,S_DRAIN=5;
    reg [2:0] state;
    reg [M_W-1:0] m_reg, tile_row_base, snapshot_row;
    reg [N_W-1:0] n_reg, tile_column_base, snapshot_column;
    reg [K_W-1:0] k_reg,k_index;
    reg accumulate_reg;
    reg [TILE_ROWS*TILE_COLS*ACC_W-1:0] snapshot;
    reg snapshot_valid,accumulation_phase;
    reg [$clog2(TILE_ROWS*TILE_COLS)-1:0] writeback_index;
    // c_mat is registered on the final accepted MAC and retained on start.
    // At the next edge, snapshot capture can share next-tile start and BRAM read.
    wire has_next_column = tile_column_base+TILE_COLS<n_reg;
    wire has_next_tile = has_next_column || tile_row_base+TILE_ROWS<m_reg;
    wire [M_W-1:0] next_tile_row = has_next_column ? tile_row_base : tile_row_base+TILE_ROWS;
    wire [N_W-1:0] next_tile_column = has_next_column ? tile_column_base+TILE_COLS : 0;
    wire core_done,core_busy,core_in_ready;
    reg core_start,core_in_valid,core_in_last;
    wire [TILE_ROWS*TILE_COLS*ACC_W-1:0] core_c_mat;
    wire [31:0] core_total_cycles,core_active_cycles;
    wire position_valid=(snapshot_row+(writeback_index / TILE_COLS)<m_reg)
                       &&(snapshot_column+(writeback_index % TILE_COLS)<n_reg);
    wire [C_ADDR_W-1:0] writeback_address=
         (snapshot_row+(writeback_index / TILE_COLS))*n_reg+snapshot_column+(writeback_index % TILE_COLS);
    wire signed [ACC_W-1:0] partial=snapshot[(writeback_index*ACC_W)+:ACC_W];
    wire signed [ACC_W:0] accumulation_sum=
         $signed({c_rd_data[ACC_W-1],c_rd_data})+$signed({partial[ACC_W-1],partial});
    // On the final write edge the old snapshot still drives C, while the
    // sequential capture below installs the next snapshot for the next cycle.
    wire snapshot_releasing = snapshot_valid && writeback_index==TILE_ROWS*TILE_COLS-1
        && (!accumulate_reg || !position_valid || accumulation_phase);
    wire snapshot_slot_available = !snapshot_valid || (FUSED_TILE_HANDOFF && snapshot_releasing);
    int8_outer_product_4x4 #(.DATA_W(DATA_W),.ACC_W(ACC_W),.ROWS(TILE_ROWS),.COLS(TILE_COLS)) compute_core (
        .clk(clk),.rst_n(rst_n),.start(core_start),.busy(core_busy),.done(core_done),
        .in_valid(core_in_valid),.in_ready(core_in_ready),.in_last(core_in_last),
        .a_vec(a_rd_data),.b_vec(b_rd_data),.c_mat(core_c_mat),
        .total_cycles(core_total_cycles),.active_cycles(core_active_cycles));
    always @* begin
        core_start=0;core_in_valid=0;core_in_last=0;
        a_rd_en=0;b_rd_en=0;a_rd_addr=0;b_rd_addr=0;
        b_rd_column_tile=tile_column_base/4;b_rd_k=0;
        c_wr_en=0;c_rd_en=0;c_wr_addr=writeback_address;c_rd_addr=writeback_address;c_wr_data=0;
        if(state==S_START) begin
            core_start=1;a_rd_en=1;b_rd_en=1;
            a_rd_addr=(tile_row_base/4)*MAX_K;
            b_rd_addr=(tile_column_base/4)*MAX_K;
        end
        if(state==S_FEED) begin
            core_in_valid=1;core_in_last=(k_index==k_reg-1'b1);
            if(k_index+1'b1<k_reg) begin
                a_rd_en=1;b_rd_en=1;
                a_rd_addr=(tile_row_base/4)*MAX_K+k_index+1'b1;
                b_rd_addr=(tile_column_base/4)*MAX_K+k_index+1'b1;
                b_rd_k=k_index+1'b1;
            end
        end
        if(FUSED_TILE_HANDOFF && state==S_CAPTURE && snapshot_slot_available && has_next_tile) begin
            core_start=1;a_rd_en=1;b_rd_en=1;
            a_rd_addr=(next_tile_row/4)*MAX_K;
            b_rd_addr=(next_tile_column/4)*MAX_K;
            b_rd_column_tile=next_tile_column/4;b_rd_k=0;
        end
        if(snapshot_valid && position_valid) begin
            if(accumulate_reg && !accumulation_phase) c_rd_en=1;
            else begin
                c_wr_en=1;
                c_wr_data=accumulate_reg ? accumulation_sum[ACC_W-1:0] : partial;
            end
        end
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=S_IDLE;busy<=0;done<=0;error<=0;total_cycles<=0;compute_cycles<=0;
            m_reg<=0;n_reg<=0;k_reg<=0;accumulate_reg<=0;
            tile_row_base<=0;tile_column_base<=0;k_index<=0;
            snapshot_valid<=0;snapshot_row<=0;snapshot_column<=0;
            writeback_index<=0;accumulation_phase<=0;
        end else begin
            done<=0;
            if(start && busy) error<=1;
            if(busy) total_cycles<=total_cycles+1;
            // Completed snapshots drain independently of the next array feed.
            if(snapshot_valid) begin
                if(accumulate_reg && position_valid && !accumulation_phase)
                    accumulation_phase<=1;
                else begin
                    accumulation_phase<=0;
                    if(accumulate_reg && position_valid && accumulation_sum[ACC_W]!=accumulation_sum[ACC_W-1]) error<=1;
                    if(writeback_index==TILE_ROWS*TILE_COLS-1) begin snapshot_valid<=0;writeback_index<=0;end
                    else writeback_index<=writeback_index+1;
                end
            end
            case(state)
                S_IDLE: begin
                    busy<=0;
                    if(start) begin
                        total_cycles<=0;compute_cycles<=0;
                        if(cfg_m==0 || cfg_m>MAX_M || cfg_n==0 || cfg_n>MAX_N || cfg_k==0 || cfg_k>MAX_K) begin error<=1;done<=1;end
                        else begin
                            m_reg<=cfg_m;n_reg<=cfg_n;k_reg<=cfg_k;accumulate_reg<=cfg_accumulate;
                            tile_row_base<=0;tile_column_base<=0;k_index<=0;
                            error<=0;busy<=1;state<=S_START;
                        end
                    end
                end
                S_START: begin k_index<=0;state<=S_FEED;end
                S_FEED: if(core_in_valid && core_in_ready) begin
                    compute_cycles<=compute_cycles+1;
                    if(core_in_last) state<=FUSED_TILE_HANDOFF ? S_CAPTURE : S_WAIT;
                    else k_index<=k_index+1;
                end
                S_WAIT: if(core_done) state<=S_CAPTURE;
                S_CAPTURE: if(snapshot_slot_available) begin
                    snapshot<=core_c_mat;snapshot_valid<=1;writeback_index<=0;accumulation_phase<=0;
                    snapshot_row<=tile_row_base;snapshot_column<=tile_column_base;
                    if(tile_column_base+TILE_COLS<n_reg) begin
                        tile_column_base<=tile_column_base+TILE_COLS;k_index<=0;
                        state<=FUSED_TILE_HANDOFF ? S_FEED : S_START;
                    end else if(tile_row_base+TILE_ROWS<m_reg) begin
                        tile_row_base<=tile_row_base+TILE_ROWS;tile_column_base<=0;k_index<=0;
                        state<=FUSED_TILE_HANDOFF ? S_FEED : S_START;
                    end else state<=S_DRAIN;
                end
                S_DRAIN: if(!snapshot_valid) begin busy<=0;done<=1;state<=S_IDLE;end
                default: begin busy<=0;error<=1;state<=S_IDLE;snapshot_valid<=0;end
            endcase
        end
    end
endmodule
