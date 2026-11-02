`timescale 1ns/1ps
module tb_alarm;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,armed=0,setting=0,clear=0,fv=0,motion=0,valid=1;
 wire alarm,interrupted;wire[23:0]count;
 security_alarm #(.CLOCKS_PER_MS(3),.QUIET_MS(7)) dut(clk,rstn,armed,setting,clear,fv,motion,valid,alarm,count,interrupted);
 integer errors=0,i;
 task frame;input integer moving;begin
  @(negedge clk);fv=1;motion=moving;@(negedge clk);fv=0;
 end endtask
 task check;input integer a,c;begin
  if(alarm!==a[0] || count!==c)begin errors=errors+1;$display("FAIL alarm=%b count=%h expected=%0d/%0d",alarm,count,a,c);end
 end endtask
 initial begin
  repeat(4)@(negedge clk);rstn=1;armed=1;
  for(i=0;i<4;i=i+1)frame(1);check(0,0);
  frame(0);frame(1);frame(1);frame(1);frame(1);check(0,0);
  frame(1);check(1,1);
  repeat(10)frame(1);check(1,1);
  frame(0);repeat(12)@(negedge clk);check(1,1);
  frame(1);repeat(30)@(negedge clk);check(1,1);
  frame(0);repeat(25)@(negedge clk);check(0,1);
  repeat(5)frame(1);check(1,2);
  clear=1;repeat(2)@(negedge clk);check(1,0);
  repeat(5)frame(1);check(1,0);
  setting=1;@(negedge clk);check(0,0);setting=0;
  valid=0;repeat(7)frame(1);check(0,0);valid=1;
  repeat(5)frame(1);check(1,1);
  // A stalled detector does not repeatedly count or silently clear an alarm.
  repeat(1600)@(negedge clk);check(1,1);
  if(!interrupted)errors=errors+1;
  armed=0;@(negedge clk);check(0,1);
  dut.event_bcd=24'h999998;armed=1;
  repeat(5)frame(1);check(1,24'h999999);
  frame(0);repeat(25)@(negedge clk);repeat(5)frame(1);check(1,24'h999999);
  if(errors==0)$display("SIMULATION_PASS alarm confirm5 quiet_timer reentry clear disarm watchdog bcd_saturates");
  else $display("SIMULATION_FAIL alarm errors=%0d",errors);
  $finish;
 end
endmodule
