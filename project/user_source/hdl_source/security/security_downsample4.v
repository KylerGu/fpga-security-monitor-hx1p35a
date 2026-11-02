// Normalized upstream interface: four adjacent 8-bit gray pixels per valid word.
// frame_start may precede pixels or accompany the first word. line_last marks
// the final 4-pixel word of each line. No back-pressure is required.
module security_downsample4 #(parameter WIDTH=1280,HEIGHT=720)(
 input wire clk,input wire rst,input wire frame_start,
 input wire in_valid,input wire line_last,input wire[31:0]gray4,
 output reg out_start,output reg out_valid,output reg out_last,
 output reg out_end,output reg out_abort,
 output reg[13:0]out_addr,output reg[7:0]out_gray
);
 reg active=0,bad=0;
 reg[8:0]word_x=0;reg[9:0]row_y=0;
 reg[9:0]half_sum=0;
 reg[13:0]small_addr=0;
 wire[8:0]x=frame_start ? 9'd0 : word_x;
 wire[9:0]y=frame_start ? 10'd0 : row_y;
 wire take=in_valid && (active || frame_start);
 wire expected_last=(x==WIDTH/4-1);
 wire good=take && (frame_start || !bad) && line_last==expected_last;
 wire[9:0]sum4={2'b0,gray4[31:24]}+{2'b0,gray4[23:16]}+
               {2'b0,gray4[15:8]}+{2'b0,gray4[7:0]};
 wire[10:0]sum8={1'b0,half_sum}+{1'b0,sum4};
 wire[19:0]row_sum;
 wire[13:0]vertical_sum=(y[2:0]==0 ? 14'd0 : row_sum[13:0])+{3'b0,sum8};
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
  .dia({6'b0,vertical_sum}),.dib(20'b0),.rsta(1'b0),.rstb(1'b0),
  .bea(1'b0),.beb(1'b0),.doa(),.dob(row_sum),
  .ecc_sbiterr(),.ecc_dbiterr(),.ecc_sbiterrinj(1'b0),.ecc_dbiterrinj(1'b0)
 );
 always @(posedge clk)begin
  if(rst)begin
   active<=0;bad<=0;word_x<=0;row_y<=0;half_sum<=0;small_addr<=0;
   out_start<=0;out_valid<=0;out_last<=0;out_end<=0;out_abort<=0;out_addr<=0;out_gray<=0;
  end else begin
   out_start<=frame_start;out_valid<=0;out_last<=0;out_end<=0;out_abort<=0;
   if(frame_start)begin
    if(active)out_abort<=1;
    active<=1;bad<=0;word_x<=0;row_y<=0;small_addr<=0;half_sum<=0;
   end
   if(take)begin
    if(line_last!=expected_last)begin bad<=1;out_abort<=1;end
    if(good)begin
     if(!x[0])half_sum<=sum4;
     else if(y[2:0]==7)begin
      out_valid<=1;out_gray<=vertical_sum[13:6];
      out_addr<=small_addr;small_addr<=small_addr+1'b1;
      out_last<=expected_last;
      out_end<=expected_last && y==HEIGHT-1;
     end
    end
    if(expected_last)begin
     word_x<=0;row_y<=y+1'b1;
     if(y==HEIGHT-1)active<=0;
    end else word_x<=x+1'b1;
   end
  end
 end
endmodule
