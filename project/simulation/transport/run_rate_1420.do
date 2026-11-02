onerror {quit -code 1 -force}
if {![file exists work_rate_1420]} {vlib work_rate_1420}
vmap work_rate_1420 work_rate_1420
vlog -work work_rate_1420 ../../user_source/hdl_source/security/security_reset_release.v
vlog -work work_rate_1420 ../../user_source/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v ../../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.v ../../user_source/ip_source/w155_d512_fifo/soft_fifo_al_f58e8b3e1f3d.v
vlog -work work_rate_1420 ../../user_source/hdl_source/security/security_capture_writer.v ../../user_source/hdl_source/security/security_mc_interface.v ../../user_source/hdl_source/security/security_frame_manager.v ../../user_source/hdl_source/security/security_video_out.v tb_transport_rate.v
vsim -t 1ps -gROW_BLANK=1420 work_rate_1420.tb_transport_rate
run -all
quit -code 0 -force
