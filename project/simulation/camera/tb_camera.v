`timescale 1ns/1ps
module tb_camera;
 reg clk=0;always #4.830 clk=~clk;
 reg ref_clk=0;always #10 ref_clk=~ref_clk;
 reg rstn=0,fs=0,iv=0,ll=0;reg[95:0]rgb=0;reg[1:0]mode=2;
 reg[63:0]ctrl={9'b0,16'd7,8'd1,8'd1,8'd4,8'd4,2'd0,1'b0,1'b1,1'b0,2'b0};
 wire[31:0]fid;wire rv,alarm,armed,interrupt;wire[255:0]meta;
 // Full-frame 0/255 toggles here exercise the original alarm rules; light-change
 // protection is disabled (unreachable quadrant threshold) and covered by light/tb_light.v.
 security_camera_motion #(.WIDTH(64),.HEIGHT(64),.CLOCKS_PER_MS(3),.LIGHT_QUAD_MIN(4096))
   dut(clk,rstn,fs,iv,ll,rgb,mode,ctrl,fid,rv,meta,alarm,armed,interrupt,ref_clk,rstn,ctrl);
 integer errors=0,frames=0,lastlevel=0;
 always @(posedge clk)begin #1;if(rv)begin frames=frames+1;
  if(meta[255:224]!=frames || meta[223:208]!=7 || meta[207:206]!=2)begin errors=errors+1;$display("FAIL camera identity");end
  if(frames>=2 && frames<=6)begin
   if(meta[109:96]!=16 || meta[95:82]!=64 || meta[141:110]!={8'd0,8'd0,8'd7,8'd7})begin errors=errors+1;$display("FAIL ROI/box frame=%0d roi=%0d all=%0d box=%h",frames,meta[109:96],meta[95:82],meta[141:110]);end
  end
 end end
 task frame;input integer level;integer w;begin
  @(negedge clk);fs=1;iv=0;@(negedge clk);fs=0;
  for(w=0;w<1024;w=w+1)begin
   @(negedge clk);iv=1;ll=w%16==15;rgb={12{level[7:0]}};
  end
  @(negedge clk);iv=0;ll=0;repeat(64)@(negedge clk);
 end endtask
 initial begin
  repeat(6)@(negedge clk);rstn=1;
  frame(0);frame(255);frame(0);frame(255);frame(0);frame(255);
  if(!alarm || meta[197:174]!=1)begin errors=errors+1;$display("FAIL fifth-confirm event");end
  // At 50 MHz and CLOCKS_PER_MS=3, 2000 modeled ms require 120 us.
  repeat(14)frame(255);
  if(alarm || meta[197:174]!=1)begin errors=errors+1;$display("FAIL static quiet release");end
  frame(0);frame(255);frame(0);frame(255);frame(0);
  if(!alarm || meta[197:174]!=2)begin errors=errors+1;$display("FAIL reentry event");end
  if(errors==0)$display("SIMULATION_PASS camera normalized_rgb gray mean diff ROI box event_metadata frames=%0d",frames);
  else $display("SIMULATION_FAIL camera errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("SIMULATION_FAIL camera timeout");$finish;end
endmodule
