`timescale 1ns/1ps
// Two real mixers on the same 720P raster: one descriptor carries a red target,
// the reference one does not. Every pixel outside the target box ring and the
// status line must be identical; inside, only the expected colours may appear.
module tb_color_render;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,vs=0,hs=0,de=0,user=0,last=0;reg[23:0]data=0;
 reg[255:0]meta=0,ref_meta=0;
 wire ovs,ohs,ode,rd,rvs,rhs,rde,rrd;wire[23:0]pixel,ref_pixel;
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0)) dut(.I_mode(2'd2),.I_security_meta(meta),.I_security_valid(1'b1),
  .I_clk(clk),.I_rst_n(rstn),.I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),
  .I_video_last(last),.I_debug_status(4'b1111),.O_video_rd_en(rd),.I_video_rd_data(data),
  .O_hdmi_vsync(ovs),.O_hdmi_hsync(ohs),.O_hdmi_de(ode),.O_hdmi_data(pixel));
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0)) reference(.I_mode(2'd2),.I_security_meta(ref_meta),.I_security_valid(1'b1),
  .I_clk(clk),.I_rst_n(rstn),.I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),
  .I_video_last(last),.I_debug_status(4'b1111),.O_video_rd_en(rrd),.I_video_rd_data(data),
  .O_hdmi_vsync(rvs),.O_hdmi_hsync(rhs),.O_hdmi_de(rde),.O_hdmi_data(ref_pixel));
 localparam[23:0]BOX=24'hff40ff,TEXT_FOUND=24'hff6060,TEXT_NONE=24'hb0b0b0,BACK=24'h102030;
 integer x,y,px,py,pixels=0,errors=0,box_pixels=0,text_pixels=0,back_pixels=0,phase=0;
 reg ring,text,perf;integer perf_pixels=0;
 task tick;input integer xx,yy;begin
  @(negedge clk);de=xx<1280 && yy<720;user=xx==0&&yy==0;last=xx==1279&&yy<720;
  vs=yy>=725&&yy<730;hs=xx>=1390&&xx<1430;data={8'h30,xx[7:0],yy[7:0]};
  @(posedge clk);#1;
  if(ode!==rde)begin errors=errors+1;$display("FAIL color render enable mismatch");end
  if(ode)begin
   px=pixels%1280;py=pixels/1280;
   ring=phase==0 && px>=160&&px<240&&py>=480&&py<600&&(px<162||px>=238||py<482||py>=598);
   text=phase!=2 && px>=700&&px<1036&&py>=48&&py<64;
   perf=phase!=2 && px>=700&&px<1020&&py>=72&&py<88;
   if(ring)begin
    box_pixels=box_pixels+1;
    if(pixel!==BOX)begin errors=errors+1;if(errors<10)$display("FAIL ring x=%0d y=%0d %h",px,py,pixel);end
   end else if(text)begin
    if(pixel===BACK)back_pixels=back_pixels+1;
    else if(pixel===(phase==0 ? TEXT_FOUND : TEXT_NONE))text_pixels=text_pixels+1;
    else begin errors=errors+1;if(errors<10)$display("FAIL text x=%0d y=%0d %h",px,py,pixel);end
   end else if(perf)begin
    if(pixel===24'h60e0ff)perf_pixels=perf_pixels+1;
    else if(pixel!==BACK)begin errors=errors+1;if(errors<10)$display("FAIL perf x=%0d y=%0d %h",px,py,pixel);end
   end else if(pixel!==ref_pixel)begin
    errors=errors+1;if(errors<10)$display("FAIL changed x=%0d y=%0d %h ref=%h",px,py,pixel,ref_pixel);
   end
   // 'R' column 0 row 0 is lit; column 4 row 0 of 'R' is dark.
   if(phase!=2&&px==700&&py==48&&pixel!==(phase==0 ? TEXT_FOUND : TEXT_NONE))begin errors=errors+1;$display("FAIL glyph R lit");end
   if(phase!=2&&px==708&&py==48&&pixel!==BACK)begin errors=errors+1;$display("FAIL glyph R dark");end
   // Sensitivity 'S' (char 19): row 0 column 1 lit, column 0 dark.
   if(phase!=2&&px==1006&&py==48&&pixel!==(phase==0 ? TEXT_FOUND : TEXT_NONE))begin errors=errors+1;$display("FAIL glyph S lit");end
   if(phase!=2&&px==1004&&py==48&&pixel!==BACK)begin errors=errors+1;$display("FAIL glyph S dark");end
   // FPS 30 LAT 1F: 'F' (0,0) lit; '3' at char 4 row0 col0 lit; 'L' char 7 row6 col4 lit;
   // '1' at char 11 row0: col2 lit, col0 dark.
   if(phase!=2&&((px==700&&py==72)||(px==764&&py==72)||(px==820&&py==84)||(px==880&&py==72))&&pixel!==24'h60e0ff)begin errors=errors+1;$display("FAIL perf glyph x=%0d y=%0d",px,py);end
   if(phase!=2&&px==876&&py==72&&pixel!==BACK)begin errors=errors+1;$display("FAIL perf glyph dark");end
   // AE 288: 'A' (char 14) row0 col0 dark / col1 lit; '2' (char 17) row0 col1 lit; '8' (char 19) row3 col0 dark.
   if(phase!=2&&((px==926&&py==72)||(px==974&&py==72))&&pixel!==24'h60e0ff)begin errors=errors+1;$display("FAIL ae glyph x=%0d",px);end
   if(phase!=2&&((px==924&&py==72)||(px==1004&&py==78))&&pixel!==BACK)begin errors=errors+1;$display("FAIL ae glyph dark x=%0d",px);end
   pixels=pixels+1;
  end
 end endtask
 initial begin
  // Same scene as the baseline render test (MOTION, ALARM, ROI, motion box, CNT 42).
  ref_meta[255:224]=42;ref_meta[207:206]=2;ref_meta[205]=1;ref_meta[204]=1;ref_meta[203]=1;ref_meta[202]=1;
  ref_meta[197:174]=24'h000042;
  ref_meta[173:166]=40;ref_meta[165:158]=22;ref_meta[157:150]=80;ref_meta[149:142]=45;
  ref_meta[141:134]=50;ref_meta[133:126]=30;ref_meta[125:118]=59;ref_meta[117:110]=39;
  // Red target: blocks x 20..29, y 60..74 -> pixels 160..239 x 480..599, centre 200,540, 37 blocks.
  meta=ref_meta;meta[74:67]=8'h30;meta[66:63]=1;meta[81]=1;meta[80:75]=6'd36;meta[20:18]=0;  // AE 288
  meta[62]=1;meta[61]=1;meta[60:53]=20;meta[52:45]=29;meta[44:38]=60;meta[37:31]=74;meta[30:24]=37;
  repeat(5)@(negedge clk);rstn=1;
  for(y=0;y<750;y=y+1)for(x=0;x<1650;x=x+1)tick(x,y);
  if(dut.u_color_overlay.xd!==16'h0200 || dut.u_color_overlay.yd!==16'h0540 || dut.u_color_overlay.nd!==16'h0037)begin
   errors=errors+1;$display("FAIL decimal x=%h y=%h n=%h",dut.u_color_overlay.xd,dut.u_color_overlay.yd,dut.u_color_overlay.nd);end
  if(pixels!=921600 || box_pixels!=(2*80*2+2*116*2) || text_pixels==0 || back_pixels==0 || perf_pixels==0)begin
   errors=errors+1;$display("FAIL counts pixels=%0d ring=%0d text=%0d back=%0d",pixels,box_pixels,text_pixels,back_pixels);end
  // Second picture: target not found (box hidden, NONE text, count still shown).
  phase=1;pixels=0;meta[61]=0;meta[30:24]=3;
  for(y=0;y<750;y=y+1)for(x=0;x<1650;x=x+1)tick(x,y);
  if(dut.u_color_overlay.nd!==16'h0003)begin errors=errors+1;$display("FAIL decimal n=%h",dut.u_color_overlay.nd);end
  // Third picture: descriptor not complete -> mixer output identical to reference everywhere.
  phase=2;pixels=0;meta[62]=0;meta[61]=1;meta[74:63]=0;   // fps 0 hides the perf line too
  for(y=0;y<750;y=y+1)for(x=0;x<1650;x=x+1)tick(x,y);
  if(errors==0)$display("SIMULATION_PASS color_render ring=%0d found_none_hidden reference_identical decimal_200_540_37 perf_line ae_288",box_pixels);
  else $display("SIMULATION_FAIL color_render errors=%0d",errors);
  $finish;
 end
endmodule
