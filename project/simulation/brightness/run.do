onerror {quit -code 1 -force}
if {![file exists work]} {vlib work}
vmap work work
vlog ../../user_source/hdl_source/security/security_reset_release.v
vlog ../../user_source/hdl_source/hdmi_mixer.v color_mixer_reference.v color_overlay_reference.v ../../user_source/hdl_source/display_mode_label.v ../../user_source/hdl_source/anlogic_logo_rom.v ../../user_source/hdl_source/osd_char_lib.v ../../user_source/hdl_source/security/security_overlay.v ../../user_source/hdl_source/security/security_color_overlay.v tb_fixed_brightness.v
vsim -t 1ps work.tb_brightness
run -all
quit -code 0 -force
