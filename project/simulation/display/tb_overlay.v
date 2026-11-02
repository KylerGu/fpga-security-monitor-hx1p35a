`timescale 1ns/1ps
module tb_overlay;
 reg[11:0]x=0,y=0;reg valid=1;reg[255:0]m=0;
 wire hit;wire[23:0]color;
 security_overlay dut(x,y,valid,m,hit,color);
 integer errors=0;
 task check;input integer xx,yy,h;input[23:0]c;begin
  x=xx;y=yy;#1;
  if(hit!==h[0] || (h && color!==c))begin errors=errors+1;$display("FAIL overlay x=%0d y=%0d hit=%b color=%h",xx,yy,hit,color);end
 end endtask
 initial begin
  m[207:206]=2;m[173:166]=40;m[165:158]=22;m[157:150]=80;m[149:142]=45;
  m[205]=1;m[204]=1;m[141:134]=50;m[133:126]=30;m[125:118]=59;m[117:110]=39;
  check(320,176,1,24'h20ff60);check(959,535,1,24'h20ff60);
  check(322,178,0,0);check(960,536,0,0);
  check(400,240,1,24'hfff000);check(479,319,1,24'hfff000);
  m[202]=1;check(320,176,1,24'hff3030);
  valid=0;check(320,176,0,0);check(400,240,0,0);
  valid=1;m[207:206]=0;check(320,176,0,0);m[201]=1;check(320,176,1,24'hff3030);
  // Status text: light-change bit shows yellow LIGHT (L top-left lit; G row3 col3 lit, row2 col3 dark).
  m[201]=0;m[202]=0;m[203]=1;check(700,24,1,24'h102030);
  m[23]=1;check(700,24,1,24'hffd040);check(738,30,1,24'hffd040);check(738,28,1,24'h102030);
  m[202]=1;check(700,24,1,24'h102030);
  m[202]=0;m[201]=1;check(702,24,1,24'hffffff);   // SET X: S row0 col1 stays white
  if(errors==0)$display("SIMULATION_PASS overlay half_open_ROI inclusive_motion_box mode_valid_alarm light_status");
  else $display("SIMULATION_FAIL overlay errors=%0d",errors);
  $finish;
 end
endmodule
