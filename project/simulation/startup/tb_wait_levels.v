`timescale 1ns/1ps
module tb_wait_levels;
 reg ddr=0,hdmi=0,rstn=0,vs_low=0,vs_high=1,de=0,user=0;
 always #7.5 ddr=~ddr;
 always #6.667 hdmi=~hdmi;
 wire[3:0]valid,underflow;
 wire[15:0]olr,oldis,ohr,ohdis,flr,fldis,fhr,fhdis;
 startup_reader_path #(0)original_low(ddr,hdmi,rstn,vs_low,de,user,
  valid[0],underflow[0],olr,oldis);
 startup_reader_path #(0)original_high(ddr,hdmi,rstn,vs_high,de,user,
  valid[1],underflow[1],ohr,ohdis);
 startup_reader_path #(1)fixed_low(ddr,hdmi,rstn,vs_low,de,user,
  valid[2],underflow[2],flr,fldis);
 startup_reader_path #(1)fixed_high(ddr,hdmi,rstn,vs_high,de,user,
  valid[3],underflow[3],fhr,fhdis);
 integer frame,errors=0;
 task check;
  input integer n;
  begin
   $display("STARTUP_LEVELS frame=%0d original_low=%b:%0d/%0d original_high=%b:%0d/%0d fixed_low=%b:%0d/%0d fixed_high=%b:%0d/%0d underflow=%b",
    n,valid[0],olr,oldis,valid[1],ohr,ohdis,
    valid[2],flr,fldis,valid[3],fhr,fhdis,underflow);
   if(valid[0]!==1'b1 || olr!==oldis)errors=errors+1;
   if(valid[1]!==1'b0 || ohdis!==(ohr+16'd1))errors=errors+1;
   if(valid[2]!==1'b1 || flr!==fldis)errors=errors+1;
   if(valid[3]!==1'b1 || fhr!==fhdis)errors=errors+1;
   if(underflow!==4'd0)errors=errors+1;
  end
 endtask
 initial begin
  repeat(20)@(negedge ddr);rstn=1;
  repeat(90)@(negedge hdmi);de=1;user=1;
  @(negedge hdmi);user=0;check(0);
  for(frame=1;frame<=5;frame=frame+1)begin
   repeat(25)@(negedge hdmi);
   de=0;vs_low=0;vs_high=0;
   repeat(15)@(negedge hdmi);vs_low=1;vs_high=1;
   repeat(90)@(negedge hdmi);de=1;user=1;
   @(negedge hdmi);user=0;check(frame);
  end
  if(errors==0)$display("SIMULATION_PASS startup_levels original_rejected_fixed_valid frames=6 initial_sync_levels=2");
  else $display("SIMULATION_FAIL startup_levels errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("SIMULATION_FAIL startup_levels timeout");$finish;end
endmodule
