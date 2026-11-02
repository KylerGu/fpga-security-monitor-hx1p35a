// Preserve identity through the command queue; ready is NOT write completion.
module security_mc_interface (
 input wire I_clk,I_rst_n,I_ddr_user_wr_en,I_ddr_user_rd_en,
 input wire[24:0]I_ddr_user_addr,input wire[127:0]I_ddr_user_wr_data,
 input wire[31:0]I_ddr_user_frame_id,
 output wire O_ddr_user_ready,O_ddr_user_rd_valid,
 output wire[127:0]O_ddr_user_rd_data,
 output wire O_mc_app_en,output wire[24:0]O_mc_app_addr,
 output wire[2:0]O_mc_app_cmd,input wire I_mc_app_rdy,
 output wire O_mc_app_wdf_wren,output wire[127:0]O_mc_app_wdf_data,
 output wire O_mc_app_wdf_end,output wire[31:0]O_mc_app_wdf_mask,
 input wire I_mc_app_wdf_rdy,input wire[127:0]I_mc_app_rd_data,
 input wire I_mc_app_rd_data_end,I_mc_app_rd_data_valid,
 output wire O_write_accepted,output wire[31:0]O_accepted_frame,
 output wire[24:0]O_accepted_addr
);
 wire almost_full,empty;wire[186:0]head;
 wire pop=I_mc_app_rdy && I_mc_app_wdf_rdy && !empty;
 soft_fifo_al_f58e8b3e1f3d #(.DATA_WIDTH_W(187),.DATA_WIDTH_R(187),
 .ADDR_WIDTH_W(9),.ADDR_WIDTH_R(9),.AL_FULL_NUM(500),.AL_EMPTY_NUM(2),
 .SHOW_AHEAD_EN(1),.OUTREG_EN("NOREG")) commands(
  .rst(!I_rst_n),.clk(I_clk),.we(I_ddr_user_wr_en||I_ddr_user_rd_en),
  .di({I_ddr_user_frame_id,I_ddr_user_wr_en,I_ddr_user_rd_en,I_ddr_user_addr,I_ddr_user_wr_data}),
  .re(pop),.dout(head),.valid(),.afull(almost_full),.empty_flag(empty),
  .full_flag(),.aempty(),.wrusedw(),.rdusedw());
 assign O_ddr_user_ready=!almost_full;
 assign O_mc_app_en=pop;
 assign O_mc_app_addr=pop ? head[152:128] : 25'b0;
 assign O_mc_app_cmd=pop && head[153] ? 3'd1 : 3'd0;
 assign O_mc_app_wdf_wren=pop && head[154];
 assign O_mc_app_wdf_end=O_mc_app_wdf_wren;
 assign O_mc_app_wdf_mask=0;
 assign O_mc_app_wdf_data=O_mc_app_wdf_wren ? head[127:0] : 128'b0;
 assign O_ddr_user_rd_data=I_mc_app_rd_data;
 assign O_ddr_user_rd_valid=I_mc_app_rd_data_valid;
 assign O_write_accepted=O_mc_app_wdf_wren;
 assign O_accepted_frame=head[186:155];
 assign O_accepted_addr=head[152:128];
endmodule
