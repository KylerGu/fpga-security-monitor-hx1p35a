// Single aggregate red target, never a person/ID counter. All state uses the
// continuously running crystal clock. The existing alarm watchdog supplies stale.
// sample = {frame_id[15:0], complete, found, xmin[7:0], xmax[7:0], sensitivity[1:0]}.
// A missing observation breaks association: no inferred crossing across a gap.
module security_pass_counter #(
 parameter [8:0] LEFT_LIMIT=9'd154, RIGHT_LIMIT=9'd166
)(
 input wire clk,rst_n,sample_valid,input wire[35:0]sample,
 input wire stale,setting,input wire[1:0]sensitivity,
 output wire[39:0]status,output reg passed
);
 // Centre in 4-pixel units = xmin + xmax + 1. Limits 616 / 664 px.
 wire[8:0]centre={1'b0,sample[17:10]}+{1'b0,sample[9:2]}+9'd1;
 wire[1:0]side=centre<LEFT_LIMIT ? 2'd1 : centre>RIGHT_LIMIT ? 2'd2 : 2'd0;
 wire usable=sample[19] && sample[18] && sample[17:10]<=sample[9:2] && sample[1:0]==sensitivity;
 reg[15:0]last_id;
 reg have_id;
 wire sequential=have_id && sample[35:20]==last_id+16'd1;
 reg[1:0]origin,pending_side,confirm,sens_d,last_dir;
 reg[11:0]total,lr,rl;
 // status {confirmed origin (0/left/right), latest crossing (0/L>R/R>L),
 //         total BCD, L>R BCD, R>L BCD}. Each counter saturates at 999.
 assign status={origin,last_dir,total,lr,rl};
 function[11:0]increment;input[11:0]v;begin
  if(v==12'h999)increment=v;
  else if(v[3:0]!=9)increment=v+12'd1;
  else if(v[7:4]!=9)increment={v[11:4]+8'd1,4'd0};
  else increment={v[11:8]+4'd1,8'd0};
 end endfunction
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   last_id<=0;have_id<=0;origin<=0;pending_side<=0;confirm<=0;sens_d<=0;
   last_dir<=0;total<=0;lr<=0;rl<=0;passed<=0;
  end else begin
   passed<=0;sens_d<=sensitivity;
   if(stale || setting || sens_d!=sensitivity)begin
    have_id<=0;origin<=0;pending_side<=0;confirm<=0;
   end else if(sample_valid)begin
    last_id<=sample[35:20];have_id<=1;
    if(!usable)begin origin<=0;pending_side<=0;confirm<=0;end
    else if(!sequential)begin
     // First observation, skipped/repeated frame ID or mailbox overflow:
     // start qualification again, never count this transition.
     origin<=0;pending_side<=side;confirm<=side==0 ? 2'd0 : 2'd1;
    end else if(side==0 || side==origin)begin
     // Neutral band and dwell keep origin but cannot advance qualification.
     pending_side<=0;confirm<=0;
    end else if(pending_side!=side)begin pending_side<=side;confirm<=1;end
    else if(confirm==2)begin
     origin<=side;pending_side<=0;confirm<=0;
     if(origin!=0)begin
      passed<=1;total<=increment(total);
      if(side==2)begin lr<=increment(lr);last_dir<=1;end
      else begin rl<=increment(rl);last_dir<=2;end
     end
    end else confirm<=confirm+1'b1;
   end
  end
 end
endmodule

// Reuse the existing coherent frame descriptor without changing its format or
// its motion/alarm path. Camera -> crystal mailbox may drop under backpressure;
// the frame sequence check above safely rejects the resulting association gap.
module security_pass_monitor(
 input wire camera_clk,ref_clk,hdmi_clk,rst_n,
 input wire result_valid,input wire[255:0]result_data,
 input wire stale,setting,input wire[1:0]sensitivity,
 input wire hdmi_blank,output wire[39:0]display_status
);
 wire ref_reset_n;
 security_reset_release pass_reset(ref_clk,rst_n,ref_reset_n);
 wire sample_ready,sample_valid;wire[35:0]sample;
 security_frame_cdc #(.WIDTH(36)) observations(
  .src_clk(camera_clk),.dst_clk(ref_clk),.rst_n(rst_n),
  .src_send(result_valid),.src_ready(sample_ready),
  .src_data({result_data[239:224],result_data[205] && result_data[62],result_data[61],result_data[60:45],result_data[22:21]}),
  .dst_frame_latch(1'b1),.dst_valid(sample_valid),.dst_data(sample));
 wire[39:0]status;wire passed;
 security_pass_counter counter(ref_clk,ref_reset_n,sample_valid,sample,stale,setting,sensitivity,status,passed);
 // Send the newest cumulative snapshot as soon as the previous one is consumed.
 // Intermediate UI snapshots can coalesce; no counting depends on HDMI rate.
 wire display_ready,display_valid;
 reg[39:0]sent;reg sent_once;
 wire send=display_ready && (!sent_once || sent!=status);
 always @(posedge ref_clk or negedge ref_reset_n)begin
  if(!ref_reset_n)begin sent<=0;sent_once<=0;end
  else if(send)begin sent<=status;sent_once<=1;end
 end
 security_frame_cdc #(.WIDTH(40)) display(
  .src_clk(ref_clk),.dst_clk(hdmi_clk),.rst_n(rst_n),
  .src_send(send),.src_data(status),.src_ready(display_ready),
  .dst_frame_latch(hdmi_blank),.dst_valid(display_valid),.dst_data(display_status));
endmodule
