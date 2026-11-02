`timescale 1ns/1ps
module tb_controls;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,setup=0,aesw=0;reg[2:0]keys=7;wire[1:0]mode;wire[63:0]ctrl;reg sec0;
 security_controls #(.DEBOUNCE(3),.LONG_PRESS(25),.CLOCKS_PER_SEC(50)) dut(clk,rstn,keys,setup,mode,ctrl,aesw);
 integer errors=0,i;
 task key;input integer n,clocks;begin
  @(negedge clk);keys[n]=0;repeat(clocks)@(negedge clk);keys[n]=1;repeat(9)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rstn=1;
  // SW2 reaches [57] after two synchroniser stages; [58] toggles every CLOCKS_PER_SEC clocks.
  if(ctrl[57])errors=errors+1;aesw=1;repeat(3)@(negedge clk);if(!ctrl[57])errors=errors+1;
  aesw=0;repeat(3)@(negedge clk);if(ctrl[57])errors=errors+1;
  @(posedge ctrl[58] or negedge ctrl[58]);sec0=ctrl[58];repeat(49)@(negedge clk);if(ctrl[58]!==sec0)errors=errors+1;
  repeat(2)@(negedge clk);if(ctrl[58]===sec0)errors=errors+1;
  key(0,9);if(mode!=3)errors=errors+1;
  key(0,9);if(mode!=1)errors=errors+1;
  key(0,9);if(mode!=2)errors=errors+1;
  key(1,9);if(mode!=0)errors=errors+1;
  if(ctrl[56:55]!=2)errors=errors+1;                          // default sensitivity S2
  key(1,9);if(mode!=0 || ctrl[56:55]!=3)errors=errors+1;      // KEY3 while in RAW: next level
  key(1,9);if(ctrl[56:55]!=0)errors=errors+1;                 // S3 wraps to S0
  key(1,9);key(1,9);if(ctrl[56:55]!=2)errors=errors+1;
  key(0,9);key(1,9);if(mode!=0 || ctrl[56:55]!=2)errors=errors+1; // outside RAW KEY3 only returns
  key(2,9);if(!ctrl[3])errors=errors+1;
  key(2,40);if(!ctrl[3] || !ctrl[2])errors=errors+1;
  setup=1;repeat(10)@(negedge clk);
  if(ctrl[3] || !ctrl[4])errors=errors+1;
  key(2,9);if(ctrl[38:31]!=41)errors=errors+1;
  key(1,9);if(ctrl[38:31]!=40)errors=errors+1;
  key(0,9);key(2,9);if(ctrl[30:23]!=23)errors=errors+1;
  setup=0;repeat(10)@(negedge clk);
  if(ctrl[3] || ctrl[4])errors=errors+1;
  setup=1;repeat(10)@(negedge clk);key(0,9);
  for(i=0;i<80;i=i+1)key(1,9);
  if(ctrl[22:15]!=8)errors=errors+1;
  key(0,9);key(0,9);
  for(i=0;i<200;i=i+1)key(2,9);
  if(ctrl[38:31]!=152 || ctrl[3])errors=errors+1;
  if(errors==0)$display("SIMULATION_PASS controls modes setup edit arm long_clear sensitivity ae_switch second_toggle");
  else $display("SIMULATION_FAIL controls errors=%0d control=%h",errors,ctrl);
  $finish;
 end
endmodule
