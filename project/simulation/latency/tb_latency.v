`timescale 1ns/1ps
// Latency visualisation sources:
//  - security_fps_meter: BCD frames per 1 s toggle window (25, 20, carry to 10, 01, saturate 99, stop -> 00)
//  - security_frame_manager: candidate_meta[66:63] = newest allocated frame - shown frame
//    (0,1,2,3 with the real slot rules, saturation at 9), other descriptor bits untouched.
module tb_latency;
 reg clk=0;always #5 clk=~clk;
 reg rstn=0,fs=0;wire[7:0]fps;
 // 1 s window = 1000 clocks, delivered as a toggle like control[58].
 reg sec=0;integer t=0;
 always @(posedge clk)if(rstn)begin t=t+1;if(t==1000)begin t=0;sec<=!sec;end end
 security_fps_meter meter(clk,rstn,fs,sec,fps);
 reg alloc=0,acc=0,rv=0;reg[1:0]aslot=0;reg[31:0]aframe=0,accf=0;reg[24:0]addr=0;reg[255:0]rd=0;
 wire cv,rej;wire[1:0]cs;wire[255:0]cm;
 security_frame_manager #(.WORDS(4)) mgr(clk,rstn,alloc,aslot,aframe,acc,addr,accf,rv,rd,cv,cs,cm,rej);
 integer errors=0,i,k;
 task pulses;input integer p,n;begin
  for(i=0;i<n;i=i+1)begin @(negedge clk);fs=(i%p==0);end
  @(negedge clk);fs=0;
 end endtask
 task check_fps;input[7:0]e;begin
  if(fps!==e)begin errors=errors+1;$display("FAIL fps=%h expected=%h",fps,e);end
 end endtask
 task allocate;input integer f;begin
  @(negedge clk);alloc=1;aslot=(f-1)%4;aframe=f;@(negedge clk);alloc=0;
 end endtask
 task fill;input integer f;begin
  for(k=0;k<4;k=k+1)begin @(negedge clk);acc=1;accf=f;addr=((f-1)%4)*7000000+8*k;end
  @(negedge clk);acc=0;
  @(negedge clk);rv=1;rd=0;rd[255:224]=f;rd[66:63]=4'hf;@(negedge clk);rv=0;
 end endtask
 task check_lag;input integer f,l;begin
  repeat(3)@(negedge clk);
  if(!cv || cm[255:224]!==f || cm[66:63]!==l || cm[223:67]!==0 || cm[62:0]!==0 || rej)begin
   errors=errors+1;$display("FAIL lag valid=%b frame=%0d lag=%0d expected frame=%0d lag=%0d",cv,cm[255:224],cm[66:63],f,l);end
 end endtask
 initial begin
  repeat(3)@(negedge clk);rstn=1;
  pulses(40,2500);check_fps(8'h25);
  pulses(50,2500);check_fps(8'h20);
  pulses(100,2500);check_fps(8'h10);
  pulses(1000,2500);check_fps(8'h01);
  pulses(7,2500);check_fps(8'h99);
  pulses(5000,2500);check_fps(8'h00);  // single pulse at start, then a full empty window
  allocate(1);fill(1);check_lag(1,0);
  allocate(2);check_lag(1,1);           // frame 2 being written, frame 1 shown
  fill(2);check_lag(2,0);
  allocate(3);allocate(4);check_lag(2,2);
  allocate(5);check_lag(2,3);           // reuses frame 1's slot
  allocate(20);check_lag(2,9);          // large gap saturates at 9
  if(errors==0)$display("SIMULATION_PASS latency fps_bcd carry saturate idle lag_frames saturate untouched_bits");
  else $display("SIMULATION_FAIL latency errors=%0d",errors);
  $finish;
 end
 initial begin #2000000;$display("SIMULATION_FAIL latency timeout");$finish;end
endmodule
