set root [file normalize [file join [file dirname [info script]] ../..]]
cd [file join $root src/hls/occupancy]
open_project [file join $root build/output/hls_occupancy]
set_top occupancy_hls4ml
add_files firmware/occupancy_hls4ml.cpp -cflags "-std=c++11 -Ifirmware"
add_files -tb test.cpp -cflags "-std=c++11 -I. -Ifirmware"
add_files -tb firmware/weights
open_solution solution1 -flow_target vivado
set_part {xc7z020clg400-1}
create_clock -period 20
catch {config_array_partition -maximum_size 2048} partition_message
puts "PARTITION_CONFIGURATION=$partition_message"
csim_design -clean
csynth_design
exit
