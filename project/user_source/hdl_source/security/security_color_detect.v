// Red target detection on the same normalized 4-pixel stream as the motion path.
// Ratio rule, so the decision tracks brightness: with d = R - max(G,B),
//   S0: R>=64, d>=32, d >= R/2       S1: R>=48, d>=24, d >= 3R/8 (default)
//   S2: R>=40, d>=16, d >= R/4       S3: R>=32, d>=12, d >= 3R/16
// level is the per-frame sensitivity, stable during the frame.
// An 8x8 block is red when at least PIX_MIN of its 64 pixels are red. A red block is
// counted only when its left or upper neighbour block is also red, so isolated noise
// blocks (sensor noise at high gain) cannot stretch the box; a real target loses at
// most its top-left corner block. The upper row's red flags are carried in bit 7 of
// the column accumulator words. The frame result is the bounding box of the counted
// blocks (block units, 160x90).
// Control/counter structure deliberately mirrors security_downsample4.
// Outputs accumulate during a frame, are final 5 cycles after the last input
// word and stay stable until the next frame_start (sampled by the motion publish).
module security_color_detect #(parameter WIDTH=1280,HEIGHT=720,
 parameter[6:0]PIX_MIN=7'd16,parameter[13:0]BLOCK_MIN=14'd4)(
 input wire clk,input wire rst,input wire frame_start,
 input wire in_valid,input wire line_last,input wire[95:0]rgb4,input wire[1:0]level,
 output reg complete,output wire found,output reg[13:0]red_blocks,
 output reg[7:0]bxmin,output reg[7:0]bxmax,output reg[6:0]bymin,output reg[6:0]bymax
);
 // Stage 2: {R, d} with d clamped to 0 when R is not the largest channel.
 function[15:0]chroma;input[23:0]p;reg[7:0]r,m;reg[8:0]d;begin
  r=p[23:16];m=p[15:8]>p[7:0] ? p[15:8] : p[7:0];
  d={1'b0,r}-{1'b0,m};
  chroma={r,d[8] ? 8'd0 : d[7:0]};
 end endfunction
 // Stage 3: ratio test for the selected level.
 function red;input[15:0]c;input[1:0]lv;reg[7:0]r,d;reg[11:0]r3,d16;begin
  r=c[15:8];d=c[7:0];
  r3={4'b0,r}+{3'b0,r,1'b0};d16={d,4'b0};
  case(lv)
   2'd0:red=r>=8'd64 && d>=8'd32 && {4'b0,d,1'b0}>={4'b0,r};
   2'd1:red=r>=8'd48 && d>=8'd24 && {1'b0,d,3'b0}>=r3;
   2'd2:red=r>=8'd40 && d>=8'd16 && {2'b0,d,2'b0}>={4'b0,r};
   default:red=r>=8'd32 && d>=8'd12 && d16>=r3;
  endcase
 end endfunction
 // Stage 1 matches the motion path's input registers; stages 2-3 hold pixel decisions.
 reg fs1=0,iv1=0,ll1=0,fs2=0,iv2=0,ll2=0,fs3=0,iv3=0,ll3=0;
 reg[95:0]rgb1=0;reg[63:0]c2=0;reg[3:0]hit3=0;
 always @(posedge clk)begin
  rgb1<=rgb4;
  c2<={chroma(rgb1[95:72]),chroma(rgb1[71:48]),chroma(rgb1[47:24]),chroma(rgb1[23:0])};
  hit3<={red(c2[63:48],level),red(c2[47:32],level),red(c2[31:16],level),red(c2[15:0],level)};
  if(rst)begin fs1<=0;iv1<=0;ll1<=0;fs2<=0;iv2<=0;ll2<=0;fs3<=0;iv3<=0;ll3<=0;end
  else begin fs1<=frame_start;iv1<=in_valid;ll1<=line_last;fs2<=fs1;iv2<=iv1;ll2<=ll1;
   fs3<=fs2;iv3<=iv2;ll3<=ll2;end
 end
 reg active=0,bad=0;
 reg[8:0]word_x=0;reg[9:0]row_y=0;
 reg[2:0]half_sum=0;
 wire[8:0]x=fs3 ? 9'd0 : word_x;
 wire[9:0]y=fs3 ? 10'd0 : row_y;
 wire take=iv3 && (active || fs3);
 wire expected_last=(x==WIDTH/4-1);
 wire good=take && (fs3 || !bad) && ll3==expected_last;
 wire[2:0]sum4={2'b0,hit3[3]}+{2'b0,hit3[2]}+{2'b0,hit3[1]}+{2'b0,hit3[0]};
 wire[3:0]sum8={1'b0,half_sum}+{1'b0,sum4};
 wire[19:0]column_sum;
 wire[6:0]vertical_sum=(y[2:0]==0 ? 7'd0 : column_sum[6:0])+{3'b0,sum8};
 wire red_now=vertical_sum>=PIX_MIN;                       // this block (valid at y[2:0]==7)
 wire up_red=column_sum[7] && y[9:3]!=0;                     // block above, same frame only
 reg left_red=0;                                             // previous block in this block row
 wire flag=y[2:0]==7 ? red_now : column_sum[7];              // keep the row flag until replaced
 PH1P_LOGIC_ERAM #(
  .DATA_WIDTH_A(20),.DATA_WIDTH_B(20),.ADDR_WIDTH_A(10),.ADDR_WIDTH_B(10),
  .DATA_DEPTH_A(1024),.DATA_DEPTH_B(1024),.MODE("DP"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG"),
  .RESETMODE_A("ASYNC"),.RESETMODE_B("ASYNC"),
  .WRITEMODE_A("NORMAL"),.WRITEMODE_B("NORMAL"),
  .CLKMODE("SYNC"),.IMPLEMENT("20K(FAST)"),
  .SSROVERCE("DISABLE"),.ASYNC_RESET_RELEASE_A("ASYNC"),.ASYNC_RESET_RELEASE_B("ASYNC"),
  .ECC_ENCODE("DISABLE"),.ECC_DECODE("DISABLE"),.INIT_FILE("NONE"),.FILL_ALL("NONE")
 ) accum (
  .clka(clk),.clkb(clk),.cea(good && x[0]),.wea(good && x[0]),
  .ceb(good && !x[0]),.web(1'b0),.ocea(1'b1),.oceb(1'b1),
  .addra({2'b0,x[8:1]}),.addrb({2'b0,x[8:1]}),
  .dia({12'b0,flag,vertical_sum}),.dib(20'b0),.rsta(1'b0),.rstb(1'b0),
  .bea(1'b0),.beb(1'b0),.doa(),.dob(column_sum),
  .ecc_sbiterr(),.ecc_dbiterr(),.ecc_sbiterrinj(1'b0),.ecc_dbiterrinj(1'b0)
 );
 reg blk_valid=0,blk_red=0,blk_end=0;reg[7:0]blk_x=0;reg[6:0]blk_y=0;
 always @(posedge clk)begin
  if(rst)begin
   active<=0;bad<=0;word_x<=0;row_y<=0;half_sum<=0;
   blk_valid<=0;blk_red<=0;blk_end<=0;blk_x<=0;blk_y<=0;left_red<=0;
  end else begin
   blk_valid<=0;blk_end<=0;
   if(fs3)begin active<=1;bad<=0;word_x<=0;row_y<=0;half_sum<=0;end
   if(take)begin
    if(ll3!=expected_last)bad<=1;
    if(good)begin
     if(!x[0])half_sum<=sum4;
     else if(y[2:0]==7)begin
      blk_valid<=1;blk_red<=red_now && (up_red || (left_red && x[8:1]!=0));left_red<=red_now;
      blk_x<=x[8:1];blk_y<=y[9:3];blk_end<=expected_last && y==HEIGHT-1;
     end
    end
    if(expected_last)begin
     word_x<=0;row_y<=y+1'b1;
     if(y==HEIGHT-1)active<=0;
    end else word_x<=x+1'b1;
   end
  end
 end
 assign found=complete && red_blocks>=BLOCK_MIN;
 always @(posedge clk)begin
  if(rst || fs3)begin
   complete<=0;red_blocks<=0;bxmin<=8'hff;bxmax<=0;bymin<=7'h7f;bymax<=0;
  end else if(blk_valid)begin
   if(blk_red)begin
    red_blocks<=red_blocks+1'b1;
    if(blk_x<bxmin)bxmin<=blk_x;
    if(blk_x>bxmax)bxmax<=blk_x;
    if(blk_y<bymin)bymin<=blk_y;
    if(blk_y>bymax)bymax<=blk_y;
   end
   if(blk_end)complete<=1;
  end
 end
endmodule
