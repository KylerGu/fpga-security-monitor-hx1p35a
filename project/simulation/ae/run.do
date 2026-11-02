onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_auto_exposure.v tb_ae.v
vsim -t 1ps work.tb_ae
run -all
quit -code 0 -force
