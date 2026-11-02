onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v
vlog ../../user_source/hdl_source/design_top_wrapper.v ../../user_source/hdl_source/isp/isp_top.v ../../user_source/hdl_source/hdmi_mixer.v ../../user_source/hdl_source/display_mode_label.v
quit -code 0 -force
