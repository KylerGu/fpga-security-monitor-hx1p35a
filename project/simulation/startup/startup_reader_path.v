`timescale 1ns/1ps
module startup_reader_path #(parameter FIXED=0)(
 input wire ddr,hdmi,rstn,vsync,de,user,
 output wire valid,underflow,
 output wire[15:0]reader_epoch,display_epoch
);
 wire selection,selected_valid,busy,read_en;
 wire[1:0]slot;
 wire[24:0]addr;
 wire[23:0]pixel;
 wire[255:0]shown;
 wire dropped;
 generate if(FIXED)begin:fixed_path
  security_video_out reader(
   .I_candidate_valid(1'b1),.I_candidate_slot(2'd0),
   .O_selection(selection),.O_selected_valid(selected_valid),
   .O_selected_slot(slot),.O_selected_epoch(reader_epoch),
   .O_underflow(underflow),.I_rst_n(rstn),.I_ddr_clk(ddr),
   .O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),
   .I_video_out_rp(2'd0),.O_ddr_user_rd_en(read_en),.O_ddr_user_addr(addr),
   .I_ddr_user_ready(1'b0),.I_ddr_user_rd_valid(1'b0),.I_ddr_user_rd_data(128'd0),
   .I_dsi_clk(hdmi),.I_video_vsync(vsync),.I_video_rd_en(1'b0),.O_vdieo_data(pixel));
 end else begin:original_path
  security_video_out_original reader(
   .I_candidate_valid(1'b1),.I_candidate_slot(2'd0),
   .O_selection(selection),.O_selected_valid(selected_valid),
   .O_selected_slot(slot),.O_selected_epoch(reader_epoch),
   .O_underflow(underflow),.I_rst_n(rstn),.I_ddr_clk(ddr),
   .O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),
   .I_video_out_rp(2'd0),.O_ddr_user_rd_en(read_en),.O_ddr_user_addr(addr),
   .I_ddr_user_ready(1'b0),.I_ddr_user_rd_valid(1'b0),.I_ddr_user_rd_data(128'd0),
   .I_dsi_clk(hdmi),.I_video_vsync(vsync),.I_video_rd_en(1'b0),.O_vdieo_data(pixel));
 end endgenerate
 security_display_metadata metadata(
  .ddr_clk(ddr),.hdmi_clk(hdmi),.rst_n(rstn),
  .selection(selection),.candidate_valid(1'b1),.candidate_meta({32'd17,224'd0}),
  .selected_epoch(reader_epoch),.vsync(vsync),.de(de),.user(user),
  .effective_meta(shown),.effective_valid(valid),.dropped(dropped));
 assign display_epoch=metadata.epoch;
endmodule

