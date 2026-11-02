onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/isp/demosaic_4x_2_0/bilinear_interpolation.v tb_bayer_channels.v
vsim -t 1ps work.tb_bayer_channels
run -all
quit -code 0 -force
