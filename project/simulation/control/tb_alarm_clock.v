`timescale 1ns/1ps
// Measure against independent reference-clock edges while the camera clock stops.
// One modeled millisecond is 100 reference cycles; the 2000/500 ms limits and
// five-frame confirmation are the production values, with only time accelerated.
module tb_alarm_clock;
 localparam C=100;
 reg ref_clk=0,cam_clk=0,cam_run=1;
 always #10 ref_clk=~ref_clk;
 always #4.830 if(cam_run)cam_clk=~cam_clk;else cam_clk=0;
 reg rstn=0,armed=1,setting=0,clear=0,fv=0,motion=0,valid=1;
 wire ready,reply_valid,alarm,interrupted;wire[26:0]reply;
 security_alarm_bridge #(.CLOCKS_PER_MS(C)) dut(
  cam_clk,rstn,ref_clk,rstn,armed,setting,clear,fv,motion,valid,
  ready,reply_valid,reply,alarm,interrupted);
 integer errors=0,i,cycles=0,quiet_start=-1,release_cycle=-1;
 reg measure_quiet=0;
 always @(posedge ref_clk)begin
  cycles=cycles+1;
  if(measure_quiet && quiet_start<0 && dut.ref_frame_valid && dut.ref_frame_data==2'b01)
   quiet_start=cycles;
  #1;if(measure_quiet && quiet_start>=0 && release_cycle<0 && !alarm)release_cycle=cycles;
 end
 task check;input condition;input[799:0]message;begin
  if(!condition)begin errors=errors+1;$display("FAIL alarm_clock %0s",message);end
 end endtask
 task frame;input moving;begin
  wait(ready);@(negedge cam_clk);fv=1;motion=moving;
  @(negedge cam_clk);fv=0;
  wait(reply_valid);@(negedge cam_clk);
 end endtask
 task pause_camera;input integer ref_cycles;begin
  @(negedge cam_clk);cam_run=0;
  repeat(ref_cycles)@(negedge ref_clk);cam_run=1;
 end endtask
 initial begin
  repeat(10)@(negedge ref_clk);rstn=1;repeat(20)@(negedge cam_clk);
  check(interrupted,"startup has no complete frame");
  valid=0;repeat(6)frame(1);check(!alarm && dut.event_bcd==0,"invalid frames cannot alarm");valid=1;
  repeat(4)frame(1);check(!alarm,"four moving frames are insufficient");
  frame(0);repeat(4)frame(1);check(!alarm,"no-motion breaks the confirmation streak");
  frame(1);check(alarm && reply[25] && reply[23:0]==1,"fifth moving frame has coherent alarm/count reply");
  measure_quiet=1;frame(0);
  // About 75% of every subsequent frame interval has no camera clock. Gaps are
  // shorter than the 500 ms data-loss threshold, so quiet time must still elapse.
  for(i=0;i<22;i=i+1)begin
   pause_camera(75*C);frame(0);repeat(25*C)@(negedge ref_clk);
  end
  check(release_cycle>=0,"quiet alarm releases despite stopped camera intervals");
  check(release_cycle-quiet_start>=1999*C && release_cycle-quiet_start<=2001*C,
   "quiet release follows 2000 reference milliseconds within one tick");
  check(!alarm && dut.event_bcd==1,"one event retained after automatic release");
  $display("REFERENCE_QUIET_CYCLES %0d expected=%0d tolerance=%0d",release_cycle-quiet_start,2000*C,C);
  measure_quiet=0;
  repeat(5)frame(1);check(alarm && dut.event_bcd==2,"new motion retriggers once");
  @(negedge cam_clk);cam_run=0;
  repeat(497*C)@(negedge ref_clk);check(!interrupted,"watchdog does not expire early");
  repeat(5*C)@(negedge ref_clk);
  check(interrupted && alarm,"500 ms watchdog runs with camera stopped and retains live alarm");
  clear=1;repeat(4)@(negedge ref_clk);check(alarm && dut.event_bcd==0,"count clear works with stopped camera");
  armed=0;repeat(4)@(negedge ref_clk);check(!alarm,"disarm works with stopped camera");
  armed=1;repeat(10)@(negedge ref_clk);check(!alarm,"rearming cannot reuse stale motion");
  cam_run=1;repeat(20)@(negedge cam_clk);frame(0);
  repeat(4)frame(1);
  wait(ready);@(negedge cam_clk);fv=1;motion=1;
  @(negedge cam_clk);fv=0;cam_run=0;
  repeat(50)@(negedge ref_clk);
  check(alarm && dut.event_bcd==1 && !ready,"pending decision is retained while camera stops before reply");
  cam_run=1;wait(reply_valid);@(negedge cam_clk);
  check(reply[25] && reply[23:0]==1,"resumed camera receives the pending frame's decision once");
  @(negedge cam_clk);cam_run=0;
  #3;rstn=0;#1;check(!alarm && dut.event_bcd==0,"asynchronous reset works without camera edges");
  repeat(4)@(negedge ref_clk);rstn=1;repeat(10)@(negedge ref_clk);
  cam_run=1;repeat(20)@(negedge cam_clk);frame(0);
  check(!alarm && dut.event_bcd==0,"reset cannot replay a stale alarm or count");
  repeat(4)frame(1);check(!alarm,"four frames before data loss do not alarm");
  pause_camera(502*C);check(interrupted,"long pause reports missing data");
  frame(1);check(!alarm,"resumption cannot reuse the pre-outage four-frame streak");
  repeat(3)frame(1);check(!alarm,"resumption still requires five new moving frames");
  frame(1);check(alarm && dut.event_bcd==1,"fifth fresh frame after outage alarms once");
  if(errors==0)$display("SIMULATION_PASS alarm_clock crystal_2000ms stopped_camera watchdog500 disarm clear reset coherent_reply restart_confirm5");
  else $display("SIMULATION_FAIL alarm_clock errors=%0d",errors);
  $finish;
 end
 initial begin #20000000;$display("SIMULATION_FAIL alarm_clock timeout");$finish;end
endmodule
