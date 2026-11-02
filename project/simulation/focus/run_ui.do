onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/hdmi_mixer.v tb_ui.v
vsim -t 1ps work.tb_ui
run -all
quit -code 0 -force
