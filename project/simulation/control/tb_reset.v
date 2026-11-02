`timescale 1ns/1ps
module tb_reset;
 reg src=0,dst=0,rstn=1,send=0,latch=1;
 always #10 src=~src;
 always #4.830 dst=~dst;
 reg[31:0]data=0;wire ready,valid;wire[31:0]received;
 wire local_reset;
 security_reset_release release_check(src,rstn,local_reset);
 security_frame_cdc #(.WIDTH(32)) mailbox(src,dst,rstn,send,data,ready,latch,valid,received);
 integer errors=0,k,n;
 task transfer;input integer value;begin
  wait(ready);@(negedge src);data=value;send=1;
  @(negedge src);send=0;
  wait(valid);#1;if(received!==value)begin errors=errors+1;$display("FAIL reset mailbox got=%0d expected=%0d",received,value);end
  @(negedge dst);
 end endtask
 initial begin
  #0.1;rstn=0;
  for(k=0;k<12;k=k+1)begin
   rstn=0;send=0;#1;
   if(local_reset!==0)errors=errors+1;
   // Fractional phase avoids a zero-time simulation race on the clock edge.
   repeat(4)@(negedge src);#(k+0.37);rstn=1;
   for(n=0;n<3;n=n+1)begin
    @(posedge src);#1;
    if(local_reset!==(n==2))begin errors=errors+1;$display("FAIL reset release phase=%0d edge=%0d value=%b",k,n,local_reset);end
   end
   repeat(6)@(negedge src);latch=1;transfer(100+k);
   // Reset while a whole descriptor is pending; it must not reappear later.
   latch=0;wait(ready);@(negedge src);data=999;send=1;
   @(negedge src);send=0;repeat(4)@(negedge dst);
   #2;rstn=0;#1;if(local_reset!==0)errors=errors+1;
   repeat(4)@(negedge src);#3;rstn=1;
   repeat(6)@(negedge src);latch=1;transfer(200+k);
  end
  if(errors==0)$display("SIMULATION_PASS reset asynchronous_assert local_release3 mailbox_pending_reset phases12");
  else $display("SIMULATION_FAIL reset errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("SIMULATION_FAIL reset timeout");$finish;end
endmodule
