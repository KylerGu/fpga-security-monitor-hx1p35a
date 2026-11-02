// Wall-clock alarm state: production clk is the board's continuous 50 MHz crystal.
module security_alarm #(parameter CLOCKS_PER_MS=50000,CONFIRM_FRAMES=5,QUIET_MS=2000)(
 input wire clk,rst_n,armed,setting,clear_toggle,
 input wire frame_valid,motion,detector_valid,
 output reg alarm,output reg[23:0]event_bcd,output wire interrupted
);
 reg[16:0]ms_div;reg[11:0]quiet_ms;reg[9:0]watchdog;
 reg[7:0]confirm;reg last_motion,clear_seen;
 wire tick=ms_div==CLOCKS_PER_MS-1;
 assign interrupted=watchdog>=500;
 wire[7:0]fresh_confirm=interrupted ? 8'd0 : confirm;
 function[23:0]increment;input[23:0]v;integer k;reg carry;reg[23:0]n;
 begin n=v;carry=1;
  if(v!=24'h999999)for(k=0;k<6;k=k+1)if(carry)begin
   if(v[k*4+:4]==9)n[k*4+:4]=0;
   else begin n[k*4+:4]=v[k*4+:4]+1'b1;carry=0;end
  end
  increment=n;
 end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin ms_div<=0;quiet_ms<=0;watchdog<=500;confirm<=0;last_motion<=0;
   clear_seen<=0;alarm<=0;event_bcd<=0;end
  else begin
   if(tick)ms_div<=0;else ms_div<=ms_div+1'b1;
   if(tick && watchdog<500)watchdog<=watchdog+1'b1;
   if(frame_valid)watchdog<=0;
   clear_seen<=clear_toggle;
   if(clear_seen!=clear_toggle)event_bcd<=0;
   if(!armed || setting)begin alarm<=0;confirm<=0;quiet_ms<=0;last_motion<=0;end
   else begin
    // A gap of 500 real milliseconds breaks consecutive-frame confirmation.
    // Existing alarms stay latched; the first fresh motion frame starts at one.
    if(interrupted)confirm<=0;
    if(frame_valid)begin
     if(detector_valid)begin
      last_motion<=motion;
      if(motion)begin
       quiet_ms<=0;
       if(!alarm)begin
        if(fresh_confirm==CONFIRM_FRAMES-1)begin
         alarm<=1;confirm<=0;
         if(clear_seen==clear_toggle)event_bcd<=increment(event_bcd);
        end else confirm<=fresh_confirm+1'b1;
       end
      end else confirm<=0;
     end else begin confirm<=0;last_motion<=0;end
    end
    if(alarm && tick && !last_motion && !interrupted && !(frame_valid && motion && detector_valid))begin
     if(quiet_ms==QUIET_MS-1)begin alarm<=0;quiet_ms<=0;end
     else quiet_ms<=quiet_ms+1'b1;
    end
   end
  end
 end
endmodule

// One complete-frame decision crosses to the crystal domain; its alarm/count
// snapshot returns before that frame descriptor is published. Only one round trip
// is allowed in flight, so delayed replies cannot be attached to a newer frame.
// The crystal-domain timer and live alarm keep running while cam_clk is stopped.
module security_alarm_bridge #(parameter CLOCKS_PER_MS=50000,CONFIRM_FRAMES=5,QUIET_MS=2000)(
 input wire cam_clk,cam_rst_n,ref_clk,ref_rst_n,
 input wire armed,setting,clear_toggle,
 input wire frame_valid,motion,detector_valid,
 output wire frame_ready,reply_valid,output wire[26:0]reply_data,
 output wire alarm,interrupted
);
 wire reset_n=cam_rst_n && ref_rst_n;
 wire request_ready,ref_frame_valid,reply_ready;
 wire[1:0]ref_frame_data;
 wire[23:0]event_bcd;
 reg in_flight,reply_pending;
 wire send=frame_valid && frame_ready;
 assign frame_ready=request_ready && !in_flight && reset_n;
 always @(posedge cam_clk or negedge reset_n)begin
  if(!reset_n)in_flight<=0;
  else begin
   if(send)in_flight<=1;
   if(reply_valid)in_flight<=0;
  end
 end
 security_frame_cdc #(.WIDTH(2)) request(
  cam_clk,ref_clk,reset_n,send,{motion,detector_valid},request_ready,
  1'b1,ref_frame_valid,ref_frame_data);
 security_alarm #(.CLOCKS_PER_MS(CLOCKS_PER_MS),.CONFIRM_FRAMES(CONFIRM_FRAMES),.QUIET_MS(QUIET_MS)) events(
  ref_clk,ref_rst_n,armed,setting,clear_toggle,
  ref_frame_valid,ref_frame_data[1],ref_frame_data[0],alarm,event_bcd,interrupted);
 // Wait one reference edge after the decision so alarm/event_bcd are updated.
 always @(posedge ref_clk or negedge reset_n)begin
  if(!reset_n)reply_pending<=0;
  else if(ref_frame_valid)reply_pending<=1;
  else if(reply_pending && reply_ready)reply_pending<=0;
 end
 security_frame_cdc #(.WIDTH(27)) response(
  ref_clk,cam_clk,reset_n,reply_pending,{armed,alarm,interrupted,event_bcd},reply_ready,
  1'b1,reply_valid,reply_data);
endmodule
