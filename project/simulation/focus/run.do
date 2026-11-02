onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/isp/edge_detect_96.v tb_focus.v
vsim -t 1ps work.tb_focus
run -all
quit -code 0 -force
