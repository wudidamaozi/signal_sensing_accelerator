// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2020.2 (64-bit)
// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// ==============================================================
`timescale 1 ns / 1 ps
(* rom_style = "block" *) module occupancy_hls4ml_dense_resource_rf_gt_nin_rem0_ap_int_8_ap_int_32_config2_mult_s_w2_V_rom (
addr0, ce0, q0, clk);

parameter DWIDTH = 119;
parameter AWIDTH = 6;
parameter MEM_SIZE = 48;

input[AWIDTH-1:0] addr0;
input ce0;
output reg[DWIDTH-1:0] q0;
input clk;

(* ram_style = "block" *)reg [DWIDTH-1:0] ram[0:MEM_SIZE-1];

initial begin
    $readmemh("data/memory/occupancy_hls4ml/occupancy_hls4ml_dense_resource_rf_gt_nin_rem0_ap_int_8_ap_int_32_config2_mult_s_w2_v_rom.dat", ram);
end



always @(posedge clk)  
begin 
    if (ce0) 
    begin
        q0 <= ram[addr0];
    end
end



endmodule

`timescale 1 ns / 1 ps
module occupancy_hls4ml_dense_resource_rf_gt_nin_rem0_ap_int_8_ap_int_32_config2_mult_s_w2_V(
    reset,
    clk,
    address0,
    ce0,
    q0);

parameter DataWidth = 32'd119;
parameter AddressRange = 32'd48;
parameter AddressWidth = 32'd6;
input reset;
input clk;
input[AddressWidth - 1:0] address0;
input ce0;
output[DataWidth - 1:0] q0;



occupancy_hls4ml_dense_resource_rf_gt_nin_rem0_ap_int_8_ap_int_32_config2_mult_s_w2_V_rom occupancy_hls4ml_dense_resource_rf_gt_nin_rem0_ap_int_8_ap_int_32_config2_mult_s_w2_V_rom_U(
    .clk( clk ),
    .addr0( address0 ),
    .ce0( ce0 ),
    .q0( q0 ));

endmodule

