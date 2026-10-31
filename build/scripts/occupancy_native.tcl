set root [file normalize [file join [file dirname [info script]] ../..]]
set out [file join $root build/output/occupancy_native]
file mkdir $out
cd $root
set_param general.maxThreads 2
create_project latencyusb [file join $out project] -part xc7z020clg400-1
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name edgeai_o55_usb_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {10} CONFIG.C_NUM_PROBE_OUT {1} CONFIG.C_PROBE_OUT0_WIDTH {1} CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} CONFIG.C_PROBE_IN0_WIDTH {32} CONFIG.C_PROBE_IN1_WIDTH {32} CONFIG.C_PROBE_IN2_WIDTH {32} CONFIG.C_PROBE_IN3_WIDTH {32} CONFIG.C_PROBE_IN4_WIDTH {32} CONFIG.C_PROBE_IN5_WIDTH {32} CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {32} CONFIG.C_PROBE_IN8_WIDTH {32} CONFIG.C_PROBE_IN9_WIDTH {32}] [get_ips edgeai_o55_usb_vio]
generate_target all [get_ips edgeai_o55_usb_vio]
read_verilog -sv [file join $root src/rtl/common/edgeai_axi_lite_bridge_55b705aad1.sv]
read_verilog -sv [file join $root src/rtl/common/edgeai_host_mailbox_f4e1ea7b21.sv]
read_verilog -sv [file join $root src/rtl/common/int8_accelerator_mmio_m33_8f15b2467b.sv]
read_verilog -sv [file join $root src/rtl/common/int8_gemm_controller_m32_8577552883.sv]
read_verilog -sv [file join $root src/rtl/common/int8_input_window_loader_gather_81e9d471b7.sv]
read_verilog -sv [file join $root src/rtl/common/int8_input_window_loader_m33_e1834de3c9.sv]
read_verilog -sv [file join $root src/rtl/common/int8_layer_postprocess_controller_3c490b37c0.sv]
read_verilog -sv [file join $root src/rtl/common/int8_max_pool2_7af1883049.sv]
read_verilog -sv [file join $root src/rtl/common/int8_outer_product_4x4_cee69d734f.sv]
read_verilog -sv [file join $root src/rtl/common/int8_requantize_relu_005e3f0635.sv]
read_verilog -sv [file join $root src/rtl/common/int8_stream_gap_54922f62b9.sv]
read_verilog -sv [file join $root src/rtl/common/int8_weight_tile_loader_581be3476b.sv]
read_verilog -sv [file join $root src/rtl/common/m30_network_replay_f81f05902d.sv]
read_verilog -sv [file join $root src/rtl/common/occupancy_mailbox_77e3f5e48b.sv]
read_verilog -sv [file join $root src/rtl/common/occupancy_service_soc_cf51d80092.sv]
read_verilog [file join $root src/rtl/common/picorv32_fd142889e8.v]
read_verilog -sv [file join $root src/rtl/common/picorv32_accel_soc_host_bcc3fad12d.sv]
read_verilog -sv [file join $root src/rtl/common/pynq_o55_jtag_stimulus_74829c4ed3.sv]
read_verilog -sv [file join $root src/rtl/common/pynq_o55_jtag_top_a35337d1af.sv]
read_verilog -sv [file join $root src/rtl/common/simple_dual_port_bram_32_e016a6dd21.sv]
read_verilog -sv [file join $root src/rtl/common/simple_dual_port_bram_8_1390076600.sv]
set_property top pynq_o55_jtag_top [current_fileset]
read_xdc [file join $root board/constraints/occupancy_native.xdc]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
open_run synth_1
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -delay_type min_max -file [file join $out timing.rpt]
report_utilization -file [file join $out utilization.rpt]
report_route_status -file [file join $out route.rpt]
report_drc -file [file join $out drc.rpt]
write_debug_probes -force [file join $out debug.ltx]
if {[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]<0 || [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]<0} {error "Timing failed"}
write_bitstream -force [file join $out board.bit]
exit
