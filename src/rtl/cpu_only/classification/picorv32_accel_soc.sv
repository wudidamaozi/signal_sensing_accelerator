`timescale 1ns/1ps

module picorv32_accel_soc #(
    parameter integer MEM_WORDS = 4096,
    parameter integer ACCEL_TILE_ROWS = 4,
    parameter integer ACCEL_TILE_COLS = 4,
    parameter integer PACKED_WINDOW_LOADER = 0,
    parameter integer ACCEL_MAX_K = 64,
    parameter integer ALLOW_LOADER_OVERLAP = 0,
    parameter integer PIPELINED_POSTPROCESS = 0,
    parameter integer DIRECT_WEIGHT_FEED = 0,
    parameter integer CHAINED_POSTPROCESS = 0,
    parameter integer INCREMENTAL_WEIGHT_ADDRESS = 0,
    parameter integer AUTONOMOUS_LAYER = 0,
    parameter integer LAYER_INPUT_OVERLAP = 0,
    parameter integer PACKED_READ_PIPELINE = 0,
    parameter integer OVERLAP_GEMM_WRITEBACK = 0,
    parameter integer ZERO_LANE_ADVANCE_OPT = 0,
    parameter MEM_INIT_FILE = "",
    parameter WEIGHT_INIT_FILE = ""
) (
    input  wire        clk,
    input  wire        rst_n,
    output wire        trap,
    output reg         host_write,
    output reg  [31:0] host_value
);

    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire        cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [3:0]  cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;

    wire accel_selected = cpu_mem_addr[31:16] == 16'h1000;
    wire host_selected = cpu_mem_addr == 32'h20000000;
    wire ram_selected = cpu_mem_addr < MEM_WORDS*4;

    wire accel_ready;
    wire [31:0] accel_rdata;
    reg ram_ready;
    reg [31:0] ram_rdata;
    reg host_ready;

    (* ram_style = "block" *) reg [31:0] local_memory [0:MEM_WORDS-1];
    integer byte_index;

    initial begin
        if (MEM_INIT_FILE != "")
            $readmemh(MEM_INIT_FILE, local_memory);
    end

    assign cpu_mem_ready = accel_selected ? accel_ready
                         : host_selected ? host_ready
                         : ram_ready;
    assign cpu_mem_rdata = accel_selected ? accel_rdata : ram_rdata;

    always @(posedge clk) begin
        if (!rst_n) begin
            ram_ready  <= 1'b0;
            ram_rdata  <= 32'd0;
            host_ready <= 1'b0;
            host_write <= 1'b0;
            host_value <= 32'd0;
        end else begin
            ram_ready  <= 1'b0;
            host_ready <= 1'b0;
            host_write <= 1'b0;

            if (cpu_mem_valid && !cpu_mem_ready && ram_selected) begin
                ram_ready <= 1'b1;
                ram_rdata <= local_memory[cpu_mem_addr[31:2]];
                for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                    if (cpu_mem_wstrb[byte_index])
                        local_memory[cpu_mem_addr[31:2]][byte_index*8 +: 8]
                            <= cpu_mem_wdata[byte_index*8 +: 8];
                end
            end

            if (cpu_mem_valid && !cpu_mem_ready && host_selected) begin
                host_ready <= 1'b1;
                if (cpu_mem_wstrb != 4'b0000) begin
                    host_value <= cpu_mem_wdata;
                    host_write <= 1'b1;
                end
            end
        end
    end

    // CPU-only execution; no dedicated CNN arithmetic instance.
    assign accel_ready=1'b0;
    assign accel_rdata=32'b0;

    wire mem_la_read;
    wire mem_la_write;
    wire [31:0] mem_la_addr;
    wire [31:0] mem_la_wdata;
    wire [3:0] mem_la_wstrb;
    wire pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    wire [31:0] eoi;
    wire trace_valid;
    wire [35:0] trace_data;

    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(1),
        .ENABLE_FAST_MUL(1),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .COMPRESSED_ISA(0),
        .PROGADDR_RESET(32'h00000000),
        .STACKADDR(MEM_WORDS*4)
    ) cpu (
        .clk(clk),
        .resetn(rst_n),
        .trap(trap),
        .mem_valid(cpu_mem_valid),
        .mem_instr(cpu_mem_instr),
        .mem_ready(cpu_mem_ready),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_wstrb(cpu_mem_wstrb),
        .mem_rdata(cpu_mem_rdata),
        .mem_la_read(mem_la_read),
        .mem_la_write(mem_la_write),
        .mem_la_addr(mem_la_addr),
        .mem_la_wdata(mem_la_wdata),
        .mem_la_wstrb(mem_la_wstrb),
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'd0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'd0),
        .eoi(eoi),
        .trace_valid(trace_valid),
        .trace_data(trace_data)
    );

endmodule
