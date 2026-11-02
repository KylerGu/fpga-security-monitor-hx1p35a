onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v ../../user_source/hdl_source/security/security_frame_cdc.v tb_reset.v
vsim -t 1ps work.tb_reset
run -all
quit -code 0 -force
