set root [file normalize [file join [file dirname [info script]] ../..]]
set out [file join $root build/output/classification_native]
file mkdir $out
cd $root
set_param general.maxThreads 2
create_project r14_m37_usb [file join $out project] -part xc7z020clg400-1
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name edgeai_o55_usb_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {10} CONFIG.C_NUM_PROBE_OUT {1} CONFIG.C_PROBE_OUT0_WIDTH {1} CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} CONFIG.C_PROBE_IN0_WIDTH {32} CONFIG.C_PROBE_IN1_WIDTH {32} CONFIG.C_PROBE_IN2_WIDTH {32} CONFIG.C_PROBE_IN3_WIDTH {32} CONFIG.C_PROBE_IN4_WIDTH {32} CONFIG.C_PROBE_IN5_WIDTH {32} CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {32} CONFIG.C_PROBE_IN8_WIDTH {32} CONFIG.C_PROBE_IN9_WIDTH {32}] [get_ips edgeai_o55_usb_vio]
generate_target all [get_ips edgeai_o55_usb_vio]
read_verilog [file join $root src/rtl/common/picorv32_0836050971.v]
read_verilog -sv [file join $root src/rtl/common/int8_accelerator_mmio_m33_3799ce2c50.sv]
read_verilog -sv [file join $root src/rtl/common/int8_gemm_controller_m32_1716969adc.sv]
read_verilog -sv [file join $root src/rtl/common/int8_input_window_loader_m33_1b4d976766.sv]
read_verilog -sv [file join $root src/rtl/common/int8_layer_postprocess_controller_28c6c0fac2.sv]
read_verilog -sv [file join $root src/rtl/common/int8_max_pool2_0a0ae2d4c0.sv]
read_verilog -sv [file join $root src/rtl/common/int8_outer_product_4x4_0622b5f9d8.sv]
read_verilog -sv [file join $root src/rtl/common/int8_requantize_relu_98dfb3d442.sv]
read_verilog -sv [file join $root src/rtl/common/int8_stream_gap_971eea06c3.sv]
read_verilog -sv [file join $root src/rtl/common/int8_weight_tile_loader_4e19926822.sv]
read_verilog -sv [file join $root src/rtl/common/m30_network_replay_6fcaa0b044.sv]
read_verilog -sv [file join $root src/rtl/common/picorv32_accel_soc_ba20cb8e85.sv]
read_verilog -sv [file join $root src/rtl/common/pynq_r14_m37_usb_top_d0eacc5328.sv]
read_verilog -sv [file join $root src/rtl/common/simple_dual_port_bram_32_69316b4be8.sv]
read_verilog -sv [file join $root src/rtl/common/simple_dual_port_bram_8_8822d650fa.sv]
set_property top pynq_r14_m37_usb_top [current_fileset]
read_xdc [file join $root board/constraints/classification_native.xdc]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
open_run synth_1
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing.rpt]
report_utilization -file [file join $out utilization.rpt]
report_route_status -file [file join $out route.rpt]
report_drc -file [file join $out drc.rpt]
write_debug_probes -force [file join $out debug.ltx]
set s [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set h [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "HLS_USB_TIMING setup=$s hold=$h"
if {$s < 0 || $h < 0} {error "timing failed"}
write_bitstream -force [file join $out board.bit]
exit
