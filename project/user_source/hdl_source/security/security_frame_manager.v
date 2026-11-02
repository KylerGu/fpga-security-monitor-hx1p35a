// All flags describe the same (slot,frame_id). Actual MC acceptance commits pixels.
// candidate_meta[66:63] = display lag: newest allocated (being written) frame minus
// the candidate's frame, saturated at 9; registered per slot, one clock behind.
module security_frame_manager #(parameter WORDS=172800)(
 input wire clk,rst_n,alloc,input wire[1:0]alloc_slot,input wire[31:0]alloc_frame,
 input wire accepted,input wire[24:0]accepted_addr,input wire[31:0]accepted_frame,
 input wire result_valid,input wire[255:0]result_data,
 output reg candidate_valid,output reg[1:0]candidate_slot,
 output reg[255:0]candidate_meta,output reg rejected
);
 reg[3:0]allocated,complete,has_result,bad;
 reg[31:0]frame[0:3];reg[17:0]count[0:3];reg[24:0]next_addr[0:3];
 reg[255:0]meta[0:3];
 reg[7:0]newest;reg[3:0]lag[0:3];reg[7:0]diff;
 integer i,j;
 function[24:0]base;input[1:0]s;begin
 case(s)0:base=0;1:base=7000000;2:base=14000000;default:base=21000000;endcase
 end endfunction
 reg[1:0]write_slot;
 always @*begin
  if(accepted_addr>=21000000)write_slot=3;
  else if(accepted_addr>=14000000)write_slot=2;
  else if(accepted_addr>=7000000)write_slot=1;
  else write_slot=0;
 end
 wire[1:0]result_slot=result_data[225:224]-2'd1;
 always @*begin
  candidate_valid=0;candidate_slot=0;candidate_meta=0;
  for(j=0;j<4;j=j+1)begin
   if(allocated[j] && complete[j] && has_result[j] && !bad[j] &&
      !(alloc && alloc_slot==j) &&
      (!candidate_valid || $signed(frame[j]-candidate_meta[255:224])>0))begin
    candidate_valid=1;candidate_slot=j;candidate_meta=meta[j];candidate_meta[66:63]=lag[j];
   end
  end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   allocated<=0;complete<=0;has_result<=0;bad<=0;rejected<=0;
   for(i=0;i<4;i=i+1)begin frame[i]<=0;count[i]<=0;next_addr[i]<=0;meta[i]<=0;lag[i]<=0;end
   newest<=0;
  end else begin
   if(alloc)newest<=alloc_frame[7:0];
   for(i=0;i<4;i=i+1)begin diff=newest-frame[i][7:0];lag[i]<=diff>8'd9 ? 4'd9 : diff[3:0];end
   rejected<=0;
   if(alloc)begin
    allocated[alloc_slot]<=1;complete[alloc_slot]<=0;has_result[alloc_slot]<=0;
    bad[alloc_slot]<=0;frame[alloc_slot]<=alloc_frame;count[alloc_slot]<=0;
    next_addr[alloc_slot]<=base(alloc_slot);
   end
   if(accepted && !(alloc && alloc_slot==write_slot))begin
    if(allocated[write_slot] && frame[write_slot]==accepted_frame)begin
     if(!bad[write_slot] && accepted_addr==next_addr[write_slot] && count[write_slot]<WORDS)begin
      count[write_slot]<=count[write_slot]+1'b1;
      next_addr[write_slot]<=next_addr[write_slot]+25'd8;
      if(count[write_slot]==WORDS-1)complete[write_slot]<=1;
     end else begin bad[write_slot]<=1;complete[write_slot]<=0;rejected<=1;end
    end else rejected<=1;
   end
   if(result_valid)begin
    if(allocated[result_slot] && frame[result_slot]==result_data[255:224] &&
       !(alloc && alloc_slot==result_slot))begin
     meta[result_slot]<=result_data;has_result[result_slot]<=1;
    end else rejected<=1;
   end
  end
 end
endmodule
