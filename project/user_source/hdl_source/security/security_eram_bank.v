// One 16K x 8 bank, explicitly split into eight 2048 x 10 ERAM20K blocks.
// Both ports use the same clock; A writes, B reads with its output register.
// There is no behavioral RAM substitute in the vendor-model verification.
module security_eram_bank (
 input wire clk,
 input wire wr_en, input wire [13:0] wr_addr, input wire [7:0] wr_data,
 input wire rd_en, input wire [13:0] rd_addr,
 output wire [7:0] rd_data
);
 wire [9:0] q [0:7];
 reg [2:0] select0, select1;
 always @(posedge clk) begin
  select0 <= rd_addr[13:11];
  select1 <= select0;
 end
 genvar g;
 generate for(g=0;g<8;g=g+1) begin: blocks
  PH1P_LOGIC_ERAM #(
   .DATA_WIDTH_A(10), .DATA_WIDTH_B(10),
   .ADDR_WIDTH_A(11), .ADDR_WIDTH_B(11),
   .DATA_DEPTH_A(2048), .DATA_DEPTH_B(2048),
   .MODE("DP"), .REGMODE_A("NOREG"), .REGMODE_B("OUTREG"),
   .WRITEMODE_A("NORMAL"), .WRITEMODE_B("NORMAL"),
   .RESETMODE_A("ASYNC"), .RESETMODE_B("SYNC"),
   .OREGSET_A("RESET"), .OREGSET_B("RESET"),
   .ASYNC_RESET_RELEASE_A("ASYNC"), .ASYNC_RESET_RELEASE_B("ASYNC"),
   .CLKMODE("SYNC"), .IMPLEMENT("20K(FAST)"),
   .ECC_ENCODE("DISABLE"), .ECC_DECODE("DISABLE"),
   .SSROVERCE("DISABLE"), .INIT_FILE("NONE"), .FILL_ALL("NONE")
  ) ram (
   .clka(clk), .clkb(clk),
   .cea(wr_en && wr_addr[13:11]==g), .ceb(rd_en && rd_addr[13:11]==g),
   .ocea(1'b1), .oceb(1'b1),
   .wea(wr_en && wr_addr[13:11]==g), .web(1'b0),
   .addra(wr_addr[10:0]), .addrb(rd_addr[10:0]),
   .dia({2'b0,wr_data}), .dib(10'b0),
   .rsta(1'b0), .rstb(1'b0), .bea(1'b0), .beb(1'b0),
   .doa(), .dob(q[g]),
   .ecc_sbiterr(), .ecc_dbiterr(), .ecc_sbiterrinj(1'b0), .ecc_dbiterrinj(1'b0)
  );
 end endgenerate
 assign rd_data=q[select1][7:0];
endmodule
