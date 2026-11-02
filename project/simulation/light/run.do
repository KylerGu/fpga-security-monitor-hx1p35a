onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v
vlog ../../user_source/hdl_source/security/security_frame_cdc.v
vlog $env(TD_ROOT)/sim_release/ph1p/ph1p_phy_gsr.v $env(TD_ROOT)/sim_release/ph1p/ph1p_logic_eram.v
vlog ../../user_source/hdl_source/security/security_eram_bank.v ../../user_source/hdl_source/security/security_ram_probe.v ../../user_source/hdl_source/security/security_downsample4.v ../../user_source/hdl_source/security/security_frame_diff.v ../../user_source/hdl_source/security/security_alarm.v ../../user_source/hdl_source/security/security_color_detect.v ../../user_source/hdl_source/security/security_auto_exposure.v ../../user_source/hdl_source/security/security_camera_motion.v tb_light.v
vsim -t 1ps work.tb_light work.PH1P_PHY_GSR
run -all
quit -code 0 -force
