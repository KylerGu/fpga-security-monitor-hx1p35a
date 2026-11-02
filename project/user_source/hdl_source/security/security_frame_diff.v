// Full small-frame ping-pong store. RAM returns in 2 sampling stages; registered
// absolute difference is valid in the following stage. No output on first frame.
module security_frame_diff #(parameter PIXELS=14400)(
 input wire clk,input wire rst,input wire frame_start,input wire frame_abort,
 input wire in_valid,input wire in_last,input wire[13:0]in_addr,input wire[7:0]in_gray,
 output reg out_valid,output reg out_last,output reg[13:0]out_addr,
 output reg[7:0]out_current,output reg[7:0]out_previous,output reg[7:0]out_difference,
 output reg frame_done,output reg frame_fault,output wire busy
);
 reg active=0,previous_valid=0,write_bank=0;
 reg[13:0]count=0;
 reg[1:0]drain=0;
 reg[7:0]current0,current1;
 reg[13:0]addr0,addr1;
 reg[1:0]last_pipe=0;
 wire accepted=in_valid && active && drain==0 && in_addr==count &&
               count<PIXELS && !frame_start && !frame_abort;
 wire[7:0]previous;wire qvalid;
 security_ram_probe storage(clk,rst || frame_abort || frame_start,
   accepted,write_bank,in_addr,in_gray,
   accepted && previous_valid,!write_bank,in_addr,previous,qvalid);
 assign busy=drain!=0;
 always @(posedge clk)begin
  if(rst)begin
   active<=0;previous_valid<=0;write_bank<=0;count<=0;drain<=0;
   out_valid<=0;out_last<=0;out_addr<=0;
   out_current<=0;out_previous<=0;out_difference<=0;
   frame_done<=0;frame_fault<=0;last_pipe<=0;current0<=0;current1<=0;addr0<=0;addr1<=0;
  end else begin
   out_valid<=qvalid && !frame_start && !frame_abort;
   out_last<=qvalid && last_pipe[1] && !frame_start && !frame_abort;
   frame_done<=0;frame_fault<=0;
   current0<=in_gray;current1<=current0;addr0<=in_addr;addr1<=addr0;
   last_pipe<={last_pipe[0],accepted && in_last};
   if(qvalid)begin
    out_current<=current1;out_previous<=previous;out_addr<=addr1;
    out_difference<=current1>=previous ? current1-previous : previous-current1;
   end
   if(frame_start)begin
    if(active || drain!=0 || frame_abort)begin previous_valid<=0;frame_fault<=1;end
    active<=1;count<=0;drain<=0;
   end else if(frame_abort)begin
    active<=0;previous_valid<=0;drain<=0;frame_fault<=1;
   end else begin
    if(in_valid && active)begin
     if(!accepted || in_last!=(count==PIXELS-1))begin
      active<=0;previous_valid<=0;frame_fault<=1;drain<=0;
     end else begin
      count<=count+1'b1;
      if(in_last)begin active<=0;drain<=3;end
     end
    end
    if(drain!=0)begin
     drain<=drain-1'b1;
     if(drain==1)begin write_bank<=!write_bank;previous_valid<=1;frame_done<=1;end
    end
   end
  end
 end
endmodule
