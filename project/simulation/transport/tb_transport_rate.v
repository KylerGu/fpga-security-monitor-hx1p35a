`timescale 1ns/1ps
module tb_transport_rate #(parameter ROW_BLANK=1420, ROWS=60);
 localparam WORDS=240*ROWS;
 reg cam=0,ddr=0,hdmi=0;always #4.830 cam=~cam;always #7.5 ddr=~ddr;always #6.667 hdmi=~hdmi;
 reg rstn=0,fs=0,iv=0;reg[127:0]data=0;reg[31:0]fid=0;
 reg enable_mc=0,vs=0,read_pixel=0,rv=0,defer_meta=0;reg[255:0]result=0;
 wire wr,rd,wrbusy,rdbusy,ready;wire[24:0]wa,ra;wire[127:0]wd;
 wire[31:0]wf,af,accepted_f;wire alloc,accepted;wire[1:0]aslot,selected,candidate;
 wire selected_valid,candidate_valid,selection,underflow,overflow,drop,rejected;
 wire[15:0]epoch;wire[255:0]candidate_meta;
 wire[24:0]accepted_addr,mc_addr;wire[2:0]mc_cmd;
 wire[127:0]mc_data;wire mc_en,mc_we,mc_last;wire[31:0]mask;
 wire[23:0]pixel;
 integer tick=0,errors=0,accepted_words=0,pixel_checks=0;
 wire mc_ready=enable_mc && tick%11!=0;
 wire mc_wready=enable_mc && tick%7!=0;
 reg[23:0]response_valid=0;reg[127:0]response_data[0:23];
 wire response=response_valid[23];wire[127:0]response_word=response_data[23];
 reg[127:0]memory[0:4*WORDS-1];integer i,s,index;
 security_capture_writer #(WORDS) writer(rstn,cam,fs,iv,data,fid,ddr,rdbusy,ready,
   selected_valid,selected,wrbusy,wr,wa,wd,wf,alloc,aslot,af,overflow,drop);
 security_mc_interface queue(ddr,rstn,wr,rd,wr?wa:ra,wd,wf,ready,,,
   mc_en,mc_addr,mc_cmd,mc_ready,mc_we,mc_data,mc_last,mask,mc_wready,
   response_word,1'b0,response,accepted,accepted_f,accepted_addr);
 security_frame_manager #(WORDS) manager(ddr,rstn,alloc,aslot,af,accepted,accepted_addr,accepted_f,
   rv,result,candidate_valid,candidate,candidate_meta,rejected);
 security_video_out #(WORDS) reader(
   .I_candidate_valid(candidate_valid),.I_candidate_slot(candidate),.O_selection(selection),
   .O_selected_valid(selected_valid),.O_selected_slot(selected),.O_selected_epoch(epoch),.O_underflow(underflow),
   .I_rst_n(rstn),.I_ddr_clk(ddr),.O_video_out_rd_busy(rdbusy),.I_video_in_wr_busy(wrbusy),
   .I_video_out_rp(2'b0),.O_ddr_user_rd_en(rd),.O_ddr_user_addr(ra),.I_ddr_user_ready(ready),
   .I_ddr_user_rd_valid(response),.I_ddr_user_rd_data(response_word),
   .I_dsi_clk(hdmi),.I_video_vsync(vs),.I_video_rd_en(read_pixel),.O_vdieo_data(pixel));
 function[127:0]word_value;input integer id,w;begin word_value={32'habcd0000|id,id[31:0],w[31:0],~w[31:0]};end endfunction
 function[23:0]pixel_value;input integer id,p;reg[255:0]pair;integer n,off;
 begin n=(p*24)/128;off=(p*24)%128;pair={word_value(id,n),word_value(id,n+1)};pixel_value=pair>>(232-off);end endfunction
 always @(posedge ddr)begin
  tick=tick+1;
  response_valid<={response_valid[22:0],mc_en && mc_cmd==1};
  for(i=1;i<24;i=i+1)response_data[i]<=response_data[i-1];
  if(mc_en)begin
   s=mc_addr/7000000;index=(mc_addr-s*7000000)/8;
   if(index>=WORDS)begin errors=errors+1;$display("FAIL DDR out of frame index=%0d",index);end
   else if(mc_cmd==0)begin
    memory[s*WORDS+index]<=mc_data;accepted_words=accepted_words+1;
    if(mc_data!==word_value(accepted_f,index) || accepted_f==6)begin
     if(errors<8)$display("FAIL committed pixel/tag id=%0d index=%0d got=%h",accepted_f,index,mc_data);errors=errors+1;
    end
   end else response_data[0]<=memory[s*WORDS+index];
  end
  if(wr && rd)begin errors=errors+1;$display("FAIL read/write enqueue collision");end
 end
 reg overflow_seen=0;
 always @(posedge cam) if(overflow && !overflow_seen)begin
  overflow_seen<=1;
  $display("RATE_OVERFLOW time_ns=%0t frame=%0d source_index=%0d fifo_full=%b fifo_used=%0d read_busy=%b writer_state=%0d",$time,fid,writer.source_index,writer.fifo_full,writer.pixels.wrusedw,rdbusy,writer.state);
 end
 integer expected_id=0,expected_pixel=0;reg prev_read=0;
 reg[23:0]want;
 always @(posedge hdmi)begin
  if(prev_read)begin
   want=pixel_value(expected_id,expected_pixel);
   #1;
   if(pixel!==want)begin
    if(errors<8)$display("FAIL display id=%0d pixel=%0d got=%h want=%h",expected_id,expected_pixel,pixel,want);errors=errors+1;
   end
   expected_pixel=expected_pixel+1;pixel_checks=pixel_checks+1;
  end else #1;
  prev_read=read_pixel;
 end
 task send_frame;input integer id,words;integer n;begin
  @(negedge cam);fid=id;fs=1;iv=0;@(negedge cam);fs=0;
  for(n=0;n<words;n=n+1)begin
   @(negedge cam);iv=1;data=word_value(id,n);
   if(n%3==2)begin @(negedge cam);iv=0;end
   if(n%240==239)begin iv=0;repeat(ROW_BLANK)@(negedge cam);end
  end
  @(negedge cam);iv=0;
  if(!defer_meta)begin
   @(negedge ddr);result=0;result[255:224]=id;result[223:208]=7;rv=1;
   @(negedge ddr);rv=0;
  end
 end endtask
 task render;input integer id;integer line,p;begin
  @(negedge hdmi);expected_id=id;expected_pixel=0;vs=1;
  repeat(6)@(negedge hdmi);vs=0;
  repeat(1000)@(negedge ddr);
  if(!selected_valid || selected!=(id-1)%4)begin errors=errors+1;$display("FAIL selected frame %0d slot=%0d",id,selected);end
  for(line=0;line<ROWS;line=line+1)begin
   for(p=0;p<1280;p=p+1)begin @(negedge hdmi);read_pixel=1;end
   @(negedge hdmi);read_pixel=0;repeat(370)@(negedge hdmi);
  end
  if(underflow || expected_pixel!=ROWS*1280)begin errors=errors+1;$display("FAIL display underflow=%b pixels=%0d",underflow,expected_pixel);end
 end endtask
 initial begin
  for(i=0;i<4*WORDS;i=i+1)memory[i]=0;
  repeat(10)@(negedge cam);rstn=1;enable_mc=1;
  send_frame(1,WORDS);wait(candidate_valid);
  // Actual reads and writes overlap, while the camera emits 3 words/4 clocks.
  fork render(1);begin wait(selected_valid);send_frame(2,WORDS);end join
  wait(candidate_meta[255:224]==2);
  fork render(2);begin wait(selected==1);send_frame(6,WORDS);end join
  send_frame(7,WORDS);wait(candidate_meta[255:224]==7);render(7);
  send_frame(8,100);repeat(1000)@(negedge ddr);
  if(candidate_meta[255:224]!=7)errors=errors+1;
  send_frame(9,WORDS);wait(candidate_meta[255:224]==9);render(9);
  if(overflow)begin errors=errors+1;$display("FAIL burst camera overflow");end
  if(errors==0 && pixel_checks==4*ROWS*1280)$display("SIMULATION_PASS transport_rate continuous_rows protected_slot pixel_checks=%0d",pixel_checks);
  else $display("SIMULATION_FAIL transport_rate errors=%0d pixels=%0d",errors,pixel_checks);
  $finish;
 end
 initial begin #20000000;$display("SIMULATION_FAIL transport timeout");$finish;end
endmodule
