`timescale 1ns/1ps
// Red target detection through the real motion module: block threshold,
// ratio colour rule at all four sensitivity levels (exact boundaries), bounding box,
// descriptor packing (level in [22:21]) and frame association.
module tb_color_detect;
 reg clk=0;always #4.830 clk=~clk;
 reg rstn=0,fs=0,iv=0,ll=0;reg[95:0]rgb=0;reg[1:0]mode=2;
 reg[63:0]ctrl={9'b0,16'd7,8'd1,8'd1,8'd4,8'd4,2'd0,1'b0,1'b1,1'b0,2'b0};
 wire[31:0]fid;wire rv,alarm,armed,interrupt;wire[255:0]meta;
 security_camera_motion #(64,64,3) dut(clk,rstn,fs,iv,ll,rgb,mode,ctrl,fid,rv,meta,alarm,armed,interrupt,clk,rstn,ctrl);
 integer errors=0,results=0,starts=0,i;
 integer expect_scene[0:15],expect_level[0:15];
 // Scenes on a 64x64 frame (8x8 blocks of 8x8 pixels).
 function[23:0]pixel;input integer s,px,py;begin
  pixel=24'h808080;
  case(s)
   // 3x3 full red blocks (2..4,3..5), whose top-left corner has no red neighbour; block (5,4)
   // exactly 16 red px next to it; block (0,7) only 12 px; block (7,0) fully red but isolated.
   1:if((px>=16&&px<40&&py>=24&&py<48)||(px>=40&&px<44&&py>=32&&py<36)||(px<4&&py>=56&&py<59)||(px>=56&&py<8))pixel=24'hc82828;
   // only 3 red blocks: below the 4-block found threshold
   2:if(px>=8&&px<32&&py>=8&&py<16)pixel=24'hc82828;
   // S0: orange d=40 < R/2, and dark red R=60 below 64: neither is red
   3:begin if(px>=16&&px<40&&py>=24&&py<48)pixel=24'hc8a028;if(px>=40&&py<24)pixel=24'h3c0000;end
   // S0 exact: R=96, d=48 = R/2 over the last 4x4 blocks (includes final block)
   4:if(px>=32&&py>=32)pixel=24'h603030;
   // level boundaries on the same 4x4 blocks: 5 exact at S1 (d=42, 8d=3R=336),
   // 6 exact at S2 (R=64, d=16=R/4), 7 exact at S3 (R=64, d=12, 16d=3R=192)
   5:if(px>=32&&py>=32)pixel=24'h704646;
   6:if(px>=32&&py>=32)pixel=24'h403030;
   7:if(px>=32&&py>=32)pixel=24'h403434;
  endcase
 end endfunction
 task check_result;input integer s,lv;reg ok,f;reg[7:0]x0,x1;reg[6:0]y0,y1,n;begin
  ok=1;f=0;x0=8'hff;x1=0;y0=7'h7f;y1=0;n=0;
  case(s)
   1:begin f=1;x0=2;x1=5;y0=3;y1=5;n=9;end           // 8 of the 3x3 + (5,4); (7,0) rejected
   2:begin x0=2;x1=3;y0=1;y1=1;n=2;end               // row of 3: first block has no neighbour
   4:begin f=1;x0=4;x1=7;y0=4;y1=7;n=15;end
   5,6,7:if(lv>=s-4)begin f=1;x0=4;x1=7;y0=4;y1=7;n=15;end
  endcase
  if(meta[255:224]!=starts || meta[62]!==ok || meta[61]!==f || meta[60:53]!==x0 || meta[52:45]!==x1 ||
     meta[44:38]!==y0 || meta[37:31]!==y1 || meta[30:24]!==n || meta[81:75]!==7'd40 ||   /* AE off: level 320 -> {[80:75],[20:18]}={40,0} */ meta[66:63]!==0 || meta[23]!==0 || meta[22:21]!==lv || meta[20:0]!==0)begin
   errors=errors+1;
   $display("FAIL color scene=%0d level=%0d id=%0d/%0d ok=%b found=%b x=%0d..%0d y=%0d..%0d n=%0d",s,lv,meta[255:224],starts,
     meta[62],meta[61],meta[60:53],meta[52:45],meta[44:38],meta[37:31],meta[30:24]);
  end
 end endtask
 always @(posedge clk)begin #1;if(rv)begin check_result(expect_scene[results],expect_level[results]);results=results+1;end end
 task frame;input integer s;input integer broken;integer w,px,py;begin
  starts=starts+1;
  @(negedge clk);fs=1;iv=0;@(negedge clk);fs=0;
  for(w=0;w<1024;w=w+1)begin
   px=(w%16)*4;py=w/16;
   @(negedge clk);iv=1;ll=(w%16==15)^(broken!=0 && w==16*20+3);
   rgb={pixel(s,px,py),pixel(s,px+1,py),pixel(s,px+2,py),pixel(s,px+3,py)};
  end
  @(negedge clk);iv=0;ll=0;repeat(64)@(negedge clk);
 end endtask
 initial begin
  expect_scene[0]=0;expect_scene[1]=1;expect_scene[2]=2;expect_scene[3]=3;
  expect_scene[4]=4;expect_scene[5]=0;expect_scene[6]=4;
  for(i=0;i<7;i=i+1)expect_level[i]=0;
  expect_scene[7]=5;expect_level[7]=0;expect_scene[8]=5;expect_level[8]=1;
  expect_scene[9]=6;expect_level[9]=1;expect_scene[10]=6;expect_level[10]=2;
  expect_scene[11]=7;expect_level[11]=2;expect_scene[12]=7;expect_level[12]=3;
  expect_scene[13]=1;expect_level[13]=3;
  repeat(6)@(negedge clk);rstn=1;
  frame(0,0);frame(1,0);frame(2,0);frame(3,0);frame(4,0);
  frame(1,1);   // broken line length: no result may be published for it
  frame(0,0);frame(4,0);
  // Sensitivity changes between frames take effect from the next frame.
  frame(5,0);ctrl[56:55]=1;frame(5,0);frame(6,0);ctrl[56:55]=2;frame(6,0);
  frame(7,0);ctrl[56:55]=3;frame(7,0);frame(1,0);
  if(results!=14)begin errors=errors+1;$display("FAIL color result count=%0d",results);end
  if(errors==0)$display("SIMULATION_PASS color_detect block_threshold colour_threshold bbox isolated_rejected packing frame_association levels_S0_S3 results=%0d",results);
  else $display("SIMULATION_FAIL color_detect errors=%0d",errors);
  $finish;
 end
 initial begin #2000000;$display("SIMULATION_FAIL color_detect timeout");$finish;end
endmodule
