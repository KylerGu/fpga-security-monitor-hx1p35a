cd [file dirname [info script]]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project camera_to_dsi_display.al
file mkdir security_build
cd security_build
commit_param -step design
elaborate -top design_top_wrapper
read_adc ../../user_source/constraints_source/pin.adc
read_ip_adc -ip ddr2 -file ../../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc
read_sdc ../camera_to_dsi_display.sdc
read_sdc ../pass_cdc_bounds.sdc
read_sdc -ip ddr2 ../../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc
read_sdc -ip w128_d512_fifo ../../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl
commit_param -step rtl
optimize_rtl
commit_param -step gate
optimize_gate -packarea gate.area
legalize_phy_inst
commit_param -step place
set_param place fix_hold high
place
commit_param -step route
route
update_timing -mode final
report_timing_summary -file final_timing.rpt
report_timing_status -file final_timing.ts
report_timing_exception -file exceptions.rpt
report_timing_ignored -file ignored.rpt
check_timing -verbose -file checks.rpt
report_timing_path -from [get_regs {u_security_camera/events/request/held[*]}] -to [get_regs {u_security_camera/events/request/dst_data[*]}] -file alarm_request_bundle.rpt -ep_num 256
report_timing_path -from [get_regs {u_security_camera/events/response/held[*]}] -to [get_regs {u_security_camera/events/response/dst_data[*]}] -file alarm_response_bundle.rpt -ep_num 256
report_timing_path -to [get_regs {u_security_camera/events/request/ack2 u_security_camera/events/request/req2}] -file alarm_request_sync.rpt
report_timing_path -to [get_regs {u_security_camera/events/response/ack2 u_security_camera/events/response/req2}] -file alarm_response_sync.rpt
report_timing_path -to [get_regs {u_security_camera/events/events/quiet_ms[*] u_security_camera/events/events/watchdog[*]}] -file alarm_timer.rpt -ep_num 64
report_timing_path -to [get_regs {u_security_result/ack2}] -file result_sync.rpt
report_timing_path -to [get_regs {u_security_display_metadata/mailbox/ack2}] -file display_sync.rpt
report_timing_path -from [get_regs {u_security_control/held[*]}] -to [get_regs {u_security_control/dst_data[*]}] -file control_bundle.rpt -ep_num 256
report_timing_path -from [get_regs {u_security_result/held[*]}] -to [get_regs {u_security_result/dst_data[*]}] -file result_bundle.rpt -ep_num 256
report_timing_path -from [get_regs {u_security_display_metadata/mailbox/held[*]}] -to [get_regs {u_security_display_metadata/mailbox/dst_data[*]}] -file display_bundle.rpt -ep_num 256
report_timing_path -from [get_regs {u_focus_cdc/held[*]}] -to [get_regs {u_focus_cdc/dst_data[*]}] -file focus_bundle.rpt -ep_num 64
report_timing_path -to [get_regs {u_focus_cdc/ack2 u_focus_cdc/req2}] -file focus_sync.rpt
report_timing_path -from [get_regs {u_pass_monitor/observations/held[*]}] -to [get_regs {u_pass_monitor/observations/dst_data[*]}] -file pass_observations_bundle.rpt -ep_num 64
report_timing_path -to [get_regs {u_pass_monitor/observations/ack2 u_pass_monitor/observations/req2}] -file pass_observations_sync.rpt
report_timing_path -from [get_regs {u_pass_monitor/display/held[*]}] -to [get_regs {u_pass_monitor/display/dst_data[*]}] -file pass_display_bundle.rpt -ep_num 64
report_timing_path -to [get_regs {u_pass_monitor/display/ack2 u_pass_monitor/display/req2}] -file pass_display_sync.rpt
report_timing_path -from [get_regs {u_pass_monitor/display/ack u_pass_monitor/display/req}] -to [get_regs {u_pass_monitor/display/ack1 u_pass_monitor/display/req1}] -file pass_display_handshake.rpt -ep_num 4
report_area -io_info -file resources.area
report_clock_utilization -file clocks.txt
export_db security_routed.db
puts "SECURITY_ROUTED_COMPLETE"
close_project
exit
