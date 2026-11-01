set root [file normalize [file join [file dirname [info script]] ../..]]
set out [file join $root build/output/classification_cpu]
file mkdir $out
cd $root
set_param general.maxThreads 2
create_project cpu_only [file join $out project_v2] -part xc7z020clg400-1
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name edgeai_o55_usb_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {10} CONFIG.C_NUM_PROBE_OUT {1} CONFIG.C_PROBE_OUT0_WIDTH {1} CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} CONFIG.C_PROBE_IN0_WIDTH {32} CONFIG.C_PROBE_IN1_WIDTH {32} CONFIG.C_PROBE_IN2_WIDTH {32} CONFIG.C_PROBE_IN3_WIDTH {32} CONFIG.C_PROBE_IN4_WIDTH {32} CONFIG.C_PROBE_IN5_WIDTH {32} CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {32} CONFIG.C_PROBE_IN8_WIDTH {32} CONFIG.C_PROBE_IN9_WIDTH {32}] [get_ips edgeai_o55_usb_vio]
generate_target all [get_ips edgeai_o55_usb_vio]
read_verilog -sv [file join $root src/rtl/cpu_only/classification/cpu_only_board_top.sv]
read_verilog [file join $root src/rtl/cpu_only/classification/picorv32.v]
read_verilog -sv [file join $root src/rtl/cpu_only/classification/picorv32_accel_soc.sv]
set_property top cpu_only_board_top [current_fileset]
read_xdc [file join $root board/constraints/classification_cpu.xdc]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
open_run synth_1
set cnn [get_cells -hier -filter {REF_NAME =~ int8_*}]
puts "CPU_ONLY_CNN_CELL_COUNT=[llength $cnn]"
if {[llength $cnn]!=0} {error "CNN accelerator remains"}
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $out timing.rpt]
report_route_status -file [file join $out route.rpt]
report_drc -file [file join $out drc.rpt]
set s [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set h [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
puts "CPU_ONLY_TIMING setup=$s hold=$h"
if {$s<0 || $h<0} {error "timing failed"}
write_debug_probes -force [file join $out debug.ltx]
write_checkpoint -force [file join $out routed.dcp]
write_bitstream -force [file join $out board.bit]
exit
