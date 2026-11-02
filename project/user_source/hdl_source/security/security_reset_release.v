// Assert immediately; release only after three edges of the local clock.
// Only the first stage sees the asynchronous external release. The remaining
// stages and local reset distribution remain in ordinary timing analysis.
module security_reset_release(input wire clk,arst_n,output wire rst_n);
 (* async_reg="true" *) reg[2:0]release_pipe;
 always @(posedge clk or negedge arst_n)
  if(!arst_n)release_pipe<=0;
  else release_pipe<={release_pipe[1:0],1'b1};
 assign rst_n=release_pipe[2];
endmodule
