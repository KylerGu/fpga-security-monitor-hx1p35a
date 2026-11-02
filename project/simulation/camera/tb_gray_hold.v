`timescale 1ns/1ps
// Compare the production camera path against independent 8x8 pixel averages.
// Nonuniform values, wrapped brightness and input gaps expose stale/misaligned bytes.
module tb_gray_hold;
 reg clk=0;always #4.830 clk=~clk;
 reg rstn=0,fs=0,iv=0,ll=0;reg[95:0]rgb=0;
 wire[31:0]fid;wire rv,alarm,armed,interrupt;wire[255:0]meta;
 security_camera_motion #(.WIDTH(64),.HEIGHT(32),.CLOCKS_PER_MS(1000),.LIGHT_QUAD_MIN(4096))
  dut(clk,rstn,fs,iv,ll,rgb,2'd0,64'd0,fid,rv,meta,alarm,armed,interrupt,clk,rstn,64'd0);
 integer errors=0,frame_index=-1,samples=0,total=0,ec,ep,ed;
 function[7:0]pixel;input integer f,x,y;begin pixel=(f*37+x*3+y*5)%256;end endfunction
 function[95:0]word_rgb;input integer f,x,y;integer lane;begin
  for(lane=0;lane<4;lane=lane+1)word_rgb[95-lane*24 -: 24]={3{pixel(f,x+lane,y)}};
 end endfunction
 function integer average;input integer f,a;integer dx,dy,sum;begin
  sum=0;
  for(dy=0;dy<8;dy=dy+1)for(dx=0;dx<8;dx=dx+1)
   sum=sum+pixel(f,(a%8)*8+dx,(a/8)*8+dy);
  average=sum/64;
 end endfunction
 always @(posedge clk)begin #1;
  if(rstn && dut.dv)begin
   ec=average(frame_index,samples);ep=average(frame_index-1,samples);
   ed=ec>=ep ? ec-ep : ep-ec;
   if(frame_index<1 || samples>=32 || dut.da!==samples[13:0] ||
      dut.cur!==ec[7:0] || dut.prev!==ep[7:0] || dut.difference!==ed[7:0])begin
    errors=errors+1;
    $display("FAIL gray data frame=%0d sample=%0d addr=%0d got=%0d/%0d/%0d expected=%0d/%0d/%0d",
     frame_index,samples,dut.da,dut.cur,dut.prev,dut.difference,ec,ep,ed);
   end
   samples=samples+1;total=total+1;
  end
 end
 task frame;input integer f,gaps;integer w;begin
  frame_index=f;samples=0;
  @(negedge clk);fs=1;iv=0;ll=0;
  @(negedge clk);fs=0;
  for(w=0;w<512;w=w+1)begin
   @(negedge clk);iv=1;ll=w%16==15;rgb=word_rgb(f,(w%16)*4,w/16);
   if(gaps && w%17==5)begin
    @(negedge clk);iv=0;ll=0;repeat(w%3+1)@(negedge clk);
   end
  end
  @(negedge clk);iv=0;ll=0;repeat(30)@(negedge clk);
  if(samples!=(f==0 ? 0 : 32))begin
   errors=errors+1;$display("FAIL gray sample count frame=%0d count=%0d",f,samples);
  end
 end endtask
 initial begin
  repeat(6)@(negedge clk);rstn=1;
  frame(0,0);frame(1,1);frame(2,0);
  if(errors==0 && total==64)$display("SIMULATION_PASS gray_hold nonuniform averages previous difference gaps addresses pixels=64");
  else $display("SIMULATION_FAIL gray_hold errors=%0d pixels=%0d",errors,total);
  $finish;
 end
 initial begin #1000000;$display("SIMULATION_FAIL gray_hold timeout");$finish;end
endmodule
