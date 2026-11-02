`timescale 1ns/1ps
module tb_brightness;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0,user=0,last=0;
 reg[1:0]mode=0;reg[23:0]data=0;reg[255:0]meta=0;
 wire ode,rde,ovs,ohs,rvs,rhs,rd,rrd;wire[23:0]pixel,reference;
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0),.BRIGHTNESS_ENABLE(1)) dut(
 .I_mode(mode),.I_security_meta(meta),.I_security_valid(1'b1),.I_clk(clk),.I_rst_n(rst),
 .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
 .I_debug_status(4'b1111),.O_video_rd_en(rd),.I_video_rd_data(data),.O_hdmi_vsync(ovs),.O_hdmi_hsync(ohs),.O_hdmi_de(ode),.O_hdmi_data(pixel));
 hdmi_mixer_color_reference #(.H_OFFSET(0),.V_OFFSET(0)) old_color(
 .I_mode(mode),.I_security_meta(meta),.I_security_valid(1'b1),.I_clk(clk),.I_rst_n(rst),
 .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
 .I_debug_status(4'b1111),.O_video_rd_en(rrd),.I_video_rd_data(data),.O_hdmi_vsync(rvs),.O_hdmi_hsync(rhs),.O_hdmi_de(rde),.O_hdmi_data(reference));
 integer phase,x,y,px,py,pixels=0,total=0,errors=0,overlay_pixels=0,lifted_pixels=0;
 integer red_edges=0,roi_edges=0,selected_mode,i,previous=-1,current,old_diagnostic_pixels=0;
 reg before_overlay;reg[23:0]expected;
 function[7:0]tone;input[7:0]v;integer n;begin
  n=v;if(n<=16)tone=n;else if(n<64)tone=n+(((n*(255-n)+255)/510)*(n-16)+24)/48;else tone=n+(n*(255-n)+255)/510;
 end endfunction
 task tick;input integer xx,yy;begin
  @(negedge clk);
  de=xx<1280;user=xx==0&&yy==0;last=xx==1279;hs=xx>=1390&&xx<1430;
  data=xx<256 ? {3{xx[7:0]}} : {xx[7:0],yy[7:0],(xx[7:0]^yy[7:0])};
  // A requested mode change mid-frame must not tear either pipeline.
  if(yy==2 && xx==100)mode=selected_mode^2'b11;
  @(posedge clk);
  before_overlay=(old_color.S_video_de_2d &&
    (old_color.security_hit || old_color.color_hit || old_color.mode_label_hit)) || old_color.S_osd_hit;
  #1;
  if({ode,ovs,ohs,rd}!=={rde,rvs,rhs,rrd})begin
   errors=errors+1;if(errors<8)$display("Sync/read changed phase=%0d",phase);
  end
  if(ode)begin
   px=pixels%1280;py=pixels/1280;expected=reference;
   if(before_overlay)overlay_pixels=overlay_pixels+1;
   else if(selected_mode==0 || selected_mode==2)begin
    expected={tone(reference[23:16]),tone(reference[15:8]),tone(reference[7:0])};
    if(expected!=reference)lifted_pixels=lifted_pixels+1;
   end
   // Former test strip and temporary label locations must show normal content.
   if((py>=600&&py<696)||(py>=72&&py<88&&px>=1020&&px<1148)||(py>=96&&py<112&&px>=700&&px<988))
    old_diagnostic_pixels=old_diagnostic_pixels+1;
   if(pixel!==expected)begin
    errors=errors+1;if(errors<12)$display("Pixel mismatch phase=%0d xy=%0d/%0d got=%h expected=%h ref=%h overlay=%b",phase,px,py,pixel,expected,reference,before_overlay);
   end
   if(pixel==24'hff40ff)red_edges=red_edges+1;
   if(selected_mode==2 && pixel==24'hff3030 && py>=40)roi_edges=roi_edges+1;
   pixels=pixels+1;total=total+1;
  end
 end endtask
 initial begin
  // Independent digital transfer bounds and selected anchor values.
  for(i=0;i<256;i=i+1)begin
   current=dut.F_brightness(i[7:0]);
   if(current<i || current>255 || current-i>32 || current<previous)errors=errors+1;
   previous=current;
  end
  if(dut.F_brightness(0)!=0 || dut.F_brightness(255)!=255 || dut.F_brightness(1)!=1 ||
     dut.F_brightness(16)!=16 || dut.F_brightness(32)!=37 || dut.F_brightness(64)!=88 || dut.F_brightness(110)!=141 ||
     dut.F_brightness(128)!=160 || dut.F_brightness(192)!=216)errors=errors+1;
  for(phase=0;phase<6;phase=phase+1)begin
   @(negedge clk);de=0;user=0;last=0;pixels=0;selected_mode=phase<4?phase:0;mode=selected_mode;meta=0;
   meta[207:206]=mode;meta[205]=1;meta[204]=1;meta[203]=1;meta[202]=1;meta[173:166]=40;meta[165:158]=4;meta[157:150]=80;meta[149:142]=6;
   meta[141:134]=35;meta[133:126]=5;meta[125:118]=60;meta[117:110]=7;
   meta[62]=1;meta[61]=1;meta[60:53]=30;meta[52:45]=100;meta[44:38]=3;meta[37:31]=8;meta[30:24]=25;
   meta[74:67]=phase<4?8'h60:0;meta[81]=1;meta[80:75]=6'd40;meta[20:18]=0;
   if(phase==0 || phase==5)begin rst=0;repeat(5)@(negedge clk);rst=1;end
   repeat(8)@(negedge clk);
   user=1;@(negedge clk);user=0;
   for(y=0;y<720;y=y+1)for(x=0;x<1650;x=x+1)tick(x,y);
   if(pixels!=921600)begin errors=errors+1;$display("Raster pixel count %0d",pixels);end
  end
  @(negedge clk);rst=0;#1;
  if(ode!==0)errors=errors+1;
  if(errors || total!=5529600 || overlay_pixels==0 || lifted_pixels==0 || red_edges==0 || roi_edges==0 || old_diagnostic_pixels!=777216)
   $display("SIMULATION_FAIL brightness errors=%0d total=%0d overlay=%0d lifted=%0d red=%0d roi=%0d diagnostics=%0d",errors,total,overlay_pixels,lifted_pixels,red_edges,roi_edges,old_diagnostic_pixels);
  else $display("SIMULATION_PASS brightness fixed_accepted_curve full720p_six_frames no_test_chart_or_labels original_Color_overlays monotone256 mode_frame_boundary reset unchanged_GRAY_EDGE red_alarm_OSD_intact same_sync_latency pixels=5529600");
  $finish;
 end
 initial begin #100000000;$display("SIMULATION_FAIL brightness timeout");$finish;end
endmodule
