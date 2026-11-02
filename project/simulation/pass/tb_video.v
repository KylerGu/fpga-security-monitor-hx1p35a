`timescale 1ns/1ps
module tb_pass_video;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,vs=0,hs=0,de=0,user=0,last=0;reg[23:0]data=0;
 reg[255:0]meta=0;reg[39:0]status={2'd1,2'd1,12'h123,12'h045,12'h078};
 wire ode,rde;wire[23:0]pixel,reference_pixel;
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0),.BRIGHTNESS_ENABLE(1),.FOCUS_ENABLE(1),.PASS_ENABLE(1)) dut(
  .I_focus_switch(1'b1),.I_focus_reset(1'b0),.I_focus_valid(1'b0),.I_focus_data(21'd0),.I_pass_status(status),
  .I_mode(2'd0),.I_security_meta(meta),.I_security_valid(1'b1),.I_clk(clk),.I_rst_n(rstn),
  .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
  .I_debug_status(4'b1111),.I_video_rd_data(data),.O_hdmi_de(ode),.O_hdmi_data(pixel));
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0),.BRIGHTNESS_ENABLE(1),.FOCUS_ENABLE(1)) reference(
  .I_focus_switch(1'b1),.I_focus_reset(1'b0),.I_focus_valid(1'b0),.I_focus_data(21'd0),
  .I_mode(2'd0),.I_security_meta(meta),.I_security_valid(1'b1),.I_clk(clk),.I_rst_n(rstn),
  .I_video_vsync(vs),.I_video_hsync(hs),.I_video_de(de),.I_video_user(user),.I_video_last(last),
  .I_debug_status(4'b1111),.I_video_rd_data(data),.O_hdmi_de(rde),.O_hdmi_data(reference_pixel));
 function[34:0]font;input[7:0]c;begin case(c)
  "P":font=35'b11110100011000111110100001000010000;
  "A":font=35'b01110100011000111111100011000110001;
  "S":font=35'b01111100001000001110000010000111110;
  "L":font=35'b10000100001000010000100001000011111;
  "R":font=35'b11110100011000111110101001001010001;
  "T":font=35'b11111001000010000100001000010000100;
  "I":font=35'b01110001000010000100001000010001110;
  "D":font=35'b11110100011000110001100011000111110;
  "E":font=35'b11111100001000011110100001000011111;
  ">":font=35'b10000010000010000010001000100010000;
  "0":font=35'b01110100011001110101110011000101110;
  "1":font=35'b00100011000010000100001000010001110;
  "2":font=35'b01110100010000100010001000100011111;
  "3":font=35'b11110000010000101110000010000111110;
  "4":font=35'b00010001100101010010111110001000010;
  "5":font=35'b11111100001111000001000011000101110;
  "7":font=35'b11111000010001000100010000100001000;
  "8":font=35'b01110100011000101110100011000101110;
  "9":font=35'b01110100011000101111000010001001100;
  default:font=0;
 endcase end endfunction
 integer x,y,px,py,n=0,phase,errors=0,protected_pixels=0,pass_pixels=0,fd;
 reg mask,text1,text2,centre,band,focus,priority_hit,label_area;reg[23:0]expected;
 reg[191:0]line1;reg[119:0]line2;reg[7:0]ch;reg[34:0]bits;integer col,row;
 task tick;begin
  @(negedge clk);de=x<1280 && y<720;user=x==0&&y==0;last=x==1279&&y<720;
  vs=y>=725&&y<730;hs=x>=1390&&x<1430;data={8'h30,x[7:0],y[7:0]};
  // The new state arrives mid-picture; every glyph must wait for the next one.
  if(phase==0 && y==100 && x==800)status={2'd1,2'd2,12'h124,12'h045,12'h079};
  if(phase==3 && y==100 && x==800)meta[17]=0; // scene switch waits until next frame
  @(posedge clk);#1;
  if(ode!==rde)begin errors=errors+1;$display("FAIL enable mismatch");end
  if(ode)begin
   px=n%1280;py=n/1280;
   label_area=phase!=2 && px>=16&&px<152&&py>=184&&py<208;
   text1=phase!=2 && px>=700&&px<1084&&py>=96&&py<112;
   text2=phase!=2 && px>=700&&px<940&&py>=120&&py<136;
   centre=phase!=2 && px>=639&&px<=640&&py>=144&&py<696;
   band=phase!=2 && (px==616||px==664)&&py>=144&&py<696&&(py%16<8);
   focus=reference.g_focus.u_focus.show &&
    ((px>=512&&px<768&&py>=232&&py<488&&(px<514||px>=766||py<234||py>=486)) ||
     (px>=512&&px<720&&py>=504&&py<520));
   priority_hit=focus ||
    (px>=600&&px<688&&py>=256&&py<320&&(px<602||px>=686||py<258||py>=318));
   expected=reference_pixel;
   if(!priority_hit)begin
    if(centre)expected=24'hffe060;
    if(band)expected=24'h408080;
    if(text1||text2)begin
     line1=phase==0 ? "PASS 123 L>R 045 R>L 078" : "PASS 124 L>R 045 R>L 079";
     line2=phase==0 ? "LAST L>R SIDE L" : "LAST R>L SIDE L";
     ch=text1 ? line1>>((23-(px-700)/16)*8) : line2>>((14-(px-700)/16)*8);
     bits=font(ch);col=((px-700)%16)/2;row=(py-(text1?96:120))/2;
     expected=(col<5&&row<7&&bits[34-row*5-col]) ? 24'hffe060 : 24'h102030;
    end
   end
   if(label_area)begin
    case((px-16)/16)0:ch="P";1:ch="A";2:ch="S";3:ch="S";default:ch=" ";endcase
    bits=font(ch);col=((px-16)%16)/2;row=(py-184)/2;
    expected=(col<5&&row<7&&bits[34-row*5-col]) ? 24'hffe060 : 24'h102030;
   end
   if(priority_hit&&(centre||band))protected_pixels=protected_pixels+1;
   if(text1||text2||centre||band)pass_pixels=pass_pixels+1;
   if(pixel!==expected)begin errors=errors+1;if(errors<12)$display("FAIL video phase=%d x=%d y=%d got=%h expected=%h",phase,px,py,pixel,expected);end
   if(phase==3)$fdisplay(fd,"%06h",pixel);
   n=n+1;
  end
 end endtask
 initial begin
  meta[207:206]=0;meta[17]=1;meta[205]=1;meta[197:174]=24'h000042;
  meta[173:166]=40;meta[165:158]=22;meta[157:150]=80;meta[149:142]=45;
  meta[62]=1;meta[61]=1;meta[60:53]=75;meta[52:45]=85;meta[44:38]=32;meta[37:31]=39;
  meta[30:24]=87;meta[22:21]=2;meta[74:67]=8'h60;meta[66:63]=1;meta[80:75]=40;
  fd=$fopen("actual.hex","w");
  repeat(5)@(negedge clk);rstn=1;
  for(phase=0;phase<4;phase=phase+1)begin
   meta[17]=phase!=2;n=0;for(y=0;y<750;y=y+1)for(x=0;x<1650;x=x+1)tick;
   if(n!=921600)begin errors=errors+1;$display("FAIL frame length %d",n);end
  end
  $fclose(fd);
  if(protected_pixels==0||pass_pixels==0)errors=errors+1;
  if(errors==0)$display("SIMULATION_PASS pass_video full_frame 4x720p exact_glyphs snapshot_midframe original_pixels RAW_full_frame_equal scene_label focus_color_priority protected=%d",protected_pixels);
  else $display("SIMULATION_FAIL pass_video errors=%d",errors);
  $finish;
 end
endmodule
