`timescale 1ns/1ps
module tb_display;
 reg ddr=0,hdmi=0,rstn=0,sel=0,cv=1,vs=0,de=0,user=0;
 always #7.5 ddr=~ddr;always #6.667 hdmi=~hdmi;
 reg[255:0]meta=0;reg[15:0]epoch=0;
 wire[255:0]shown;wire valid,dropped;
 security_display_metadata dut(ddr,hdmi,rstn,sel,cv,meta,epoch,vs,de,user,shown,valid,dropped);
 integer errors=0;
 task publish;input integer id,ep;begin
  wait(dut.ready);@(negedge ddr);meta=0;meta[255:224]=id;meta[207:206]=2;epoch=ep;sel=1;
  @(negedge ddr);sel=0;
 end endtask
 task start_blank;begin
  @(negedge hdmi);de=0;user=0;vs=1;
  repeat(5)@(negedge hdmi);vs=0;
 end endtask
 task active;begin
  @(negedge hdmi);de=1;user=1;@(negedge hdmi);user=0;
 end endtask
 task check;input integer v,id;begin
  if(valid!==v[0] || (v && shown[255:224]!==id))begin errors=errors+1;$display("FAIL display meta valid=%b id=%0d expected=%0d/%0d",valid,shown[255:224],v,id);end
 end endtask
 initial begin
  repeat(5)@(negedge ddr);rstn=1;repeat(6)@(negedge hdmi);
  start_blank;publish(11,1);repeat(15)@(negedge hdmi);active;check(1,11);
  // A descriptor for the wrong picture arrives during active display.
  publish(99,1);repeat(15)@(negedge hdmi);check(1,11);
  de=0;repeat(15)@(negedge hdmi);check(1,11);de=1;repeat(10)@(negedge hdmi);check(1,11);
  // The queued old epoch is discarded in the next vertical blank, then fresh data wins.
  start_blank;repeat(15)@(negedge hdmi);check(0,0);
  publish(12,2);repeat(15)@(negedge hdmi);active;check(1,12);
  start_blank;cv=0;publish(0,3);repeat(15)@(negedge hdmi);active;check(0,0);
  if(dropped)errors=errors+1;
  if(errors==0)$display("SIMULATION_PASS display epoch late_descriptor vertical_only stable_mode");
  else $display("SIMULATION_FAIL display errors=%0d",errors);
  $finish;
 end
endmodule
