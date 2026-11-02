`timescale 1ns/1ps
// Real production interpolation arithmetic; synthetic known BGGR sensor tiles.
module tb_bayer_channels;
 reg clk=0,rst=0,v=0,user=0,last=0,yp=0;
 reg[95:0]above=0,middle=0,below=0;
 wire[127:0]out;wire ov,ou,ol,ready;
 bilinear_interpolation #(.BAYER_MODE("BGGR")) dut(clk,rst,last,user,v,ready,yp,above,middle,below,ol,ou,out,ov,1'b1);
 always #5 clk=~clk;
 reg[127:0]queue[0:511];integer head=0,tail=0,errors=0,checks=0;
 reg[23:0]rgb=0;
 always @(posedge clk)if(rst)begin
  if(v)begin queue[tail]={4{8'd0,rgb}};tail=tail+1;end
  #1;if(ov)begin
   if(out!==queue[head])begin errors=errors+1;if(errors<5)$display("Bayer mismatch %h expected %h",out,queue[head]);end
   head=head+1;checks=checks+4;
  end
 end
 function[7:0]mosaic;
 input integer yy,xx;input[23:0]c;
 begin
  if(yy%2==0 && xx%2==0)mosaic=c[7:0];
  else if(yy%2!=0 && xx%2!=0)mosaic=c[23:16];
  else mosaic=c[15:8];
 end endfunction
 integer row,col,beat,parity,kind;
 reg[95:0]rows[0:2];
 initial begin
  repeat(3)@(negedge clk);rst=1;
  for(kind=0;kind<5;kind=kind+1)for(parity=0;parity<2;parity=parity+1)begin
   @(negedge clk);
   case(kind)0:rgb=24'h123456;1:rgb=24'hc82814;2:rgb=24'h1478c8;3:rgb=24'hffffff;4:rgb=0;endcase
   for(row=0;row<3;row=row+1)begin
    rows[row]=0;
    for(col=0;col<6;col=col+1)rows[row][64-col*8+:8]=mosaic(parity+row+1,col+1,rgb);
   end
   above=rows[0];middle=rows[1];below=rows[2];yp=parity;
   for(beat=0;beat<16;beat=beat+1)begin v=1;last=beat==15;@(negedge clk);end
   v=0;last=0;repeat(10)@(negedge clk);
  end
  if(errors || head!=tail || checks!=640)$display("SIMULATION_FAIL bayer_channels errors=%0d pixels=%0d",errors,checks);
  else $display("SIMULATION_PASS bayer_channels actual_BGGR both_row_parities red_green_blue white_black pixels=%0d",checks);
  $finish;
 end
endmodule
