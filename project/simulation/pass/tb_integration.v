`timescale 1ns/1ps
module tb_pass_integration;
 reg cam=0,run_cam=1;always #5 if(run_cam)cam=~cam;
 reg refclk=0;always #10 refclk=~refclk;
 reg hdmi=0;always #7 hdmi=~hdmi;
 reg rstn=0,fs=0,iv=0,ll=0;reg[95:0]rgb=0;
 reg[63:0]ctrl=0;
 wire[31:0]fid;wire rv,alarm,armed,stale;wire[255:0]meta;
 security_camera_motion #(.WIDTH(1280),.HEIGHT(64),.CLOCKS_PER_MS(32)) camera(
  cam,rstn,fs,iv,ll,rgb,2'd0,ctrl,fid,rv,meta,alarm,armed,stale,refclk,rstn,ctrl);
 reg blank=1;wire[39:0]shown;
 security_pass_monitor monitor(cam,refclk,hdmi,rstn,rv,meta,stale,ctrl[4],ctrl[56:55],blank,shown);
 integer errors=0,x,y,results=0;
 always @(posedge cam)if(rv)results=results+1;
 function[23:0]pixel;input integer xx,yy,pos;begin
  pixel=(pos>=0 && xx>=pos && xx<pos+32 && yy>=16 && yy<48) ? 24'hd02020 : 24'h707070;
 end endfunction
 task frame;input integer pos;input broken;begin
  @(negedge cam);fs=1;iv=0;@(negedge cam);fs=0;
  for(y=0;y<64;y=y+1)for(x=0;x<1280;x=x+4)begin
   @(negedge cam);iv=1;ll=(x==1276)^(broken && y==30 && x==100);
   rgb={pixel(x,y,pos),pixel(x+1,y,pos),pixel(x+2,y,pos),pixel(x+3,y,pos)};
  end
  @(negedge cam);iv=0;ll=0;repeat(100)@(negedge cam);
 end endtask
 task check;input[11:0]t,l,r;input[1:0]side,dir;begin
  if(monitor.status!=={side,dir,t,l,r})begin errors=errors+1;$display("FAIL integration frame=%d state %h expected %h",fid,monitor.status,{side,dir,t,l,r});end
  if(blank && shown!==monitor.status)begin errors=errors+1;$display("FAIL display snapshot %h/%h",shown,monitor.status);end
 end endtask
 initial begin
  ctrl[56:55]=2;ctrl[38:31]=1;ctrl[30:23]=1;ctrl[22:15]=158;ctrl[14:7]=6;
  repeat(10)@(negedge cam);rstn=1;repeat(10)@(negedge cam);
  repeat(4)frame(240,0);check(0,0,0,1,0);
  // Red square's centre enters the band, dwells, crosses and stays.
  repeat(3)frame(624,0);check(0,0,0,1,0);
  repeat(3)frame(1000,0);check(1,1,0,2,1);
  repeat(2)frame(1000,0);check(1,1,0,2,1);
  // HDMI stalls: counter must continue and later deliver the cumulative state.
  blank=0;repeat(3)frame(240,0);check(2,1,1,1,2);
  repeat(3)frame(1000,0);check(3,2,1,2,1);
  blank=1;repeat(100)@(negedge cam);check(3,2,1,2,1);
  // Actual detector returns NONE; opposite-side reappearance must not count.
  frame(-1,0);repeat(3)frame(240,0);check(3,2,1,1,1);
  // Bad line length suppresses the camera descriptor; ID gap breaks history.
  // This deliberately accelerated watchdog expires during the two-frame gap;
  // the motion path first rebuilds its reference, then supplies 3 valid frames.
  frame(1000,1);repeat(4)frame(1000,0);check(3,2,1,2,1);
  // Camera clock stops while crystal-domain watchdog and monitor keep running.
  @(negedge cam);run_cam=0;#400000;
  if(!stale || monitor.status[39:38]!=0)begin errors=errors+1;$display("FAIL stopped camera not invalidated");end
  run_cam=1;repeat(20)@(negedge cam);
  repeat(4)frame(240,0);check(3,2,1,1,1);
  // Alarm clear changes no passage count. Setup and sensitivity only disassociate.
  ctrl[2]=1;repeat(20)@(negedge cam);check(3,2,1,1,1);
  ctrl[4]=1;frame(1000,0);ctrl[4]=0;repeat(3)frame(1000,0);check(3,2,1,2,1);
  ctrl[56:55]=3;repeat(3)frame(240,0);check(3,2,1,1,1);
  if(meta[197:174]!=0 || alarm)begin errors=errors+1;$display("FAIL disarmed alarm changed");end
  if(errors==0)$display("SIMULATION_PASS pass_integration real_color real_camera frame_gap clock_stop watchdog cdc_backpressure alarm_independent results=%d",results);
  else $display("SIMULATION_FAIL pass_integration errors=%d",errors);
  $finish;
 end
 initial begin #30000000;$display("SIMULATION_FAIL pass_integration timeout");$finish;end
endmodule
