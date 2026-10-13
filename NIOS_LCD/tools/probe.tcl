package require -exact qsys 24.1
create_system probe
add_instance cpu altera_nios2_gen2
puts "CPU_PARAMETERS=[get_instance_parameters cpu]"
foreach p {impl resetSlave exceptionSlave resetOffset exceptionOffset} {puts "$p=[get_instance_parameter_value cpu $p]"}
