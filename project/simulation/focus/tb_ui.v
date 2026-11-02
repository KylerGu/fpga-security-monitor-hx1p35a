`timescale 1ns/1ps
module tb_ui;
reg clk=0;always #5 clk=~clk;
reg rst=0,user=0,se=0,sr=0,sv=0;reg[20:0]s=0;reg[11:0]x=0,y=0;wire hit;wire[23:0]color;
integer i,errors=0;reg[10:0]oldpeak;
focus_assist dut(clk,rst,user,se,sr,sv,s,x,y,hit,color);
task frame;input integer val,exp,fresh;begin
 @(negedge clk);user=1;@(negedge clk);user=0;
 s={exp[9:0],val[10:0]};sv=fresh;@(negedge clk);sv=0;repeat(20)@(negedge clk);
end endtask
task check;input ok;input[255:0]label;begin if(ok!==1'b1)begin errors=errors+1;$display("FAIL %s",label);end end endtask
initial begin
 repeat(4)@(negedge clk);rst=1;se=1;
 for(i=0;i<15;i=i+1)frame(400,320,1);
 check(dut.ready && dut.peak==400,"settle constant");
 check(dut.cd==16'h0400 && dut.pd==16'h0400,"decimal display");
 for(i=0;i<8;i=i+1)frame(800,320,1);
 check(dut.peak>700 && dut.peak<800,"smooth rising");oldpeak=dut.peak;
 for(i=0;i<8;i=i+1)frame(100,320,1);
 check(dut.peak==oldpeak && dut.filtered[12:2]<200,"peak preserved falling");
 sr=1;for(i=0;i<4;i=i+1)frame(100,320,1);
 check(dut.peak==0 && !dut.ready,"switch reset edge");
 for(i=0;i<10;i=i+1)frame(100,320,1);check(dut.ready && dut.peak==100,"new reference");
 sr=0;for(i=0;i<4;i=i+1)frame(100,320,1);check(dut.peak==0 && !dut.ready,"reset reverse edge");
 for(i=0;i<10;i=i+1)frame(100,320,1);
 frame(800,321,1);check(!dut.ready && dut.peak==0,"exposure clears");
 for(i=0;i<7;i=i+1)frame(800,321,1);check(!dut.ready,"exposure holdoff");
 for(i=0;i<4;i=i+1)frame(800,321,1);check(dut.ready,"exposure settled");
 for(i=0;i<33;i=i+1)frame(800,321,0);check(!dut.ready && dut.peak==0,"stale clears");
 for(i=0;i<12;i=i+1)frame(100,321,1);check(dut.ready,"fresh recovery");
 se=0;for(i=0;i<4;i=i+1)frame(100,321,1);check(!dut.show && !dut.ready,"disabled");
 if(errors)begin $display("SIMULATION_FAIL ui errors=%0d",errors);$stop;end
 $display("SIMULATION_PASS focus_ui controls exposure_settle smooth peak reset stale recovery");$finish;
end
endmodule
