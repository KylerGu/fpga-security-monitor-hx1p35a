`timescale 1ns/1ps
module tb_pass_counter;
 reg clk=0;always #10 clk=~clk;
 reg rstn=0,sv=0,stale=0,setting=0;reg[1:0]sens=2;
 reg[35:0]sample=0;wire[39:0]status;wire passed;
 security_pass_counter dut(clk,rstn,sv,sample,stale,setting,sens,status,passed);
 integer errors=0,seq=0,events=0,i;
 task obs;input integer x;input ok,found;begin
  @(negedge clk);seq=seq+1;sample={seq[15:0],ok,found,x[7:0],x[7:0],sens};sv=1;
  @(negedge clk);sv=0;if(passed)events=events+1;
 end endtask
 task side3;input integer x;begin repeat(3)obs(x,1,1);end endtask
 task check;input[11:0]t,l,r;input[1:0]dir,side;begin
  if(status!=={side,dir,t,l,r})begin errors=errors+1;$display("FAIL state got=%h expected=%h id=%d",status,{side,dir,t,l,r},seq);end
 end endtask
 task reset;begin @(negedge clk);rstn=0;repeat(3)@(negedge clk);rstn=1;repeat(3)@(negedge clk);end endtask
 initial begin
  reset;
  // First target on line, then on left, never a passage.
  repeat(10)obs(79,1,1);check(0,0,0,0,0);
  side3(50);check(0,0,0,0,1);
  // Exact neutral limits (616,664) and line jitter, long dwell.
  repeat(100)begin obs(76,1,1);obs(77,1,1);obs(82,1,1);obs(83,1,1);end
  obs(79,1,1);
  // Exactly 616 and 664 px, including asymmetric bounding boxes.
  repeat(6)begin
   @(negedge clk);seq=seq+1;sample={seq[15:0],2'b11,8'd82,8'd83,sens};sv=1;
   @(negedge clk);sv=0;
  end
  repeat(6)begin
   @(negedge clk);seq=seq+1;sample={seq[15:0],2'b11,8'd76,8'd77,sens};sv=1;
   @(negedge clk);sv=0;
  end
  check(0,0,0,0,1);
  // One or two far-side frames cannot count; neutral restarts confirmation.
  repeat(10)begin obs(110,1,1);obs(110,1,1);obs(79,1,1);end
  check(0,0,0,0,1);side3(110);check(1,1,0,1,2);
  repeat(100)obs(110,1,1);check(1,1,0,1,2);
  side3(50);check(2,1,1,2,1);
  // Found=0, malformed frame, sequence gap and duplicate all break continuity.
  obs(0,1,0);side3(110);check(2,1,1,2,2);
  obs(50,0,1);side3(50);check(2,1,1,2,1);
  seq=seq+1;side3(110);check(2,1,1,2,2);
  seq=seq-1;side3(50);check(2,1,1,2,1);
  // Reset history during a partially confirmed crossing.
  obs(110,1,1);obs(110,1,1);stale=1;repeat(3)@(negedge clk);stale=0;
  side3(110);check(2,1,1,2,2);
  setting=1;side3(50);setting=0;side3(50);check(2,1,1,2,1);
  sens=3;repeat(3)@(negedge clk);side3(110);check(2,1,1,2,2);
  // Old-sensitivity packet is unusable even though the target was found.
  @(negedge clk);seq=seq+1;sample={seq[15:0],2'b11,8'd50,8'd50,2'd2};sv=1;
  @(negedge clk);sv=0;side3(50);check(2,1,1,2,1);
  // Wrap is continuous, not an association break.
  seq=65532;side3(50);side3(110);check(3,2,1,1,2);
  // Saturation and all decimal carries, using real events (no forced registers).
  reset;events=0;side3(50);
  for(i=0;i<1001;i=i+1)begin side3(110);side3(50);end
  check(12'h999,12'h999,12'h999,2,1);
  if(events!=2002)begin errors=errors+1;$display("FAIL pulses %d",events);end
  reset;check(0,0,0,0,0);
  if(errors==0)$display("SIMULATION_PASS pass_counter first_seen band_jitter dwell reverse lost incomplete skipped_duplicate wrap sensitivity setup stale decimal_saturation pulses2002 reset");
  else $display("SIMULATION_FAIL pass_counter errors=%d",errors);
  $finish;
 end
endmodule
