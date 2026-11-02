onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
set root ../../user_source/hdl_source/security
vlog $root/security_buzzer.v $root/security_alarm.v $root/security_controls.v $root/security_frame_cdc.v $root/security_reset_release.v production_buzzer_path.v tb_buzzer.v
vsim -t 1ps work.tb_buzzer
run -all
quit -code 0 -force
