`timescale 1ns/1ps
// Focused scene-change regression. This is not a complete video-frame test.
// Real controls feed the real 64x64 camera descriptor path. Mixer probes force
// only raster coordinates to keep this check short; data/overlay pipelines run.
module tb_pass_scene;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,setup=0,aesw=0;reg[2:0]keys=3'b111;
 wire[1:0]mode;wire[63:0]ctrl;
 security_controls #(.DEBOUNCE(3),.LONG_PRESS(25),.CLOCKS_PER_SEC(500000)) controls(
  clk,rstn,keys,setup,mode,ctrl,aesw);
 reg fs=0,iv=0,ll=0;reg[95:0]rgb={4{24'h707070}};
 wire[31:0]fid;wire rv,alarm,armed,stale;wire[255:0]meta;
 security_camera_motion #(.WIDTH(64),.HEIGHT(64),.CLOCKS_PER_MS(100)) camera(
  clk,rstn,fs,iv,ll,rgb,mode,ctrl,fid,rv,meta,alarm,armed,stale,clk,rstn,ctrl);
 integer errors=0,results=0,frames=0,probes=0;
 reg[255:0]last_meta=0;
 always @(posedge clk)begin #1;if(rv)begin results=results+1;last_meta=meta;end end
 task key;input integer n,cycles;begin
  @(negedge clk);keys[n]=0;repeat(cycles)@(negedge clk);
  keys[n]=1;repeat(10)@(negedge clk);
 end endtask
 task control_check;input[1:0]m;input pv;input[1:0]sens;begin
  if(mode!==m || ctrl[59]!==pv || ctrl[56:55]!==sens)begin
   errors=errors+1;$display("FAIL scene control mode=%d/%d pass=%b/%b sens=%d/%d",mode,m,ctrl[59],pv,ctrl[56:55],sens);
  end
 end endtask
 task frame;input[1:0]m;input pv,setting;integer w,before_results;begin
  before_results=results;frames=frames+1;
  @(negedge clk);fs=1;iv=0;@(negedge clk);fs=0;
  for(w=0;w<1024;w=w+1)begin
   @(negedge clk);iv=1;ll=w%16==15;rgb={4{24'h707070}};
  end
  @(negedge clk);iv=0;ll=0;repeat(128)@(negedge clk);
  if(results!=before_results+1 || last_meta[207:206]!==m || last_meta[17]!==pv || last_meta[201]!==setting)begin
   errors=errors+1;$display("FAIL scene descriptor frame=%d results=%d/%d mode=%d/%d pass=%b/%b setup=%b/%b",
    frames,results,before_results+1,last_meta[207:206],m,last_meta[17],pv,last_meta[201],setting);
  end
 end endtask

 reg video_user=0,video_de=0,display_valid=1;reg[1:0]display_mode=0;
 reg[255:0]display_meta=0;
 reg[11:0]probe_x=0,probe_y=0;
 reg[39:0]pass_status={2'd1,2'd1,12'h003,12'h002,12'h001};
 wire de_new,de_ref;wire[23:0]pixel_new,pixel_ref;
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0),.BRIGHTNESS_ENABLE(1),.FOCUS_ENABLE(1),.PASS_ENABLE(1)) dut(
  .I_focus_switch(1'b0),.I_focus_reset(1'b0),.I_focus_valid(1'b0),.I_focus_data(21'd0),.I_pass_status(pass_status),
  .I_mode(display_mode),.I_security_meta(display_meta),.I_security_valid(display_valid),.I_clk(clk),.I_rst_n(rstn),
  .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(video_de),.I_video_user(video_user),.I_video_last(1'b0),
  .I_debug_status(4'b1111),.O_video_rd_en(),.I_video_rd_data(24'h305070),
  .O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(de_new),.O_hdmi_data(pixel_new));
 hdmi_mixer #(.H_OFFSET(0),.V_OFFSET(0),.BRIGHTNESS_ENABLE(1),.FOCUS_ENABLE(1),.PASS_ENABLE(0)) reference(
  .I_focus_switch(1'b0),.I_focus_reset(1'b0),.I_focus_valid(1'b0),.I_focus_data(21'd0),.I_pass_status(pass_status),
  .I_mode(display_mode),.I_security_meta(display_meta),.I_security_valid(display_valid),.I_clk(clk),.I_rst_n(rstn),
  .I_video_vsync(1'b0),.I_video_hsync(1'b0),.I_video_de(video_de),.I_video_user(video_user),.I_video_last(1'b0),
  .I_debug_status(4'b1111),.O_video_rd_en(),.I_video_rd_data(24'h305070),
  .O_hdmi_vsync(),.O_hdmi_hsync(),.O_hdmi_de(de_ref),.O_hdmi_data(pixel_ref));
 task boundary;input active;begin
  @(negedge clk);probe_x=0;probe_y=0;video_user=1;video_de=active;
  @(negedge clk);video_user=0;video_de=1;repeat(8)@(negedge clk);
 end endtask
 task gate_check;input expected;begin
  if(dut.pass_show!==expected)begin errors=errors+1;$display("FAIL scene frame gate got=%b expected=%b",dut.pass_show,expected);end
 end endtask
 // kind 0: exactly the no-PASS mixer; kind 1: yellow PASS/line foreground;
 // kind 2: PASS label's fourth character ink must replace RAW's blank cell.
 task probe;input[11:0]x,y;input integer kind;begin
  @(negedge clk);probe_x=x;probe_y=y;video_de=1;
  repeat(10)@(negedge clk);probes=probes+1;
  if(de_new!==1 || de_ref!==1 ||
     (kind==0 && pixel_new!==pixel_ref) ||
     (kind==1 && pixel_new!==24'hffe060) ||
     (kind==2 && (pixel_new===pixel_ref || pixel_new===24'h101820 || pixel_new===24'h102030)))begin
   errors=errors+1;$display("FAIL scene pixel x=%d y=%d kind=%d new=%h reference=%h",x,y,kind,pixel_new,pixel_ref);
  end
 end endtask
 task hidden_probes;begin
  probe(640,160,0);probe(616,160,0);probe(664,160,0);
  probe(700,96,0);probe(700,120,0);probe(66,184,0);probe(1100,600,0);
 end endtask

 initial begin
  force dut.S_x=probe_x;force dut.S_y=probe_y;
  force reference.S_x=probe_x;force reference.S_y=probe_y;
  repeat(6)@(negedge clk);rstn=1;repeat(10)@(negedge clk);
  control_check(0,0,2);frame(0,0,0);
  key(0,9);control_check(3,0,2);frame(3,0,0);
  key(0,9);control_check(1,0,2);frame(1,0,0);
  key(0,9);control_check(2,0,2);frame(2,0,0);
  key(0,9);control_check(0,1,2);frame(0,1,0);
  // A held KEY2 advances only once and PASS wraps to ordinary RAW.
  key(0,40);control_check(0,0,2);frame(0,0,0);
  repeat(4)key(0,9);control_check(0,1,2);
  // PASS is a distinct UI scene although its ISP encoding is RAW: KEY3 must
  // leave it without accidentally changing colour sensitivity.
  key(1,9);control_check(0,0,2);
  key(1,9);control_check(0,0,3);
  repeat(3)key(0,9);control_check(2,0,3);
  // Scene request changes after camera frame-start: descriptor must retain
  // the earlier mode/scene together for that entire frame.
  fork
   frame(2,0,0);
   begin repeat(100)@(negedge clk);key(0,9);end
  join
  control_check(0,1,3);frame(0,1,0);
  setup=1;repeat(10)@(negedge clk);control_check(0,1,3);
  if(ctrl[3] || !ctrl[4])begin errors=errors+1;$display("FAIL setup did not disarm");end
  frame(0,1,1);
  key(0,9);control_check(0,1,3);
  if(ctrl[6:5]!=1)begin errors=errors+1;$display("FAIL setup KEY2 must edit item, not scene");end
  key(1,9);control_check(0,1,3);
  key(2,9);control_check(0,1,3);
  setup=0;repeat(10)@(negedge clk);control_check(0,1,3);frame(0,1,0);
  if(ctrl[3] || ctrl[4])begin errors=errors+1;$display("FAIL setup exit state");end

  display_mode=0;display_meta=0;display_valid=1;boundary(1);gate_check(0);hidden_probes;
  display_meta[17]=1;hidden_probes;gate_check(0);
  boundary(0);gate_check(0);hidden_probes; // user pulse in blanking is not SOF
  boundary(1);gate_check(1);probe(640,160,1);probe(700,96,1);probe(66,184,2);
  display_meta[17]=0;probe(640,160,1);gate_check(1); // no mid-picture disappearance
  boundary(1);gate_check(0);hidden_probes;
  display_meta[17]=1;display_valid=0;boundary(1);gate_check(0);hidden_probes;
  display_valid=1;display_meta[201]=1;boundary(1);gate_check(0);hidden_probes;
  display_meta[201]=0;display_mode=3;boundary(1);gate_check(0);hidden_probes;
  display_mode=1;boundary(1);gate_check(0);hidden_probes;
  display_mode=2;boundary(1);gate_check(0);hidden_probes;
  display_mode=0;boundary(1);gate_check(1);probe(640,160,1);
  @(negedge clk);rstn=0;repeat(6)@(negedge clk);gate_check(0);
  rstn=1;repeat(10)@(negedge clk);control_check(0,0,2);
  if(errors==0)$display("SIMULATION_PASS pass_scene controls_cycle key3_no_sensitivity_change setup_preserves_scene descriptor_frame_latch raw_hidden sof_gate probes=%d frames=%d",probes,frames);
  else $display("SIMULATION_FAIL pass_scene errors=%d",errors);
  $finish;
 end
 initial begin #5000000;$display("SIMULATION_FAIL pass_scene timeout");$finish;end
endmodule
