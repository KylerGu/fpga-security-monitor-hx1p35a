`timescale 1ns/1ps
// Auto exposure: controller on a 16-pixel "small image" (target 110, dead band +-12,
// far band +-40, one decision every 4 complete frames) and the 24 MHz writer mapping
// and request handshake.
module tb_ae;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,en=1,start=0,valid=0,last=0,abort=0;reg[7:0]gray=0;
 wire[8:0]level;
 security_auto_exposure #(.PIXELS(16)) dut(clk,rstn,en,start,valid,last,abort,gray,level);
 reg wrst=1,cfg=0,aecfg=0;reg[8:0]wl=0;wire req;wire[15:0]ae,ag;
 security_ae_writer writer(clk,wrst,cfg,aecfg,wl,req,ae,ag);
 integer errors=0,i,f,g;
 task frame;input[7:0]v;input integer n;input integer broken;begin
  @(negedge clk);start=1;@(negedge clk);start=0;
  for(i=0;i<n;i=i+1)begin
   @(negedge clk);valid=1;gray=v;last=(i==n-1);abort=(broken!=0 && i==5);
   @(negedge clk);valid=0;last=0;abort=0;
  end
  repeat(3)@(negedge clk);
 end endtask
 task frames;input[7:0]v;input integer k;begin for(f=0;f<k;f=f+1)frame(v,16,0);end endtask
 task expect_level;input integer l;begin
  if(level!==l)begin errors=errors+1;$display("FAIL ae level=%0d expected=%0d",level,l);end
 end endtask
 task map;input integer l,e,g;begin
  wl=l;#1;
  if(writer.map_ae!==e || writer.map_ag!==g)begin errors=errors+1;$display("FAIL map T=%0d ae=%0d ag=%0d expected %0d %0d",l,writer.map_ae,writer.map_ag,e,g);end
 end endtask
 initial begin
  repeat(3)@(negedge clk);rstn=1;
  expect_level(320);                      // reset = former fixed setting
  frames(8'd50,3);expect_level(320);      // dark, but only 3 frames: no decision yet
  frames(8'd50,1);expect_level(324);      // 4th frame: far below (<70) -> +4
  frames(8'd90,4);expect_level(325);      // 90 < 98: +1
  frames(8'd98,4);expect_level(325);      // dead band edge (98 = 110-12): hold
  frames(8'd122,4);expect_level(325);     // 122 = 110+12: hold
  frames(8'd123,4);expect_level(324);     // just above: -1
  frames(8'd200,4);expect_level(320);     // far above (>150): -4
  frame(8'd200,16,1);frame(8'd200,16,1);frame(8'd200,16,1);frame(8'd200,16,1);
  expect_level(320);                      // aborted frames never count
  frame(8'd200,15,0);frame(8'd200,15,0);frame(8'd200,15,0);frame(8'd200,15,0);
  expect_level(320);                      // short frames never count
  for(g=0;g<90;g=g+1)frames(8'd250,4);
  expect_level(0);                        // clamps at 0
  for(g=0;g<100;g=g+1)frames(8'd0,4);
  expect_level(352);                      // clamps at 352
  en=0;@(negedge clk);@(negedge clk);expect_level(320);   // SW2 down: fixed
  frames(8'd0,8);expect_level(320);
  // Writer mapping
  map(0,32,16);map(31,63,16);map(32,64,16);map(100,(32+4)<<3,16);
  map(160,1024,16);map(191,1991,16);map(192,1991,16);map(320,1991,144);map(352,1991,176);map(400,1991,176);
  // Request handshake: nothing before the sensor is configured, one request per change.
  wl=320;@(negedge clk);wrst=0;repeat(4)@(negedge clk);
  if(req!==0)begin errors=errors+1;$display("FAIL request before cfg_done");end
  cfg=1;aecfg=1;@(posedge req);@(negedge clk);
  if(ae!==1991 || ag!==144)begin errors=errors+1;$display("FAIL first write %0d %0d",ae,ag);end
  repeat(5)@(negedge clk);if(req!==0)begin errors=errors+1;$display("FAIL repeated request");end
  aecfg=0;wl=100;repeat(5)@(negedge clk);
  if(req!==0 || ae!==1991)begin errors=errors+1;$display("FAIL request while AE table busy");end
  aecfg=1;@(posedge req);@(negedge clk);
  if(ae!==288 || ag!==16)begin errors=errors+1;$display("FAIL second write %0d %0d",ae,ag);end
  if(errors==0)$display("SIMULATION_PASS ae_control far_near_deadband interval abort clamp fixed writer_map handshake");
  else $display("SIMULATION_FAIL ae_control errors=%0d",errors);
  $finish;
 end
 initial begin #20000000;$display("SIMULATION_FAIL ae_control timeout");$finish;end
endmodule
