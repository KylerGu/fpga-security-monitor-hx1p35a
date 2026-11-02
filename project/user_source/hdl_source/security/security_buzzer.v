// HX1P35A C12 drives a PNP transistor: high is silent, low energizes it.
// Use the existing 50 MHz system clock, with clock enables (no new clock).
module security_buzzer #(parameter integer CLOCK_HZ=50000000,TONE_HZ=2000)(
 input wire clk,rst_n,enable,
 output wire buzzer_n
);
 localparam integer HALF_PERIOD=CLOCK_HZ/(2*TONE_HZ);
 localparam integer COUNTER_BITS=(HALF_PERIOD>1)?$clog2(HALF_PERIOD):1;
 reg[COUNTER_BITS-1:0]count;
 reg tone_n;
 // Force the inactive level even if reset/disable arrives between clock edges.
 assign buzzer_n=(!rst_n || !enable)?1'b1:tone_n;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin count<=0;tone_n<=1;end
  else if(!enable)begin count<=0;tone_n<=1;end
  else if(count==HALF_PERIOD-1)begin count<=0;tone_n<=!tone_n;end
  else count<=count+1'b1;
 end
endmodule
