`timescale 1ns/1ps
module tb_buzzer;
 reg clk=0,cam_clk=0;
 always #10 clk=~clk; // Actual 50 MHz system clock, default 2 kHz tone.
 always #4.83 cam_clk=~cam_clk;
 reg rstn=0,setup=0;
 reg[2:0]keys=3'b111;
 wire rst_sys,rst_cam;
 security_reset_release rs(clk,rstn,rst_sys);
 security_reset_release rc(cam_clk,rstn,rst_cam);
 wire[1:0]mode;wire[63:0]control;
 security_controls #(.DEBOUNCE(3),.LONG_PRESS(100)) controls(clk,rst_sys,keys,setup,mode,control,1'b0);
 reg[63:0]last_sent,camera_control;
 reg sent;wire ready,received;wire[63:0]received_control;
 wire send=ready && (!sent || control!=last_sent);
 always @(posedge clk or negedge rst_sys)
  if(!rst_sys)begin last_sent<=0;sent<=0;end
  else if(send)begin last_sent<=control;sent<=1;end
 security_frame_cdc #(.WIDTH(64)) mailbox(clk,cam_clk,rstn,send,control,ready,1'b1,received,received_control);
 always @(posedge cam_clk or negedge rst_cam)
  if(!rst_cam)camera_control<=0;else if(received)camera_control<=received_control;
 reg fv=0,motion=0,valid=1;
 wire alarm,interrupted,alarm_ready,alarm_reply_valid;wire[26:0]alarm_reply;
 wire[23:0]count=events.event_bcd;
 // Only the wall-clock quiet/watchdog scale is accelerated, confirmation stays 5.
 security_alarm_bridge #(.CLOCKS_PER_MS(5000),.QUIET_MS(7)) events(
  cam_clk,rst_cam,clk,rst_sys,control[3],control[4],control[2],
  fv,motion,valid,alarm_ready,alarm_reply_valid,alarm_reply,alarm,interrupted);
 wire[3:0]led;wire buzzer_n;
 production_buzzer_path dut(clk,rst_sys,1'b0,interrupted,
  camera_control[3]&&!camera_control[4],alarm,control,led,buzzer_n);
 integer errors=0,i,toggles=0;
 time edge_time=0;
 reg tone_test=0;
 always @(buzzer_n)if(tone_test)begin
  if(edge_time!=0 && $time-edge_time!=250000)begin
   errors=errors+1;$display("FAIL tone half period=%0t",$time-edge_time);
  end
  edge_time=$time;toggles=toggles+1;
 end
 task check;input condition;input[639:0]message;
 begin if(!condition)begin errors=errors+1;$display("FAIL %0s",message);end end endtask
 task settle;begin repeat(150)@(negedge clk);end endtask
 task frame;input moving;begin
  wait(alarm_ready);
  @(negedge cam_clk);fv=1;motion=moving;@(negedge cam_clk);fv=0;
  wait(alarm_reply_valid);@(negedge cam_clk);
 end endtask
 task short_key4;begin keys[2]=0;repeat(12)@(negedge clk);keys[2]=1;settle;end endtask
 task trigger;begin repeat(5)frame(1);settle;end endtask
 initial begin
  #1;check(buzzer_n===1'b1,"reset must be silent");
  repeat(5)@(negedge clk);rstn=1;settle;
  check(!alarm && buzzer_n===1'b1 && count==0,"startup disarmed and silent");
  repeat(8)frame(1);settle;check(!alarm && buzzer_n===1'b1,"disarmed movement silent");
  short_key4;check(control[3] && camera_control[3],"armed through actual controls/mailbox");
  repeat(4)frame(1);settle;check(!alarm && buzzer_n===1'b1 && count==0,"first four motion frames silent");
  frame(0);repeat(4)frame(1);settle;check(!alarm && count==0,"confirmation still consecutive");
  frame(1);settle;check(alarm && led[0] && count==1,"fifth consecutive frame alarms once");
  tone_test=1;repeat(100010)@(negedge clk);tone_test=0;
  check(toggles>=8,"alarm produces repeated 2 kHz drive");
  repeat(12)frame(1);settle;check(alarm && count==1,"ongoing alarm not recounted");
  frame(0);repeat(20000)@(negedge cam_clk);check(alarm,"quiet timer does not stop early");
  repeat(60000)@(negedge cam_clk);settle;
  check(!alarm && !led[0] && buzzer_n===1'b1 && count==1,"automatic alarm release stops tone");
  repeat(20000)@(negedge clk);check(buzzer_n===1'b1,"silence maintained past tone periods");
  trigger;repeat(13000)@(negedge clk);check(alarm && buzzer_n===1'b0 && count==2,"retrigger produces sound");
  // Long KEY4 clears the event count but must not mute or disarm a live alarm.
  keys[2]=0;repeat(130)@(negedge clk);keys[2]=1;settle;
  check(control[3] && alarm && count==0,"long clear preserves live alarm and arming");
  short_key4;check(!control[3] && !alarm && buzzer_n===1'b1,"short KEY4 disarms and stops tone");
  repeat(15000)@(negedge clk);check(buzzer_n===1'b1,"disarmed tone does not resume");
  short_key4;trigger;repeat(13000)@(negedge clk);
  check(alarm && count==1,"alarm before setup");
  setup=1;settle;check(!control[3] && !alarm && buzzer_n===1'b1,"setup disarms and silences");
  setup=0;settle;check(!alarm && buzzer_n===1'b1,"leaving setup remains silent");
  short_key4;valid=0;repeat(7)frame(1);settle;
  check(!alarm && buzzer_n===1'b1,"invalid detector cannot start sound");
  valid=1;trigger;repeat(13000)@(negedge clk);check(alarm && buzzer_n===1'b0,"alarm before asynchronous reset");
  #3;rstn=0;#1;check(buzzer_n===1'b1,"reset silences without a clock edge");
  settle;rstn=1;settle;check(!alarm && count==0 && buzzer_n===1'b1,"reset clears and stays silent");
  if(errors==0)$display("SIMULATION_PASS buzzer tone2000 alarm_link quiet_release disarm setup reset clear_retrigger consecutive5 invalid_detector");
  else $display("SIMULATION_FAIL buzzer errors=%0d",errors);
  $finish;
 end
 initial begin #30000000;$display("SIMULATION_FAIL buzzer timeout");$finish;end
endmodule
