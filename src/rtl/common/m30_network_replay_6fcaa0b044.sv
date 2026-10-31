`timescale 1ns/1ps
// Resident MMIO command descriptors. No arithmetic, model or input is cached.
// 0100 control(start=1, clear=2), 0104 status(busy/done/error), 0108 count,
// 010c pc, 0110 cycles, 0114 acknowledged commands, 0118/1c/20 counters.
// 0800..0bff: 128 {address/control, data} pairs; control bit16 = status wait.
// Wait reads require bit1(done) and reject bit2(error); data must be 2.
module m30_network_replay (
    input wire clk, rst_n,
    input wire host_valid,
    input wire [15:0] host_addr,
    input wire [31:0] host_wdata,
    input wire [3:0] host_wstrb,
    output wire host_ready,
    output wire [31:0] host_rdata,
    output wire core_valid,
    output wire [15:0] core_addr,
    output wire [31:0] core_wdata,
    output wire [3:0] core_wstrb,
    input wire core_ready,
    input wire [31:0] core_rdata,
    input wire core_active,
    input wire [31:0] core_gemm, core_compute, core_post
);
    localparam FETCH=0, ISSUE=1, RELEASE=2;
    (* ram_style="distributed" *) reg [31:0] commands [0:255];
    reg [255:0] valid_words;
    reg [7:0] count, pc;
    reg [1:0] state;
    reg busy, done, error;
    reg local_ready;
    reg [31:0] local_data;
    reg [31:0] cycles, acknowledged, gemm, compute, post;
    reg [17:0] watchdog;
    wire program_window=host_addr>=16'h0800 && host_addr<16'h0c00;
    wire registers=host_addr>=16'h0100 && host_addr<=16'h0120;
    wire special=program_window || registers;
    wire [7:0] host_index=host_addr[9:2];
    wire [31:0] command=commands[{pc[6:0],1'b0}];
    wire [31:0] argument=commands[{pc[6:0],1'b1}];
    wire is_wait=command[16];
    wire valid_wait_addr=command[15:0]==16'h0004 || command[15:0]==16'h0028
        || command[15:0]==16'h0054 || command[15:0]==16'h0074
        || command[15:0]==16'h0084 || command[15:0]==16'h00a0
        || command[15:0]==16'h00a8;
    reg valid_write_addr;
    always @* begin
        case(command[15:0])
            16'h0000,16'h0008,16'h000c,16'h0010,16'h0020,16'h0024,
            16'h002c,16'h0030,16'h0034,16'h0038,16'h003c,16'h0040,
            16'h0050,16'h0058,16'h005c,16'h0060,16'h0064,16'h0068,
            16'h006c,16'h0070,16'h0078,16'h007c,16'h0080,16'h0088,
            16'h008c,16'h0090,16'h0094,16'h0098,16'h009c,16'h00a4,
            16'h00ac,16'h00b0,16'h00c4: valid_write_addr=1;
            default: valid_write_addr=0;
        endcase
    end
    assign core_valid=busy ? state==ISSUE : host_valid && !special && !local_ready;
    assign core_addr=busy ? command[15:0] : host_addr;
    assign core_wdata=busy ? argument : host_wdata;
    assign core_wstrb=busy ? (is_wait ? 4'b0 : 4'b1111) : host_wstrb;
    assign host_ready=local_ready || (!busy && !special && core_ready);
    assign host_rdata=local_ready ? local_data : core_rdata;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_words<=0; count<=0; pc<=0; state<=FETCH;
            busy<=0; done<=0; error<=0; local_ready<=0; local_data<=0;
            cycles<=0; acknowledged<=0; watchdog<=0;
            gemm<=0; compute<=0; post<=0;
        end else begin
            local_ready<=0;
            if (busy) begin
                cycles<=cycles+1;
                // Bound the entire descriptor, including unsuccessful status polls.
                watchdog<=watchdog+1;
                case(state)
                    FETCH: begin
                        if (pc==count) begin busy<=0; done<=1; end
                        else if (!valid_words[{pc[6:0],1'b0}]
                            || !valid_words[{pc[6:0],1'b1}] || command[31:17]!=0
                            || (is_wait && (!valid_wait_addr || argument!=2))
                            || (!is_wait && !valid_write_addr)) begin
                            busy<=0; done<=1; error<=1;
                        end else state<=ISSUE;
                    end
                    ISSUE: begin
                        if (core_ready) begin
                            state<=RELEASE;
                            if (is_wait && core_rdata[2]) begin
                                // Drain the completed bus transaction before releasing ownership.
                                error<=1; pc<=count; watchdog<=0;
                            end else if (!is_wait || core_rdata[1]) begin
                                pc<=pc+1; acknowledged<=acknowledged+1; watchdog<=0;
                                if (is_wait && (command[15:0]==16'h00a8
                                    || command[15:0]==16'h0004)) begin
                                    gemm<=gemm+core_gemm;
                                    compute<=compute+core_compute;
                                    if (command[15:0]==16'h00a8) post<=post+core_post;
                                end
                            end
                        end
                    end
                    RELEASE: state<=FETCH;
                    default: begin busy<=0; done<=1; error<=1; end
                endcase
                if (&watchdog && pc!=count) begin
                    pc<=count; state<=RELEASE; error<=1; watchdog<=0;
                end
            end
            if (host_valid && !local_ready && (special || busy)) begin
                local_ready<=1; local_data<=0;
                if (host_wstrb!=0) begin
                    if (busy || core_active || host_wstrb!=4'hf || host_addr[1:0]!=0)
                        error<=1;
                    else if (program_window) begin
                        commands[host_index]<=host_wdata; valid_words[host_index]<=1;
                    end else if (host_addr==16'h0108) begin
                        if (host_wdata>128) error<=1;
                        else count<=host_wdata[7:0];
                    end else if (host_addr==16'h0100) begin
                        if (host_wdata[1]) begin done<=0; error<=0; end
                        if (host_wdata[0]) begin
                            if (count==0) begin done<=1; error<=1; end
                            else begin
                                busy<=1; done<=0; error<=0; pc<=0; state<=FETCH;
                                cycles<=0; acknowledged<=0; gemm<=0; compute<=0; post<=0; watchdog<=0;
                            end
                        end
                    end else error<=1;
                end else if (program_window) begin
                    if (busy) error<=1;
                    else local_data<=commands[host_index];
                end else case(host_addr)
                    16'h0100: local_data<=32'h80000000;
                    16'h0104: local_data<={29'd0,error,done,busy};
                    16'h0108: local_data<={24'd0,count};
                    16'h010c: local_data<={24'd0,pc};
                    16'h0110: local_data<=cycles;
                    16'h0114: local_data<=acknowledged;
                    16'h0118: local_data<=gemm;
                    16'h011c: local_data<=compute;
                    16'h0120: local_data<=post;
                    default: error<=1;
                endcase
            end
        end
    end
endmodule
