// Frame identity and word index travel in the SAME FIFO entry as each pixel word.
// No per-frame FIFO reset: congestion cannot silently splice different frames.
module security_capture_writer #(parameter WORDS=172800)(
 input wire I_rst_n,I_camera_clk,I_camera_frame_start,I_camera_valid,
 input wire[127:0]I_camera_data,input wire[31:0]I_frame_id,
 input wire I_ddr_clk,I_video_out_rd_busy,I_ddr_user_ready,
 input wire I_protected_valid,input wire[1:0]I_protected_slot,
 output wire O_video_in_wr_busy,output wire O_ddr_user_wr_en,
 output wire[24:0]O_ddr_user_addr,output wire[127:0]O_ddr_user_wr_data,
 output wire[31:0]O_ddr_user_frame_id,
 output wire O_alloc,output wire[1:0]O_alloc_slot,output wire[31:0]O_alloc_frame,
 output reg O_capture_overflow,output reg O_frame_drop
);
 wire camera_reset_n;
 security_reset_release u_reset_release_camera_reset_n(I_camera_clk,I_rst_n,camera_reset_n);
 wire ddr_reset_n;
 security_reset_release u_reset_release_ddr_reset_n(I_ddr_clk,I_rst_n,ddr_reset_n);
 reg[17:0]source_index;
 wire[17:0]packet_index=I_camera_frame_start ? 18'd0 : source_index;
 wire fifo_full,fifo_empty,fifo_valid;
 wire[177:0]fifo_data;
 reg[177:0]packet;
 reg[1:0]state;
 reg active;
 reg alloc_sent;
 reg[31:0]active_id;
 reg[17:0]next_index;
 reg[24:0]next_address;
 wire[31:0]packet_id=packet[177:146];
 wire[17:0]index=packet[145:128];
 wire[1:0]slot=packet_id[1:0]-2'd1;
 wire protected=I_protected_valid && slot==I_protected_slot;
 wire pop=ddr_reset_n && state==0 && !fifo_empty && !I_video_out_rd_busy;
 wire push=camera_reset_n && I_camera_valid && packet_index<WORDS && !fifo_full;
 soft_fifo_al_4057d6b76aa6 #(.DATA_WIDTH_W(178),.DATA_WIDTH_R(178),
  .ADDR_WIDTH_W(9),.ADDR_WIDTH_R(9),.AL_FULL_NUM(500),.AL_EMPTY_NUM(2),
  .SHOW_AHEAD_EN(0),.OUTREG_EN("NOREG")) pixels (
  .rst(!I_rst_n),.clkw(I_camera_clk),.clkr(I_ddr_clk),.we(push),
  .di({I_frame_id,packet_index,I_camera_data}),.re(pop),.dout(fifo_data),
  .valid(fifo_valid),.full_flag(fifo_full),.empty_flag(fifo_empty),
  .afull(),.aempty(),.wrusedw(),.rdusedw());
 always @(posedge I_camera_clk or negedge camera_reset_n)begin
  if(!camera_reset_n)begin source_index<=0;O_capture_overflow<=0;end
  else begin
   if(I_camera_frame_start)source_index<=0;
   if(I_camera_valid)begin
    if(fifo_full || packet_index>=WORDS)O_capture_overflow<=1;
    if(packet_index<WORDS)source_index<=packet_index+1'b1;
   end
  end
 end
 function[24:0]base;input[1:0]s;begin
  case(s)0:base=0;1:base=7000000;2:base=14000000;default:base=21000000;endcase
 end endfunction
 // Validate and enqueue the held word in the same cycle. Keeping a separate
 // address-setup state limited sustained capture while display reads overlap.
 wire first_packet=index==0;
 wire packet_ok=first_packet ? !protected :
   active && packet_id==active_id && index==next_index;
 assign O_video_in_wr_busy=state!=0;
 assign O_ddr_user_wr_en=state==2 && packet_ok && !I_video_out_rd_busy && I_ddr_user_ready;
 assign O_ddr_user_addr=first_packet ? base(slot) : next_address;
 assign O_ddr_user_wr_data=packet[127:0];
 assign O_ddr_user_frame_id=packet_id;
 // Allocate once without carrying the reader FIFO occupancy/queue-ready
 // combinational path into the wide newest-frame metadata selection.
 // Physical write completion still commits the frame separately.
 assign O_alloc=state==2 && first_packet && !protected && !alloc_sent;
 assign O_alloc_slot=slot;
 assign O_alloc_frame=packet_id;
 always @(posedge I_ddr_clk or negedge ddr_reset_n)begin
  if(!ddr_reset_n)begin state<=0;active<=0;alloc_sent<=0;active_id<=0;next_index<=0;
   next_address<=0;packet<=0;O_frame_drop<=0;end
  else begin
   O_frame_drop<=0;
   if(O_alloc)alloc_sent<=1;
   case(state)
    0:if(pop)begin state<=1;alloc_sent<=0;end
    1:if(fifo_valid)begin packet<=fifo_data;state<=2;end
    2:begin
     if(!packet_ok)begin active<=0;state<=0;O_frame_drop<=1;end
     else if(O_ddr_user_wr_en)begin
      state<=0;next_address<=O_ddr_user_addr+25'd8;
      if(first_packet)begin
       active_id<=packet_id;next_index<=1;active<=WORDS!=1;
      end else begin
       next_index<=next_index+1'b1;
       if(index==WORDS-1)active<=0;
      end
     end
    end
    default:begin state<=0;active<=0;end
   endcase
  end
 end
endmodule
