// Occupancy V2 AXI-Lite service. Single clock; PS/interconnect are external.
module occupancy_service_soc #(
    parameter MEM_INIT_FILE = "data/memory/occupancy_native/program.hex",
    parameter [255:0] MODEL_SHA = 256'd0,
    parameter [255:0] FIRMWARE_SHA = 256'd0,
    parameter integer JOB_TIMEOUT_CYCLES = 5000000
)(
    input wire clk, input wire rst_n,
    output wire trap, output reg address_fault = 0,
    output reg host_valid = 0, output reg [31:0] host_data = 0,
    input wire [11:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire [11:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output wire [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input wire s_axi_rready,
    output wire irq

);
    wire valid, instr, ready, acc_ready;
    wire [31:0] addr, wdata, rdata, acc_data;
    wire [3:0] strb;
    reg ram_ready = 0, ram_hit = 0;
    reg [31:0] ram_data = 0;
    (* ram_style = "block" *) reg [31:0] mem [0:2047];
    wire h_valid,h_write,h_ready,h_error,m_error,m_ready,working;
    wire [11:0] h_addr;
    wire [31:0] h_wdata,h_rdata,m_data;
    wire [3:0] h_wstrb;
    wire m_sel=addr[31:12]==20'h30000;
    reg [2:0] reset_count=0;
    reg [31:0] watchdog=0,epoch=0,reset_reason=0;
    wire core_rst_n=rst_n && reset_count==0;
    wire reset_command=h_write && h_addr==12'h010 && h_wdata==4 && h_wstrb==4'hf;
    wire metadata=!h_write && (h_addr==12'h034 || h_addr==12'h038);
    wire special=reset_command || metadata;
    wire timeout_event=working && watchdog>=JOB_TIMEOUT_CYCLES-1;
    always @(posedge clk) begin
        if(!rst_n)begin reset_count<=0;watchdog<=0;epoch<=0;reset_reason<=0;end
        else if((h_valid && reset_command) || (timeout_event && core_rst_n))begin
            reset_count<=4;watchdog<=0;epoch<=epoch+1;
            reset_reason<=h_valid && reset_command ? 1 : 2;
        end else if(reset_count!=0)begin reset_count<=reset_count-1;watchdog<=0;end
        else if(working)watchdog<=watchdog+1;
        else watchdog<=0;
    end
    wire mailbox_h_error;
    wire [31:0] mailbox_h_data;
    assign h_ready=h_valid;
    assign h_error=special ? 0 : (!core_rst_n || mailbox_h_error);
    assign h_rdata=metadata ? (h_addr==12'h034 ? epoch : reset_reason) : mailbox_h_data;
    edgeai_axi_lite_bridge bridge(
        .clk(clk),.rst_n(rst_n),.s_awaddr(s_axi_awaddr),.s_awvalid(s_axi_awvalid),.s_awready(s_axi_awready),
        .s_wdata(s_axi_wdata),.s_wstrb(s_axi_wstrb),.s_wvalid(s_axi_wvalid),.s_wready(s_axi_wready),
        .s_bresp(s_axi_bresp),.s_bvalid(s_axi_bvalid),.s_bready(s_axi_bready),
        .s_araddr(s_axi_araddr),.s_arvalid(s_axi_arvalid),.s_arready(s_axi_arready),
        .s_rdata(s_axi_rdata),.s_rresp(s_axi_rresp),.s_rvalid(s_axi_rvalid),.s_rready(s_axi_rready),
        .h_valid(h_valid),.h_write(h_write),.h_addr(h_addr),.h_wdata(h_wdata),.h_wstrb(h_wstrb),
        .h_ready(h_ready),.h_rdata(h_rdata),.h_error(h_error));
    occupancy_mailbox #(.MODEL_SHA(MODEL_SHA),.FIRMWARE_SHA(FIRMWARE_SHA)) mailbox(
        .clk(clk),.rst_n(core_rst_n),.h_valid(h_valid && !special && core_rst_n),.h_write(h_write),
        .h_addr(h_addr),.h_wdata(h_wdata),.h_wstrb(h_wstrb),.h_ready(),.h_rdata(mailbox_h_data),.h_error(mailbox_h_error),
        .c_valid(valid && m_sel),.c_addr(addr[11:0]),.c_wdata(wdata),.c_wstrb(strb),
        .c_ready(m_ready),.c_rdata(m_data),.c_error(m_error),.working(working),.irq(irq));
    wire acc_sel = addr[31:16] == 16'h1000;
    wire accept = core_rst_n && valid && !ready && !acc_sel && !m_sel;
    wire ram_access = accept && addr < 8192;
    assign ready = acc_sel ? acc_ready : (m_sel ? m_ready : ram_ready);
    assign rdata = acc_sel ? acc_data : (m_sel ? m_data : (ram_hit ? ram_data : 32'b0));
    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1) mem[i] = 0;
        $readmemh(MEM_INIT_FILE, mem);
    end
    // No runtime reset on the RAM read port: infer synchronous byte-write BRAM.
    always @(posedge clk) begin
        if (ram_access) begin
            ram_data <= mem[addr[12:2]];
            if (strb[0]) mem[addr[12:2]][7:0] <= wdata[7:0];
            if (strb[1]) mem[addr[12:2]][15:8] <= wdata[15:8];
            if (strb[2]) mem[addr[12:2]][23:16] <= wdata[23:16];
            if (strb[3]) mem[addr[12:2]][31:24] <= wdata[31:24];
        end
    end
    always @(posedge clk) begin
        ram_ready <= 0;
        host_valid <= 0;
        if (!core_rst_n) begin
            address_fault <= 0;
            ram_hit <= 0;
            host_data <= 0;
        end else if (m_sel && valid && m_error) address_fault<=1;
        else if (accept) begin
            ram_ready <= 1;
            ram_hit <= addr < 8192;
            if (addr == 32'h20000000 && |strb) begin
                host_valid <= 1;
                host_data <= wdata;
            end else if (addr >= 8192) address_fault <= 1;
        end
    end
    picorv32 #(.ENABLE_COUNTERS(1), .ENABLE_COUNTERS64(0),
        .ENABLE_MUL(1), .ENABLE_FAST_MUL(1), .ENABLE_DIV(0),
        .ENABLE_IRQ(0), .STACKADDR(8192)) cpu (
        .clk(clk), .resetn(core_rst_n), .trap(trap), .mem_valid(valid),
        .mem_instr(instr), .mem_ready(ready), .mem_addr(addr),
        .mem_wdata(wdata), .mem_wstrb(strb), .mem_rdata(rdata),
        .irq(32'b0), .pcpi_wr(1'b0), .pcpi_rd(32'b0),
        .pcpi_wait(1'b0), .pcpi_ready(1'b0));
    int8_accelerator_mmio_core_m30 #(.PACKED_READ_PIPELINE(1), .ZERO_LANE_ADVANCE_OPT(1), .INCREMENTAL_WEIGHT_ADDRESS(1), .OVERLAP_GEMM_WRITEBACK(1), .MAX_M(16), .MAX_N(64), .AUTONOMOUS_LAYER(1), .LAYER_INPUT_OVERLAP(1), .FUSED_LAYER_LAUNCH(0), .MAX_K(272), .TILE_ROWS(4),
        .TILE_COLS(8), .PACKED_WINDOW_LOADER(1), .PIPELINED_POSTPROCESS(1), .DIRECT_WEIGHT_FEED(1), .CHAINED_POSTPROCESS(1), .WEIGHT_BYTES(38880), .WEIGHT_INIT_FILE("data/memory/occupancy_native/weight_init.hex")) accel (
        .clk(clk), .rst_n(core_rst_n), .bus_valid(valid && acc_sel),
        .bus_addr(addr[15:0]), .bus_wdata(wdata), .bus_wstrb(strb),
        .bus_ready(acc_ready), .bus_rdata(acc_data));
endmodule
