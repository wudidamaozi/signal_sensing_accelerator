# Programs volatile FPGA configuration only; does not write configuration flash.
set build [file normalize [lindex $argv 0]]
if {![file exists $build/board.bit] || ![file exists $build/debug.ltx]} {error "Missing verified bit/LTX"}
open_hw_manager
connect_hw_server -url 127.0.0.1:3121
set targets [get_hw_targets -quiet *]
if {[llength $targets] != 1} {error "Expected exactly one JTAG target, found [llength $targets]"}
current_hw_target [lindex $targets 0]
open_hw_target
set devs [get_hw_devices -quiet xc7z020*]
if {[llength $devs] != 1} {error "Expected exactly one xc7z020 device; programming stopped"}
set d [lindex $devs 0]
puts "USB_BOARD_DEVICE=$d"
current_hw_device $d
set_property PROGRAM.FILE $build/board.bit $d
set_property PROBES.FILE $build/debug.ltx $d
set_property FULL_PROBES.FILE $build/debug.ltx $d
program_hw_devices $d
refresh_hw_device $d
set v [get_hw_vios -of_objects $d]
if {[llength $v] != 1} {error "Expected one VIO; check input clock and probes"}
set probes [get_hw_probes -of_objects $v]
foreach p $probes {puts "USB_BOARD_PROBE=[get_property NAME $p]"; if {[get_property TYPE $p] eq "vio_input"} {set_property INPUT_VALUE_RADIX HEX $p}}
proc get_probe {probes n} {
 set hits [list]
 foreach p $probes {set name [get_property NAME $p];if {$name eq $n || [string match */$n $name]} {lappend hits $p}}
 if {[llength $hits] != 1} {error "Probe $n: expected one, got [llength $hits]"}
 return [lindex $hits 0]
}
proc number {probes name} {
 set p [get_probe $probes $name];set value [get_property INPUT_VALUE $p]
 if {[scan $value %x v] != 1} {error "Unreadable probe $name value=$value"}
 # Tcl scan can return signed 32-bit values for hex >= 0x80000000.
 return [expr {$v & 0xffffffff}]
}
set reset [get_probe $probes reset_request]
for {set run 1} {$run<=2} {incr run} {
 set_property OUTPUT_VALUE 1 $reset;commit_hw_vio $reset
 after 100;refresh_hw_vio $v
 if {[number $probes locked] != 1 || [number $probes frames_done] != 0} {error "MMCM not locked or reset did not clear"}
 set_property OUTPUT_VALUE 0 $reset;commit_hw_vio $reset
 for {set poll 0} {$poll<60} {incr poll} {
  after 500;refresh_hw_vio $v
  if {[number $probes finished]} {break}
 }
 foreach name {locked finished failed failure_code frames_done cycles0 cycles1 heartbeat trap} {
  puts "USB_BOARD_OBSERVED run=$run $name=[number $probes $name]"
 }
 if {[number $probes finished]!=1 || [number $probes failed]!=0 || [number $probes frames_done]!=2 || [number $probes trap]!=0} {error "Board test failed or timed out"}
 foreach {name expected} {cycles0 27075892 cycles1 27082616 failure_code 0} {
  if {[number $probes $name]!=$expected} {error "Mismatch $name actual=[number $probes $name] expected=$expected"}
 }
 puts "CPU_BOARD_PASS run=$run cycles0=[number $probes cycles0] cycles1=[number $probes cycles1] no_flash"
}
close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
