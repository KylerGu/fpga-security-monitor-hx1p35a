onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v
vlog ../../user_source/hdl_source/awb.v ../../user_source/hdl_source/isp/awb/signal_delay.v ../../user_source/hdl_source/data_96bit_to_128bit.v ../../user_source/hdl_source/isp/isp_top.v ../../user_source/hdl_source/isp/edge_detect_96.v tb_isp_frame.v
vsim -t 1ps work.tb_isp_frame
run -all
quit -code 0 -force
