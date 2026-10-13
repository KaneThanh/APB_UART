package require -exact qsys 16.1
create_system nios_uart_system
set_project_property DEVICE_FAMILY "Cyclone IV E"
set_project_property DEVICE EP4CE115F29C7
add_instance clock_source clock_source
set_instance_parameter_value clock_source clockFrequency 50000000
set_instance_parameter_value clock_source clockFrequencyKnown true
set_instance_parameter_value clock_source resetSynchronousEdges DEASSERT
add_instance cpu altera_nios2_gen2
if {[lsearch -exact [get_instances] cpu] < 0} {
  error "Nios II Gen2 IP is missing. No CPU system will be saved. Use a Quartus installation with this IP."
}
set_instance_parameter_value cpu impl Tiny
set_instance_parameter_value cpu resetSlave ram.s1
set_instance_parameter_value cpu resetOffset 0
set_instance_parameter_value cpu exceptionSlave ram.s1
set_instance_parameter_value cpu exceptionOffset 32
add_instance ram altera_avalon_onchip_memory2
set_instance_parameter_value ram memorySize 65536
set_instance_parameter_value ram dataWidth 32
set_instance_parameter_value ram initMemContent true
set_instance_parameter_value ram writable true
add_instance peripheral uart_cpu_peripheral 1.0
add_connection clock_source.clk cpu.clk
add_connection clock_source.clk ram.clk1
add_connection clock_source.clk peripheral.clock
add_connection clock_source.clk_reset cpu.reset
add_connection clock_source.clk_reset ram.reset1
add_connection clock_source.clk_reset peripheral.reset
add_connection cpu.debug_reset_request cpu.reset
add_connection cpu.debug_reset_request ram.reset1
add_connection cpu.debug_reset_request peripheral.reset
add_connection cpu.instruction_master ram.s1
add_connection cpu.data_master ram.s1
add_connection cpu.data_master peripheral.avalon
add_connection cpu.data_master cpu.debug_mem_slave
add_connection cpu.instruction_master cpu.debug_mem_slave
set_connection_parameter_value cpu.instruction_master/ram.s1 baseAddress 0x00010000
set_connection_parameter_value cpu.data_master/ram.s1 baseAddress 0x00010000
set_connection_parameter_value cpu.data_master/peripheral.avalon baseAddress 0x00020000
set_connection_parameter_value cpu.data_master/cpu.debug_mem_slave baseAddress 0x00030000
set_connection_parameter_value cpu.instruction_master/cpu.debug_mem_slave baseAddress 0x00030000
add_interface clk clock sink
set_interface_property clk EXPORT_OF clock_source.clk_in
add_interface reset reset sink
set_interface_property reset EXPORT_OF clock_source.clk_in_reset
add_interface board conduit end
set_interface_property board EXPORT_OF peripheral.pins
save_system nios_uart_system.qsys
