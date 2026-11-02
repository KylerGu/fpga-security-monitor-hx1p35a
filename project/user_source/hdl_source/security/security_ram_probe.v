// Standalone measurable storage: both banks remain live and observable.
module security_ram_probe (
 input wire clk, input wire rst,
 input wire wr_en, input wire wr_bank,
 input wire [13:0] wr_addr, input wire [7:0] wr_data,
 input wire rd_en, input wire rd_bank, input wire [13:0] rd_addr,
 output wire [7:0] rd_data, output wire rd_valid
);
 wire [7:0] q0,q1;
 reg [1:0] valid_pipe,bank_pipe;
 always @(posedge clk) begin
  if(rst) begin valid_pipe<=0; bank_pipe<=0; end
  else begin
   valid_pipe<={valid_pipe[0],rd_en};
   bank_pipe<={bank_pipe[0],rd_bank};
  end
 end
 security_eram_bank b0(clk,wr_en && !wr_bank,wr_addr,wr_data,
                       rd_en && !rd_bank,rd_addr,q0);
 security_eram_bank b1(clk,wr_en && wr_bank,wr_addr,wr_data,
                       rd_en && rd_bank,rd_addr,q1);
 assign rd_data=bank_pipe[1] ? q1 : q0;
 assign rd_valid=valid_pipe[1];
endmodule
