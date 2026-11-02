`timescale 1ns/1ps
module tb_serial;
 reg pixel=0,serial=0,rst=1,compare=0;
 always #6.667 pixel=~pixel;
 always #1.3334 serial=~serial;
 reg[9:0]symbol=0;
 wire actual,reference;
 lane_lvds_10_1 #(.DEVICE("PH1P")) dut(pixel,serial,rst,symbol,actual);
 lane_reference #(.DEVICE("PH1P")) golden(pixel,serial,rst,symbol,reference);
 integer errors=0,checks=0,k;
 always @(negedge pixel)symbol<={symbol[8:0],symbol[9]^symbol[6]^1'b1};
 always @(posedge serial or negedge serial)begin
  #0.1;
  if(compare)begin
   checks=checks+1;
   if(actual!==reference || actual===1'bx)begin
    if(errors<5)$display("FAIL serial data got=%b reference=%b",actual,reference);
    errors=errors+1;
   end
  end
 end
 initial begin
  repeat(15)@(negedge pixel);
  for(k=0;k<12;k=k+1)begin
   compare=0;rst=1;repeat(5)@(negedge pixel);#(k*0.17+0.23);rst=0;
   // Compare data after normal lane synchronization has settled.
   repeat(10)@(negedge pixel);compare=1;
   repeat(40)@(negedge pixel);
  end
  compare=0;
  if(errors==0 && checks>=4700)$display("SIMULATION_PASS serial real_lane vendor_ODDR reset_phases12 output_edges=%0d",checks);
  else $display("SIMULATION_FAIL serial errors=%0d checks=%0d",errors,checks);
  $finish;
 end
endmodule
