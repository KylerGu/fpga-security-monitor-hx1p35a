// One pending frame descriptor, source holds data until destination consumes it.
// Destination consumes only at the blanking-to-active frame boundary.
module security_frame_cdc #(parameter WIDTH=115)(
 input wire src_clk, input wire dst_clk, input wire rst_n,
 input wire src_send, input wire [WIDTH-1:0] src_data, output wire src_ready,
 input wire dst_frame_latch, output reg dst_valid,
 output reg [WIDTH-1:0] dst_data
);
 wire src_reset_n;
 security_reset_release u_reset_release_src_reset_n(src_clk,rst_n,src_reset_n);
 wire dst_reset_n;
 security_reset_release u_reset_release_dst_reset_n(dst_clk,rst_n,dst_reset_n);
 reg [WIDTH-1:0] held;
 reg req,ack;
 (* async_reg="true" *) reg ack1,ack2,req1,req2;
 assign src_ready=req==ack2;
 always @(posedge src_clk or negedge src_reset_n)begin
  if(!src_reset_n)begin req<=0;held<=0;ack1<=0;ack2<=0;end
  else begin
   ack1<=ack;ack2<=ack1;
   if(src_send && src_ready)begin held<=src_data;req<=~req;end
  end
 end
 always @(posedge dst_clk or negedge dst_reset_n)begin
  if(!dst_reset_n)begin ack<=0;req1<=0;req2<=0;dst_valid<=0;dst_data<=0;end
  else begin
   req1<=req;req2<=req1;
   if(dst_frame_latch)begin
    dst_valid<=req2!=ack;
    if(req2!=ack)begin dst_data<=held;ack<=req2;end
   end
  end
 end
endmodule
