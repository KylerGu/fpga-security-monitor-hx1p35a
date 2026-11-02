cd [file dirname [info script]]
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project camera_to_dsi_display.al -single_run
import_db ./security_build/security_routed.db
cd security_build
commit_param -step bitgen
bitgen -bit security_monitor_720p_ddr_fix.bit
puts "SECURITY_BITGEN_COMPLETE"
close_project
exit
