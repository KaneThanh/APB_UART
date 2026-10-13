package require -exact qsys 24.1
create_system peripheral_check
set_project_property DEVICE_FAMILY "Cyclone IV E"
set_project_property DEVICE EP4CE115F29C7
add_instance peripheral uart_cpu_peripheral 1.0
foreach {name type target} {clk clock clock reset reset reset bus avalon avalon board conduit pins} {
  add_interface $name $type end
  set_interface_property $name EXPORT_OF peripheral.$target
}
save_system peripheral_check.qsys
