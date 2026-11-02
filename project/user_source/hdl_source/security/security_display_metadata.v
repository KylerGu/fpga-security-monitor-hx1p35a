// Late descriptors are never applied mid-picture, including horizontal blanking.
// Epoch rejects a descriptor that arrives one display frame late.
module security_display_metadata(
 input wire ddr_clk,hdmi_clk,rst_n,
 input wire selection,candidate_valid,input wire[255:0]candidate_meta,input wire[15:0]selected_epoch,
 input wire vsync,de,user,
 output wire[255:0]effective_meta,output wire effective_valid,output reg dropped
);
 wire ddr_reset_n;
 security_reset_release u_reset_release_ddr_reset_n(ddr_clk,rst_n,ddr_reset_n);
 wire hdmi_reset_n;
 security_reset_release u_reset_release_hdmi_reset_n(hdmi_clk,rst_n,hdmi_reset_n);
 reg[255:0]sent;reg send;
 wire ready,pending;wire[255:0]received;
 reg[255:0]shown;reg shown_valid,active_frame,vs_prev;
 reg[15:0]epoch;
 wire pending_good=pending && received[16] && received[15:0]==epoch;
 assign effective_meta=pending_good ? received : shown;
 assign effective_valid=pending_good || shown_valid;
 always @(posedge ddr_clk or negedge ddr_reset_n)begin
  if(!ddr_reset_n)begin send<=0;sent<=0;dropped<=0;end
  else begin
   send<=0;
   if(selection)begin
    if(ready)begin
     sent<=candidate_meta;sent[15:0]<=selected_epoch;sent[16]<=candidate_valid;send<=1;
    end else dropped<=1;
   end
  end
 end
 security_frame_cdc #(.WIDTH(256)) mailbox(
  .src_clk(ddr_clk),.dst_clk(hdmi_clk),.rst_n(rst_n),.src_send(send),.src_data(sent),.src_ready(ready),
  .dst_frame_latch(!active_frame && !de),.dst_valid(pending),.dst_data(received));
 always @(posedge hdmi_clk or negedge hdmi_reset_n)begin
  if(!hdmi_reset_n)begin epoch<=0;vs_prev<=0;active_frame<=0;shown<=0;shown_valid<=0;end
  else begin
   vs_prev<=vsync;
   if(vsync && !vs_prev)begin epoch<=epoch+1'b1;shown_valid<=0;active_frame<=0;end
   else begin
    if(user && de)active_frame<=1;
    if(pending && !active_frame)begin shown<=received;shown_valid<=pending_good;end
   end
  end
 end
endmodule
