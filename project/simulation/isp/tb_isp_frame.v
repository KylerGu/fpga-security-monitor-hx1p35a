`timescale 1ns/1ps
// Production ISP wrapper, AWB, AWB delay, edge stage and RGB packing.
// Demosaic expands synthetic RGB input; divider is held at unity gain;
// a dual-port behavioral RAM replaces the device memory primitive.
module tb_isp_frame;
 reg clk=0,rst=0,valid=0,user=0,last=0;
 reg [1:0] mode=0;
 reg [23:0] color=24'hff0000;
 wire [127:0] data;
 wire ov,ou,ol,ready;
 integer errors=0,raw_words=0,gray_words=0,edge_words=0,early_markers=0;
 integer phase=0,row,beat;
 always #5 clk=~clk;
 isp_top dut(.I_mode(mode),.axi4s_video_aclk(clk),.I_rst_n(rst),
 .I_tlast(last),.I_tuser(user),.I_tdata({16'd0,color}),.I_tvalid(valid),
 .I_tdest(10'd0),.O_tready(1'b1),.O_tdata(data),.O_tlast(ol),.O_tuser(ou),.O_tvalid(ov),.I_tready(ready));
 always @(posedge clk) begin
  if(rst && dut.awb_O_tuser && !dut.awb_O_tvalid) early_markers=early_markers+1;
  #1;
  if(dut.O_raw_valid && (dut.O_raw_rgb4!==dut.awb_O_tdata || dut.O_raw_last!==dut.awb_O_tlast))errors=errors+1;
  if(phase==1 && dut.O_raw_valid && dut.O_capture_mode!==3)errors=errors+1;
  if(ov) begin
   case(phase)
    0: if(^data===1'bx || data=={16{8'h3f}} || data==0) begin errors=errors+1; end else raw_words=raw_words+1;
    1: begin
     gray_words=gray_words+1;
     if(data!=={16{8'h3f}}) begin
      if(errors<4) $display("GRAY mismatch packed=%h frame_mode=%d AWB start/valid=%b/%b",data,dut.u_edge_detect_96.frame_mode,dut.awb_O_tuser,dut.awb_O_tvalid);
      errors=errors+1;
     end
    end
    2: begin edge_words=edge_words+1; if(data!==0) errors=errors+1; end
   endcase
  end
 end
 task frame;
 input [1:0] selected;
 input integer target_phase;
 begin
  phase=target_phase;
  // A bright flat frame after red exposes stale line-buffer row coordinates.
  // Its first two rows must be masked, and all later gradients must be zero.
  color=(target_phase==2)?24'hffffff:24'hff0000;
  @(negedge clk); mode=selected; user=1;valid=0;last=0;
  @(negedge clk); user=0;
  // Start precedes input data, as it can on this video pipeline.
  repeat(5) @(negedge clk);
  for(row=0;row<3;row=row+1) begin
   for(beat=0;beat<320;beat=beat+1) begin
    valid=1; last=(beat==319); @(negedge clk);
   end
   valid=0;last=0;
   // Changing the request mid-frame must wait for the next frame start.
   if(target_phase==1) mode=0;
   repeat(100) @(negedge clk);
  end
  repeat(100) @(negedge clk);
 end
 endtask
 initial begin
  #20; @(negedge clk);rst=1;
  frame(0,0); frame(3,1); frame(1,2); frame(2,0); frame(0,0);
  if(errors || raw_words!=2160 || gray_words!=720 || edge_words!=720 || early_markers!=5)
   $display("SIMULATION_FAIL ISP frame start: errors=%0d RAW=%0d GRAY=%0d EDGE=%0d early=%0d",errors,raw_words,gray_words,edge_words,early_markers);
  else $display("SIMULATION_PASS real AWB raw_tap early_SOF frame_mode RAW_GRAY_EDGE_MOTION_RAW packed_RGB");
  $finish;
 end
 initial begin #200000; $display("SIMULATION_FAIL ISP frame timeout");$finish;end
endmodule

module demosaic #(parameter IMG_HEIGHT=720,IMG_WIDTH=1280,data_complete_delay=50,BAYER_MODE="BGGR")(
 input I_clk,I_rst_n,input [39:0] axi4s_video_tdata,input [9:0] axi4s_video_tdest,
 input axi4s_video_tlast,axi4s_video_tvalid,axi4s_video_tuser,output axi4s_video_tready,
 output O_tlast,O_tuser,output [127:0] O_tdata,output O_tvalid,input O_tready);
 assign axi4s_video_tready=O_tready;
 assign O_tlast=axi4s_video_tlast;
 assign O_tuser=axi4s_video_tuser;
 assign O_tvalid=axi4s_video_tvalid;
 assign O_tdata={4{8'd0,axi4s_video_tdata[23:0]}};
endmodule
module data128_96(input [127:0] I_tdata,output [95:0] O_tdata);
 assign O_tdata={I_tdata[119:96],I_tdata[87:64],I_tdata[55:32],I_tdata[23:0]};
endmodule
module divider(input clk,rst,start,input [31:0] denominator,input [47:0] numerator,output [47:0] quotient,output done);
 assign quotient=48'h000000010000;
 assign done=1'b0;
endmodule
module blk_mem_gen_awb_delay_signal(input clka,wea,input [10:0] addra,input [95:0] dia,
 input clkb,input [10:0] addrb,output reg [95:0] dob);
 reg [95:0] memory[0:2047];
 always @(posedge clka) if(wea) memory[addra]<=dia;
 always @(posedge clkb) dob<=memory[addrb];
endmodule
