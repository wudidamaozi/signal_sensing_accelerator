`timescale 1ns/1ps
// Single outstanding frame; host owns input until START, firmware owns it until DONE.
module occupancy_mailbox #(
    parameter [255:0] MODEL_SHA = 256'd0,
    parameter [255:0] FIRMWARE_SHA = 256'd0
)(
    input wire clk, input wire rst_n,
    input wire h_valid, input wire h_write, input wire [11:0] h_addr,
    input wire [31:0] h_wdata, input wire [3:0] h_wstrb,
    output wire h_ready, output reg [31:0] h_rdata, output reg h_error,
    input wire c_valid, input wire [11:0] c_addr,
    input wire [31:0] c_wdata, input wire [3:0] c_wstrb,
    output wire c_ready, output reg [31:0] c_rdata, output reg c_error,
    output wire working, output wire irq
);
    reg fw_ready=0, pending=0, busy=0, done=0, job_error=0;
    reg [31:0] staged_id=0, active_id=0, result_id=0, fw_error=0;
    reg [31:0] cnn_cycles=0, protocol_errors=0;
    reg [6:0] complete_words=0;
    reg [3:0] output_valid=0;
    reg cycles_valid=0;
    (* ram_style="distributed" *) reg [31:0] input_words [0:63];
    reg [3:0] valid_bytes [0:63];
    reg [31:0] logits [0:3];
    wire idle = !pending && !busy && !done;
    wire h_input = h_addr>=12'h100 && h_addr<12'h200;
    wire c_input = c_addr>=12'h100 && c_addr<12'h200;
    wire h_sha = h_addr>=12'h060 && h_addr<12'h080;
    wire [5:0] hi = h_addr[7:2];
    wire [5:0] ci = c_addr[7:2];
    integer i,b;
    assign h_ready=h_valid;
    assign c_ready=c_valid;
    assign irq=done;
    assign working=pending||busy;
    reg [31:0] stages [0:4];
    reg [4:0] stage_valid=0;
    wire h_fwsha=h_addr>=12'h0a0 && h_addr<12'h0c0;
    function [31:0] read_common(input [11:0] address);
        begin
            case(address)
                12'h000:read_common=32'h45414931;
                12'h004:read_common=2;
                12'h028:read_common=2; // task: occupancy
                12'h02c:read_common=256; // required input bytes
                12'h030:read_common=2; // output words
                12'h008:read_common={27'd0,job_error,done,busy,pending,fw_ready};
                12'h014:read_common=staged_id;
                12'h018:read_common=active_id;
                12'h01c:read_common=fw_error;
                12'h020:read_common={25'd0,complete_words};
                12'h024:read_common=protocol_errors;
                12'h040:read_common=logits[0];
                12'h044:read_common=logits[1];
                12'h0c0:read_common=stages[0];
                12'h0c4:read_common=stages[1];
                12'h0c8:read_common=stages[2];
                12'h0cc:read_common=stages[3];
                12'h0d0:read_common=stages[4];
                12'h050:read_common=cnn_cycles;
                default:read_common=0;
            endcase
        end
    endfunction
    function valid_read(input [11:0] address);
        begin
            case(address)
                12'h000,12'h004,12'h008,12'h014,12'h018,12'h01c,12'h020,12'h024,
                12'h040,12'h044,12'h050,12'h028,12'h02c,12'h030,
                12'h0c0,12'h0c4,12'h0c8,12'h0cc,12'h0d0:valid_read=1;
                default:valid_read=0;
            endcase
        end
    endfunction
    always @* begin
        h_rdata=read_common(h_addr);h_error=0;
        if(h_fwsha)h_rdata=FIRMWARE_SHA[(h_addr-12'h0a0)*8+:32];
        if(h_sha)h_rdata=MODEL_SHA[(h_addr-12'h060)*8+:32];
        if(h_input)h_rdata=valid_bytes[hi]==4'hf ? input_words[hi] : 0;
        if(h_addr[1:0]!=0)h_error=1;
        else if(h_write && h_wstrb!=0) begin
            if(h_input)h_error=!idle;
            else if(h_addr==12'h014)h_error=!idle;
            else if(h_addr==12'h02c)h_error=!idle || h_wstrb!=4'hf || h_wdata!=256;
            else if(h_addr==12'h010) begin
                h_error=h_wstrb!=4'hf;
                if(h_wdata==1)h_error=h_error || !idle || !fw_ready || complete_words!=64;
                else if(h_wdata==2)h_error=h_error || !done;
                else h_error=1;
            end else h_error=1;
        end else if(!h_write && !h_input && !h_sha && !h_fwsha && !valid_read(h_addr))h_error=1;
        c_rdata=read_common(c_addr);c_error=0;
        if(c_input)c_rdata=(pending||busy) && valid_bytes[ci]==4'hf ? input_words[ci] : 0;
        if(c_addr[1:0]!=0)c_error=1;
        else if(c_wstrb!=0) begin
            c_error=c_wstrb!=4'hf;
            case(c_addr)
                12'h080:c_error=c_error || c_wdata!=1 || !idle;
                12'h084:c_error=c_error || c_wdata!=1 || !pending;
                12'h088:c_error=c_error || !busy || result_id!=active_id ||
                    !((c_wdata==1 && output_valid==4'h3 && cycles_valid && stage_valid==5'h1f) || c_wdata==2);
                12'h08c,12'h090,12'h040,12'h044,12'h050,12'h0c0,12'h0c4,12'h0c8,12'h0cc,12'h0d0:c_error=c_error || !busy;
                default:c_error=1;
            endcase
        end else if(c_input)c_error=!(pending||busy);
        else if(!valid_read(c_addr))c_error=1;
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            fw_ready<=0;pending<=0;busy<=0;done<=0;job_error<=0;
            staged_id<=0;active_id<=0;result_id<=0;fw_error<=0;
            cnn_cycles<=0;protocol_errors<=0;complete_words<=0;output_valid<=0;cycles_valid<=0;stage_valid<=0;
            for(i=0;i<64;i=i+1)valid_bytes[i]<=0;
            for(i=0;i<4;i=i+1)logits[i]<=0;
            for(i=0;i<5;i=i+1)stages[i]<=0;
        end else begin
            if(h_valid && h_error)protocol_errors<=protocol_errors+1;
            if(h_valid && h_write && !h_error && h_wstrb!=0) begin
                if(h_input) begin
                    for(b=0;b<4;b=b+1)if(h_wstrb[b])input_words[hi][b*8+:8]<=h_wdata[b*8+:8];
                    valid_bytes[hi]<=valid_bytes[hi]|h_wstrb;
                    if(valid_bytes[hi]!=4'hf && (valid_bytes[hi]|h_wstrb)==4'hf)complete_words<=complete_words+1;
                end else if(h_addr==12'h014)begin
                    for(b=0;b<4;b=b+1)if(h_wstrb[b])staged_id[b*8+:8]<=h_wdata[b*8+:8];
                end else if(h_addr==12'h010 && h_wdata==1)begin
                    pending<=1;active_id<=staged_id;output_valid<=0;cycles_valid<=0;stage_valid<=0;fw_error<=0;
                end else if(h_addr==12'h010 && h_wdata==2)begin
                    done<=0;job_error<=0;complete_words<=0;output_valid<=0;cycles_valid<=0;stage_valid<=0;
                    for(i=0;i<64;i=i+1)valid_bytes[i]<=0;
                end
            end
            if(c_valid && c_wstrb!=0 && !c_error)begin
                case(c_addr)
                    12'h080:fw_ready<=1;
                    12'h084:begin pending<=0;busy<=1;end
                    12'h088:begin busy<=0;done<=1;job_error<=c_wdata==2;end
                    12'h08c:fw_error<=c_wdata;
                    12'h090:result_id<=c_wdata;
                    12'h050:begin cnn_cycles<=c_wdata;cycles_valid<=1;end
                    12'h0c0,12'h0c4,12'h0c8,12'h0cc,12'h0d0:begin stages[(c_addr-12'h0c0)>>2]<=c_wdata;stage_valid[(c_addr-12'h0c0)>>2]<=1;end
                    12'h040,12'h044:begin logits[(c_addr-12'h040)>>2]<=c_wdata;output_valid[(c_addr-12'h040)>>2]<=1;end
                    default:begin end
                endcase
            end
        end
    end
endmodule
