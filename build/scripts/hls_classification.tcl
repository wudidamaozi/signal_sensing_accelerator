set root [file normalize [file join [file dirname [info script]] ../..]]
cd [file join $root src/hls/classification]
open_project [file join $root build/output/hls_classification]
set_top public_cnn
add_files firmware/public_cnn.cpp -cflags "-std=c++11 -Ifirmware"
add_files -tb network_tb.cpp -cflags "-std=c++11 -I. -Ifirmware"
add_files -tb firmware/weights
open_solution solution1 -flow_target vivado
set_part {xc7z020clg400-1}
create_clock -period 20
csim_design -clean
csynth_design
exit
