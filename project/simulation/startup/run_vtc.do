onerror {quit -code 1 -force}
if {![file exists work_vtc]} {vlib work_vtc}
vmap work_vtc work_vtc
set root ../../user_source
vlog -work work_vtc $root/hdl_source/security/security_reset_release.v
vlog -work work_vtc $root/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v $root/ip_source/w128_d512_fifo/w128_d512_fifo.v
vlog -work work_vtc $root/hdl_source/security/security_frame_cdc.v $root/hdl_source/security/security_video_out.v $root/hdl_source/security/security_display_metadata.v $root/hdl_source/vtc/uivtc.v security_video_out_original.v startup_reader_path.v tb_wait_vtc.v
vsim -t 1ps work_vtc.tb_wait_vtc
run -all
quit -code 0 -force
