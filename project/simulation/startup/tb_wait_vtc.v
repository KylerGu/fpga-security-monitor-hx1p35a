`timescale 1ns/1ps
module tb_wait_vtc;
 reg ddr=0,hdmi=0,rstn=0;
 always #7.5 ddr=~ddr;
 always #6.667 hdmi=~hdmi;
 wire hdmi_reset_n,raw_vs,hs,de,user,last;
 wire video_vsync=~raw_vs;
 security_reset_release hdmi_reset(hdmi,rstn,hdmi_reset_n);
 // Same actual timing-generator HDL and inversion as the top-level design.
 // Shorter geometry accelerates this startup/descriptor-only investigation.
 uivtc #(.H_ActiveSize(64),.H_FrameSize(80),.H_SyncStart(68),.H_SyncEnd(72),
  .V_ActiveSize(12),.V_FrameSize(18),.V_SyncStart(13),.V_SyncEnd(15)) vtc(
  .I_vtc_rstn(hdmi_reset_n),.I_vtc_clk(hdmi),.O_vtc_vs(raw_vs),
  .O_vtc_hs(hs),.O_vtc_de_valid(de),.O_vtc_user(user),.O_vtc_last(last));
 wire original_valid,fixed_valid,original_underflow,fixed_underflow;
 wire[15:0]original_reader,original_display,fixed_reader,fixed_display;
 startup_reader_path #(0)original_case(ddr,hdmi,rstn,video_vsync,de,user,
  original_valid,original_underflow,original_reader,original_display);
 startup_reader_path #(1)fixed_case(ddr,hdmi,rstn,video_vsync,de,user,
  fixed_valid,fixed_underflow,fixed_reader,fixed_display);
 integer errors=0,total_frames=0,run_frames=0,run_number=0;
 always @(negedge hdmi)begin
  if(rstn && de && user)begin
   total_frames=total_frames+1;run_frames=run_frames+1;
   $display("ACTUAL_VTC_WAIT run=%0d frame=%0d original_reader=%0d original_display=%0d original_valid=%b fixed_reader=%0d fixed_display=%0d fixed_valid=%b underflow=%b/%b",
    run_number,run_frames,original_reader,original_display,original_valid,
    fixed_reader,fixed_display,fixed_valid,original_underflow,fixed_underflow);
   if(original_valid!==1'b0 || original_display!==(original_reader+16'd1))errors=errors+1;
   if(fixed_valid!==1'b1 || fixed_display!==fixed_reader)errors=errors+1;
   if(original_underflow!==1'b0 || fixed_underflow!==1'b0)errors=errors+1;
  end
 end
 initial begin
  repeat(20)@(negedge ddr);
  $display("ACTUAL_VTC_RESET video_vsync=%b",video_vsync);
  if(video_vsync!==1'b1)errors=errors+1;
  rstn=1;
  wait(run_frames>=4);
  // Reproduce a button-style reset in active display, then rerun the real VTC.
  repeat(23)@(negedge hdmi);rstn=0;
  repeat(21)@(negedge ddr);run_frames=0;run_number=1;rstn=1;
  wait(run_frames>=4);
  #10;
  if(errors==0)$display("SIMULATION_PASS startup_actual_vtc original_rejected_fixed_valid frames=%0d",total_frames);
  else $display("SIMULATION_FAIL actual_VTC errors=%0d",errors);
  $finish;
 end
 initial begin #250000;$display("SIMULATION_FAIL actual_VTC timeout");$finish;end
endmodule
