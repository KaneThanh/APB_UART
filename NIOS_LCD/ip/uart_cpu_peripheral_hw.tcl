package require -exact qsys 16.1
set_module_property NAME uart_cpu_peripheral
set_module_property VERSION 1.0
set_module_property GROUP "UART Project"
set_module_property DISPLAY_NAME "APB UART and board LCD"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
add_fileset synthesis_files QUARTUS_SYNTH ""
set_fileset_property synthesis_files TOP_LEVEL uart_cpu_peripheral
foreach f {avalon_apb_bridge.v lcd_text.v uart_cpu_peripheral.v} {
  add_fileset_file $f VERILOG PATH ../rtl/$f
}
foreach f {reset_sync.v uart_sync.v uart_apb_slave.v uart_regs.v uart_tx.v uart_rx.v uart_rx_slot.v uart_apb_top.v} {
  add_fileset_file $f VERILOG PATH ../../RTL/rtl/$f
}
add_fileset_file uart_functions.vh VERILOG_INCLUDE PATH ../../RTL/rtl/uart_functions.vh
add_interface clock clock end
add_interface_port clock clk clk Input 1
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
add_interface_port reset reset_n reset_n Input 1
add_interface avalon avalon end
set_interface_property avalon associatedClock clock
set_interface_property avalon associatedReset reset
set_interface_property avalon addressUnits SYMBOLS
set_interface_property avalon bitsPerSymbol 8
set_interface_property avalon readLatency 0
set_interface_property avalon maximumPendingReadTransactions 0
set_interface_property avalon maximumPendingWriteTransactions 0
set_interface_property avalon timingUnits Cycles
set_interface_property avalon readWaitTime 0
set_interface_property avalon writeWaitTime 0
set_interface_property avalon setupTime 0
set_interface_property avalon holdTime 0
foreach {name role direction width} {
  address address Input 13
  read read Input 1
  write write Input 1
  writedata writedata Input 32
  byteenable byteenable Input 4
  readdata readdata Output 32
  waitrequest waitrequest Output 1
} { add_interface_port avalon $name $role $direction $width }
add_interface pins conduit end
set_interface_property pins associatedClock clock
set_interface_property pins associatedReset reset
foreach {name direction width} {
  rx Input 1 cts_n Input 1 tx Output 1 rts_n Output 1
  switches Input 8 keys_n Input 3 leds Output 2
  lcd_data Output 8 lcd_rs Output 1 lcd_rw Output 1
  lcd_en Output 1 lcd_on Output 1 lcd_blon Output 1
} { add_interface_port pins $name $name $direction $width }
