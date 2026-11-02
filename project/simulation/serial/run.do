onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog $env(TD_ROOT)/sim_release/ph1p/ph1p_phy_gsr.v $env(TD_ROOT)/sim_release/ph1p/ph1p_phy_hr_pad.v $env(TD_ROOT)/sim_release/ph1p/ph1p_logic_hrio.v
vlog ../../user_source/hdl_source/security/security_reset_release.v ../../user_source/hdl_source/lane_lvds_10_1.v lane_reference.v tb_serial.v
vsim -t 1ps work.tb_serial work.PH1P_PHY_GSR
run -all
quit -code 0 -force
