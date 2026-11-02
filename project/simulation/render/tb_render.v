`timescale 1ns/1ps
module tb_render;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,vs=0,hs=0,de=0,user=0,last=0;reg[23:0]data=0;
 reg[255:0]meta=0;wire ovs,ohs,ode,rd;wire[23:0]pixel;
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0)) dut(.I_mode(2'd2),.I_security_meta(meta),.I_security_valid(1'b1),
  .I_clk(clk),.I_rst_n(rstn),.I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),
  .I_video_last(last),.I_debug_status(4'b1111),.O_video_rd_en(rd),.I_video_rd_data(data),
  .O_hdmi_vsync(ovs),.O_hdmi_hsync(ohs),.O_hdmi_de(ode),.O_hdmi_data(pixel));
 integer x,y,fd,pixels=0,errors=0;reg[2:0]valid_pipe=0;
 task tick;input integer xx,yy;begin
  @(negedge clk);de=xx<1280 && yy<720;user=xx==0&&yy==0;last=xx==1279&&yy<720;
  vs=yy>=725&&yy<730;hs=xx>=1390&&xx<1430;data={8'h30,xx[7:0],yy[7:0]};
  @(posedge clk);#1;
  if(ode)begin
   $fdisplay(fd,"%06h",pixel);
   // Check rectangle pixels on the actual mixer output, not just its submodule.
   if(pixels==176*1280+320 && pixel!==24'hff3030)begin errors=errors+1;$display("FAIL mixer ROI not routed");end
   if(pixels==240*1280+400 && pixel!==24'hfff000)begin errors=errors+1;$display("FAIL mixer motion box not routed");end
   pixels=pixels+1;
  end
 end endtask
 initial begin
  meta[255:224]=42;meta[207:206]=2;meta[205]=1;meta[204]=1;meta[203]=1;meta[202]=1;meta[197:174]=24'h000042;
  meta[173:166]=40;meta[165:158]=22;meta[157:150]=80;meta[149:142]=45;
  meta[141:134]=50;meta[133:126]=30;meta[125:118]=59;meta[117:110]=39;
  fd=$fopen("actual.hex","w");repeat(5)@(negedge clk);rstn=1;
  for(y=0;y<750;y=y+1)for(x=0;x<1650;x=x+1)tick(x,y);
  repeat(5)tick(1650,750);
  $fclose(fd);
  if(pixels!=921600 || {dut.S_cnt_d5,dut.S_cnt_d4,dut.S_cnt_d3,dut.S_cnt_d2,dut.S_cnt_d1,dut.S_cnt_d0}!==24'h000042)errors=errors+1;
  if(errors==0)$display("SIMULATION_PASS render mixer_real_output pixels=%0d event_bcd42 ROI_motion_status_logo",pixels);
  else $display("SIMULATION_FAIL render errors=%0d pixels=%0d",errors,pixels);
  $finish;
 end
endmodule
