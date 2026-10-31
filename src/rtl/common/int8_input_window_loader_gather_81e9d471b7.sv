// Four independently addressed byte banks gather an unaligned window in one read.
module int8_input_window_loader_gather #(
    parameter integer MAX_M=64, MAX_K=192, Q_BYTES=8192,
    parameter integer Q_WORD_ADDR_W=$clog2(Q_BYTES/4),
    parameter integer A_ADDR_W=$clog2(((MAX_M+3)/4)*MAX_K)
)(
    input wire clk, rst_n, start,
    input wire [7:0] cfg_tile_m,
    input wire [15:0] cfg_tile_k,
    input wire [15:0] cfg_output_base, cfg_input_length,
    input wire [7:0] cfg_kernel, cfg_padding,
    input wire [15:0] cfg_channel_base,
    input wire [7:0] cfg_start_tap,
    output reg busy, done, error,
    output wire q_rd_en,
    output wire [Q_WORD_ADDR_W-1:0] q_rd_addr,
    output wire [Q_WORD_ADDR_W-1:0] q_rd_addr_0, q_rd_addr_1, q_rd_addr_2, q_rd_addr_3,
    input wire [31:0] q_rd_data,
    output wire a_wr_en,
    output reg [A_ADDR_W-1:0] a_wr_addr,
    output wire [31:0] a_wr_data
);
    reg issuing, pipe_valid;
    reg [$clog2((MAX_M+3)/4)-1:0] row_tile;
    reg [15:0] local_k;
    reg [7:0] tap;
    reg [15:0] channel_base;
    reg [3:0] valid_r;
    reg [1:0] bank_r[0:3];
    wire [15:0] row_position = row_tile * 4;
    wire [7:0] row_count = (cfg_tile_m+8'd3)>>2;
    wire signed [18:0] first_position = $signed({3'b0,cfg_output_base})
        + $signed({3'b0,row_position}) + $signed({11'b0,tap}) - $signed({11'b0,cfg_padding});
    wire signed [18:0] position[0:3], address[0:3];
    wire [3:0] valid, bounds_error;
    wire [Q_WORD_ADDR_W-1:0] bank_address[0:3];
    wire [7:0] result_byte[0:3];
    genvar i;
    generate for(i=0;i<4;i=i+1) begin: lane
        assign position[i]=first_position+i;
        assign address[i]=$signed({3'b0,channel_base})+position[i];
        assign valid[i]=(row_position+i<cfg_tile_m) && position[i]>=0
            && position[i]<$signed({3'b0,cfg_input_length});
        assign bounds_error[i]=valid[i] && (address[i]<0 || address[i]>=Q_BYTES);
        assign bank_address[i]=(valid[0] && address[0][1:0]==i) ? address[0][Q_WORD_ADDR_W+1:2]
            : (valid[1] && address[1][1:0]==i) ? address[1][Q_WORD_ADDR_W+1:2]
            : (valid[2] && address[2][1:0]==i) ? address[2][Q_WORD_ADDR_W+1:2]
            : (valid[3] && address[3][1:0]==i) ? address[3][Q_WORD_ADDR_W+1:2] : {Q_WORD_ADDR_W{1'b0}};
        assign result_byte[i]=valid_r[i] ? (q_rd_data>>(bank_r[i]*8)) : 8'b0;
    end endgenerate
    assign q_rd_en=busy && issuing && !(|bounds_error);
    assign q_rd_addr_0=bank_address[0];
    assign q_rd_addr_1=bank_address[1];
    assign q_rd_addr_2=bank_address[2];
    assign q_rd_addr_3=bank_address[3];
    assign q_rd_addr=bank_address[0];
    assign a_wr_en=busy && pipe_valid;
    assign a_wr_data={result_byte[3],result_byte[2],result_byte[1],result_byte[0]};
    always @(posedge clk) begin
        if(!rst_n) begin
            busy<=0; done<=0; error<=0; issuing<=0; pipe_valid<=0;
            row_tile<=0; local_k<=0; tap<=0; channel_base<=0; valid_r<=0; a_wr_addr<=0;
            for(integer j=0;j<4;j=j+1) bank_r[j]<=0;
        end else begin
            done<=0;
            if(start && !busy) begin
                error<=0; pipe_valid<=0;
                if(cfg_tile_m==0 || cfg_tile_m>MAX_M || cfg_tile_k==0 || cfg_tile_k>MAX_K
                    || cfg_kernel==0 || cfg_start_tap>=cfg_kernel || cfg_input_length==0
                    || cfg_input_length>128 || cfg_padding>=cfg_kernel || cfg_channel_base>=Q_BYTES) begin
                    error<=1; done<=1;
                end else begin
                    busy<=1; issuing<=1; row_tile<=0; local_k<=0;
                    tap<=cfg_start_tap; channel_base<=cfg_channel_base;
                end
            end else if(busy) begin
                pipe_valid<=0;
                if(issuing) begin
                    if(|bounds_error) begin
                        error<=1; done<=1; busy<=0; issuing<=0;
                    end else begin
                        pipe_valid<=1; valid_r<=valid; a_wr_addr<=row_tile*MAX_K+local_k;
                        for(integer j=0;j<4;j=j+1) bank_r[j]<=address[j][1:0];
                        if(local_k+1<cfg_tile_k) begin
                            local_k<=local_k+1;
                            if(tap+1<cfg_kernel) tap<=tap+1;
                            else begin tap<=0; channel_base<=channel_base+cfg_input_length; end
                        end else if(row_tile+1<row_count) begin
                            row_tile<=row_tile+1; local_k<=0;
                            tap<=cfg_start_tap; channel_base<=cfg_channel_base;
                        end else issuing<=0;
                    end
                end else if(pipe_valid) begin busy<=0; done<=1; end
            end
        end
    end
endmodule
