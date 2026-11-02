onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_camera_motion.v ../../user_source/hdl_source/security/security_frame_manager.v tb_latency.v
vsim -t 1ps work.tb_latency
run -all
quit -code 0 -force
