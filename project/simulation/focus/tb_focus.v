`timescale 1ns/1ps
module tb_focus;
reg clk=0;always #5 clk=~clk;
reg rst=0,v=0,u=0,last=0;reg[95:0]data=0;reg[1:0]mode=0;
wire[10:0]score;wire sv;integer seen=0,errors=0,lastscore;
edge_detect_96 dut(.I_clk(clk),.I_rst_n(rst),.I_tvalid(v),.I_tuser(u),.I_tlast(last),.I_tdata(data),.I_tready(1'b1),.I_mode(mode),.O_focus_score(score),.O_focus_valid(sv));
always @(posedge clk)begin #1;if(sv)begin seen=seen+1;lastscore=score;end end
function[7:0]pix;input integer xx,yy,kind;begin
 case(kind)
 0:pix=100;
 1:pix=(xx%16<8)?8'd30:8'd230;
 2:case(xx%16)0,15:pix=110;1,14:pix=90;2,13:pix=70;3,12:pix=50;4,11:pix=70;5,10:pix=90;6,9:pix=110;default:pix=130;endcase
 3:pix=100+((xx+yy)%3)-1;
 4:pix=(xx<480)?((xx%16<8)?30:230):100;
 default:pix=100;endcase
end endfunction
integer x,y,k,n,a,b;
task frame;input integer kind,rows;begin
 @(negedge clk);u=1;v=0;@(negedge clk);u=0;
 for(y=0;y<rows;y=y+1)begin
  for(x=0;x<1280;x=x+4)begin
   v=1;last=(x==1276);
   data={ {3{pix(x,y,kind)}},{3{pix(x+1,y,kind)}},{3{pix(x+2,y,kind)}},{3{pix(x+3,y,kind)}}};
   @(negedge clk);
   if(x==400)begin v=0;repeat(3)@(negedge clk);end
  end
  v=0;last=0;repeat(6)@(negedge clk);
 end
 v=0;repeat(10)@(negedge clk);
end endtask
initial begin
 repeat(5)@(negedge clk);rst=1;
 frame(0,720);if(seen!=1 || lastscore!=0)errors=errors+1;
 frame(1,720);a=lastscore;if(seen!=2 || a<100)errors=errors+1;
 frame(2,720);b=lastscore;if(seen!=3 || b>=a)errors=errors+1;
 frame(3,720);if(seen!=4 || lastscore!=0)errors=errors+1;
 frame(4,720);if(seen!=5 || lastscore!=0)errors=errors+1;
 frame(1,300);if(seen!=5)errors=errors+1;
 for(k=0;k<4;k=k+1)begin mode=k;frame(1,720);if(lastscore!=a)errors=errors+1;end
 if(seen!=9)errors=errors+1;
 if(errors)begin $display("SIMULATION_FAIL focus errors=%0d seen=%0d sharp=%0d blur=%0d",errors,seen,a,b);$stop;end
 $display("SIMULATION_PASS focus real_sobel sharp=%0d blur=%0d flat=0 weak_noise=0 outside_roi=0 incomplete_rejected modes4 stalls",a,b);$finish;
end
endmodule
