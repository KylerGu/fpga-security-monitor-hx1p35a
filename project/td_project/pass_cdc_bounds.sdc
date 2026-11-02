# The crystal/HDMI passage snapshot is a held-data toggle handshake, not a
# phase-dependent transfer. Bound ONLY its bundle and first synchronizer stages.
# 9.660 ns < both functional periods (20.000 / 13.333 ns) and the two-stage
# request settling window. datapath_only excludes the meaningless first-stage
# inter-clock hold check; ack1->ack2, req1->req2 and all local logic stay timed.
set_max_delay -from [get_regs {u_pass_monitor/display/held[*]}] -to [get_regs {u_pass_monitor/display/dst_data[*]}] -datapath_only 9.660
set_max_delay -from [get_regs {u_pass_monitor/display/req}] -to [get_regs {u_pass_monitor/display/req1}] -datapath_only 9.660
set_max_delay -from [get_regs {u_pass_monitor/display/ack}] -to [get_regs {u_pass_monitor/display/ack1}] -datapath_only 9.660
