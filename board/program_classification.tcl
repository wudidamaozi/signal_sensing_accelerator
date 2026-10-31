# One local xc7z020, volatile PL only; 64 input words supplied by caller.
set build [file normalize [lindex $argv 0]]
set input [file normalize [lindex $argv 1]]
set program [lindex $argv 2]
set fh [open $input r];set words [split [string trim [read $fh]] "\n"];close $fh
if {[llength $words]!=64} {error "Expected exactly 64 I/Q words"}
open_hw_manager
connect_hw_server -url 127.0.0.1:3121
set targets [get_hw_targets -quiet *];if {[llength $targets]!=1} {error "Expected one local JTAG target"}
current_hw_target [lindex $targets 0];open_hw_target
set devices [get_hw_devices -quiet xc7z020*];if {[llength $devices]!=1} {error "Expected one xc7z020"}
set d [lindex $devices 0];current_hw_device $d
if {$program eq "program"} {
 set_property PROGRAM.FILE $build/board.bit $d;set_property PROBES.FILE $build/debug.ltx $d;set_property FULL_PROBES.FILE $build/debug.ltx $d;program_hw_devices $d
} else {set_property PROBES.FILE $build/debug.ltx $d;set_property FULL_PROBES.FILE $build/debug.ltx $d}
refresh_hw_device $d
set v [get_hw_vios -of_objects $d];if {[llength $v]!=1} {error "Expected dynamic VIO"}
set ps [get_hw_probes -of_objects $v]
proc probe {ps n} {set a [list];foreach p $ps {set x [get_property NAME $p];if {$x eq $n || [string match */$n $x]} {lappend a $p}};if {[llength $a]!=1} {error "Missing or ambiguous probe $n"};return [lindex $a 0]}
proc number {ps n} {set p [probe $ps $n];set_property INPUT_VALUE_RADIX HEX $p;set val [get_property INPUT_VALUE $p];if {[scan $val %x v]!=1} {error "Unreadable $n=$val"};return [expr {$v & 0xffffffff}]}
set reset [probe $ps reset_request];set req [probe $ps command_toggle];set wr [probe $ps command_write];set addr [probe $ps command_addr];set data [probe $ps command_data]
foreach p [list $reset $req $wr $addr $data] {set_property OUTPUT_VALUE_RADIX UNSIGNED $p}
set_property OUTPUT_VALUE 1 $reset;set_property OUTPUT_VALUE 0 $req;commit_hw_vio [list $reset $req];after 100;set_property OUTPUT_VALUE 0 $reset;commit_hw_vio $reset;after 100;refresh_hw_vio $v
if {[number $ps locked]!=1} {error "MMCM not locked"}
set toggle 0
proc txn {write address value} {
 global ps v toggle req wr addr data
 set_property OUTPUT_VALUE $write $wr;set_property OUTPUT_VALUE $address $addr;set_property OUTPUT_VALUE $value $data
 set toggle [expr {1-$toggle}];set_property OUTPUT_VALUE $toggle $req;commit_hw_vio [list $wr $addr $data $req]
 set matched 0
 for {set k 0} {$k<100} {incr k} {refresh_hw_vio $v;if {[number $ps ack]==$toggle} {set matched 1;break}}
 if {!$matched} {error "AXI response timeout"};if {[number $ps error]!=0} {error "AXI transaction error address=$address"}
 return [number $ps response]
}
set ready 0
for {set k 0} {$k<1000} {incr k} {set ready [txn 0 8 0];if {$ready==1} {break}}
if {$ready!=1} {error "O55 service not ready"}
for {set i 0} {$i<64} {incr i} {set w [string trim [lindex $words $i]];if {![regexp {^[0-9a-fA-F]{8}$} $w]} {error "Invalid input word $i"};scan $w %x n;txn 1 [expr {256+4*$i}] [expr {$n & 0xffffffff}]}
txn 1 20 2526412801;txn 1 16 1
set status 0
for {set k 0} {$k<1000} {incr k} {set status [txn 0 8 0];if {$status & 16} {error "O55 job error"};if {$status & 8} {break}}
if {!($status & 8)} {error "O55 inference timeout"}
set id [txn 0 24 0];if {$id!=2526412801} {error "Result ID mismatch"}
set l0 [txn 0 64 0];set l1 [txn 0 68 0];set l2 [txn 0 72 0];set l3 [txn 0 76 0];set cycles [txn 0 80 0];txn 1 16 2
refresh_hw_vio $v;if {[number $ps trap]!=0} {error "FPGA CPU fault"}
puts "LIVE_CLASS_BOARD_PASS id=$id logits0=$l0 logits1=$l1 logits2=$l2 logits3=$l3 cycles=$cycles"
close_hw_target;disconnect_hw_server;close_hw_manager;exit
