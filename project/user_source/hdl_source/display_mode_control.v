// Both keys are active low. A stable release is required before another press.
module display_mode_control #(parameter integer DEBOUNCE_CYCLES=1000000)(
 input clk, rst_n, input [1:0] key_n, output reg [1:0] mode
);
 (* async_reg="true" *) reg [1:0] meta, sync_key;
 reg [1:0] stable;
 reg [19:0] count0,count1;
 wire press0=(sync_key[0]!=stable[0]) && count0==DEBOUNCE_CYCLES-1 && !sync_key[0];
 wire press1=(sync_key[1]!=stable[1]) && count1==DEBOUNCE_CYCLES-1 && !sync_key[1];
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin meta<=3;sync_key<=3;stable<=3;count0<=0;count1<=0;mode<=0;end
  else begin
   meta<=key_n;sync_key<=meta;
   if(sync_key[0]==stable[0]) count0<=0;
   else if(count0==DEBOUNCE_CYCLES-1) begin stable[0]<=sync_key[0];count0<=0;end
   else count0<=count0+1'b1;
   if(sync_key[1]==stable[1]) count1<=0;
   else if(count1==DEBOUNCE_CYCLES-1) begin stable[1]<=sync_key[1];count1<=0;end
   else count1<=count1+1'b1;
   if(press1) mode<=0;
   else if(press0) begin
    case(mode)
     2'd0: mode<=2'd3; // RAW -> GRAY
     2'd3: mode<=2'd1; // GRAY -> EDGE
     2'd1: mode<=2'd2; // EDGE -> EDGE+OSD
     default: mode<=2'd0;
    endcase
   end
  end
 end
endmodule

// Bundled-data handshake: the source holds the complete mode word until ack.
// Common asynchronous reset is required in both domains. Intermediate requests
// may coalesce while busy; the latest stable request is always delivered.
module display_mode_cdc(
 input src_clk,dst_clk,rst_n,input [1:0] src_mode,output reg [1:0] dst_mode
);
 reg [1:0] held;
 reg req,ack;
 (* async_reg="true" *) reg req1,req2,ack1,ack2;
 always @(posedge src_clk or negedge rst_n) begin
  if(!rst_n) begin held<=0;req<=0;ack1<=0;ack2<=0;end
  else begin
   ack1<=ack;ack2<=ack1;
   if(req==ack2 && held!=src_mode) begin held<=src_mode;req<=~req;end
  end
 end
 always @(posedge dst_clk or negedge rst_n) begin
  if(!rst_n) begin req1<=0;req2<=0;ack<=0;dst_mode<=0;end
  else begin
   req1<=req;req2<=req1;
   if(req2!=ack) begin dst_mode<=held;ack<=req2;end
  end
 end
endmodule
