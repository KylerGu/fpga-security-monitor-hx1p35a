`timescale 1ps/1ps
`include "ph1p_mis_define.vh"
module tb;
reg refclk=0, rst=1;
wire cfg,userclk,locked;
wire [1:0] ctl,ddr;
always #10000 refclk=~refclk;
`include "generated_instance.vh"
`include "ddr2_parameter.vh"
real start_ddr,start_user,start_cfg,period_ddr,period_user,period_cfg;
task measure;
begin
 fork
  begin @(posedge ddr[0]);start_ddr=$realtime;repeat(400) @(posedge ddr[0]);period_ddr=($realtime-start_ddr)/400;end
  begin @(posedge userclk);start_user=$realtime;repeat(100) @(posedge userclk);period_user=($realtime-start_user)/100;end
  begin @(posedge cfg);start_cfg=$realtime;repeat(100) @(posedge cfg);period_cfg=($realtime-start_cfg)/100;end
 join
 $display("CLOCK_MEASURE ddr_ps=%f user_ps=%f cfg_ps=%f lock=%b",period_ddr,period_user,period_cfg,locked);
 if(period_ddr<3749 || period_ddr>3751 || period_user<14999 || period_user>15001 || period_cfg<19999 || period_cfg>20001 || locked!==1'b1)begin $display("SIMULATION_FAIL frequency");$finish;end
end
endtask
initial begin
 if(tCK!=3750 || nREFI!=2080 || nRFC!=28 || nWR!=4)begin $display("SIMULATION_FAIL timing_parameters %d %d %d %d",tCK,nREFI,nRFC,nWR);$finish;end
 #200000 rst=0;
 wait(locked===1'b1);#1000000;measure;
 rst=1;#200000;
 if(locked!==1'b0)begin $display("SIMULATION_FAIL reset_did_not_unlock");$finish;end
 rst=0;wait(locked===1'b1);#1000000;measure;
 $display("SIMULATION_PASS ddr_clock vendor_models 50MHz_ref DDR266.667 user66.667 cfg50 reset_relock tCK3750 nREFI2080 nRFC28 nWR4");$finish;
end
initial begin #2000000000;$display("SIMULATION_FAIL timeout");$finish;end
endmodule
