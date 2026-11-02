onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v
vlog ../../user_source/hdl_source/security/security_frame_cdc.v ../../user_source/hdl_source/security/security_display_metadata.v tb_display.v
vsim -t 1ps work.tb_display
run -all
quit -code 0 -force
