`timescale 1ns/1ps
// Global light change protection through the real motion module.
// 64x64 frame -> 8x8 small image, quadrants of 4x4; default quadrant
// threshold (4*4)*2/5 = 6 moving pixels; LIGHT_HOLD overridden to 3.
// Covers: full-frame flicker never alarms, hold frames suppress real motion
// then counting resumes, a 3-quadrant "near person" still alarms, exact
// quadrant threshold (5 vs 6), hold countdown and descriptor bit [23].
module tb_light;
 reg clk=0;always #4.830 clk=~clk;
 reg rstn=0,fs=0,iv=0,ll=0;reg[95:0]rgb=0;reg[1:0]mode=2;reg arm=1;
 wire[63:0]ctrl={9'b0,16'd7,8'd0,8'd0,8'd8,8'd8,2'd0,1'b0,arm,1'b0,2'b0};
 wire[31:0]fid;wire rv,alarm,armed,interrupt;wire[255:0]meta;
 security_camera_motion #(.WIDTH(64),.HEIGHT(64),.CLOCKS_PER_MS(3),.LIGHT_HOLD(3))
   dut(clk,rstn,fs,iv,ll,rgb,mode,ctrl,fid,rv,meta,alarm,armed,interrupt,clk,rstn,ctrl);
 integer errors=0,results=0,starts=0;
 integer exp_light[1:64],exp_alarm[1:64];
 // Scenes: 0 base, 1 full bright, 2 top-left quadrant object,
 // 3 three quadrants (all but bottom-right), 4 quadrants 6/6/6/5, 5 quadrants 6/6/6/6.
 function[7:0]level;input integer s,px,py;integer sx,sy,q,li;begin
  sx=px/8;sy=py/8;q=(sy>=4)*2+(sx>=4);li=(sy%4)*4+(sx%4);level=8'h40;
  case(s)
   1:level=8'ha0;
   2:if(q==0)level=8'ha0;
   3:if(q!=3)level=8'ha0;
   4:if(li<(q==3 ? 5 : 6))level=8'ha0;
   5:if(li<6)level=8'ha0;
  endcase
 end endfunction
 function[23:0]pixel;input integer s,px,py;reg[7:0]v;begin v=level(s,px,py);pixel={v,v,v};end endfunction
 always @(posedge clk)begin #1;if(rv)begin
  results=results+1;
  if(meta[255:224]!=results)begin errors=errors+1;$display("FAIL light id=%0d result=%0d",meta[255:224],results);end
  if(exp_light[results]>=0 && meta[23]!==exp_light[results][0])begin
   errors=errors+1;$display("FAIL light frame=%0d light=%b expected=%0d all=%0d",results,meta[23],exp_light[results],meta[95:82]);end
  if(exp_alarm[results]>=0 && meta[202]!==exp_alarm[results][0])begin
   errors=errors+1;$display("FAIL light frame=%0d alarm=%b expected=%0d",results,meta[202],exp_alarm[results]);end
  if(meta[22:0]!==0)begin errors=errors+1;$display("FAIL light frame=%0d low descriptor bits=%h",results,meta[22:0]);end
 end end
 task frame;input integer s,l,a;integer w,px,py;begin
  starts=starts+1;exp_light[starts]=l;exp_alarm[starts]=a;
  @(negedge clk);fs=1;iv=0;@(negedge clk);fs=0;
  for(w=0;w<1024;w=w+1)begin
   px=(w%16)*4;py=w/16;
   @(negedge clk);iv=1;ll=(w%16==15);
   rgb={pixel(s,px,py),pixel(s,px+1,py),pixel(s,px+2,py),pixel(s,px+3,py)};
  end
  @(negedge clk);iv=0;ll=0;repeat(64)@(negedge clk);
 end endtask
 integer i;
 initial begin
  repeat(6)@(negedge clk);rstn=1;
  frame(0,-1,-1);frame(0,0,0);frame(0,0,0);                 // 1-3 warm-up
  for(i=0;i<4;i=i+1)begin frame(1,1,0);frame(0,1,0);end     // 4-11 full flicker: no alarm
  frame(2,1,0);frame(0,1,0);frame(2,1,0);                   // 12-14 hold 3,2,1 suppresses real motion
  frame(0,0,0);frame(2,0,0);frame(0,0,0);frame(2,0,0);      // 15-18 counted 1..4
  frame(0,0,1);                                             // 19 fifth counted frame alarms
  arm=0;frame(0,0,0);arm=1;                                 // 20 clear by disarm
  frame(3,0,0);frame(0,0,0);frame(3,0,0);frame(0,0,0);      // 21-24 near person: 3 quadrants
  frame(3,0,1);                                             // 25 still alarms
  arm=0;frame(0,0,0);                                       // 26
  frame(4,0,0);frame(0,0,0);                                // 27-28 one quadrant at 5: not light
  frame(5,1,0);frame(0,1,0);                                // 29-30 all quadrants at 6: light
  frame(0,1,0);frame(0,1,0);frame(0,1,0);frame(0,0,0);      // 31-34 hold 3,2,1 then clear
  if(results!=starts)begin errors=errors+1;$display("FAIL light results=%0d frames=%0d",results,starts);end
  if(errors==0)$display("SIMULATION_PASS light_guard flicker_no_alarm hold_then_count near_person_alarms quadrant_threshold results=%0d",results);
  else $display("SIMULATION_FAIL light_guard errors=%0d",errors);
  $finish;
 end
 initial begin #3000000;$display("SIMULATION_FAIL light_guard timeout");$finish;end
endmodule
