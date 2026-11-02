onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_pass_counter.v tb_counter.v
vsim -t 1ps work.tb_pass_counter
run -all
quit -code 0 -force
