// Closed-loop auto exposure for the SC520CS.
//
// Exposure and gain are folded into one logarithmic level T (about 2-3 % per step):
//   T   0..191 : exposure = (32 + T[4:0]) << T[7:5] half-lines (32..2016, clamped to 1991), gain 1x
//   T 192..352 : exposure 1991 (maximum), gain-table input AG = 16 + (T-192)  (16..176, 32 steps/octave)
// T = 320 (exposure 1991, AG 144 = 16x analog) is the former fixed setting and is used whenever
// auto exposure is disabled (SW2 down).

// Camera domain: measure the mean of the motion path's 160x90 small gray image and
// step T toward TARGET. Only complete frames count; T moves at most once per INTERVAL
// frames, by 4 when outside +-FAR and by 1 when outside +-DEAD, so successive frames
// change brightness far less than the motion threshold.
module security_auto_exposure #(parameter PIXELS=14400,TARGET=110,DEAD=12,FAR=40,INTERVAL=4,
 parameter[8:0]FIXED=9'd320,MAX_LEVEL=9'd352)(
 input wire clk,rst_n,enable,
 input wire start,valid,last,abort,input wire[7:0]gray,
 output reg[8:0]level
);
 localparam integer LOW=(TARGET-DEAD)*PIXELS,HIGH=(TARGET+DEAD)*PIXELS;
 localparam integer LOW_FAR=(TARGET-FAR)*PIXELS,HIGH_FAR=(TARGET+FAR)*PIXELS;
 reg[21:0]sum;reg[13:0]count;reg[2:0]frames;reg ok;
 wire[21:0]total=sum+{14'd0,gray};
 wire frame_end=valid && last && ok && count==PIXELS-1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin sum<=0;count<=0;frames<=0;ok<=0;level<=FIXED;end
  else begin
   if(start)begin sum<=0;count<=0;ok<=1;end
   else begin
    if(abort)ok<=0;
    if(valid)begin sum<=total;count<=count+1'b1;end
   end
   if(!enable)begin level<=FIXED;frames<=0;end
   else if(frame_end && !start && !abort)begin
    if(frames==INTERVAL-1)begin
     frames<=0;
     if(total<LOW_FAR)level<=level>MAX_LEVEL-9'd4 ? MAX_LEVEL : level+9'd4;
     else if(total<LOW)level<=level==MAX_LEVEL ? MAX_LEVEL : level+9'd1;
     else if(total>HIGH_FAR)level<=level<9'd4 ? 9'd0 : level-9'd4;
     else if(total>HIGH)level<=level==0 ? 9'd0 : level-9'd1;
    end else frames<=frames+1'b1;
   end
  end
 end
endmodule

// 24 MHz sensor-configuration domain: map T to exposure / gain-table input and request
// one grouped register write (uicfgcs520 AE table) whenever the mapped values change.
// Same handshake as the vendor ae_set it replaces; starts from values that differ from
// any mapping so the first setting is always written after sensor initialisation.
module security_ae_writer(
 input wire clk,rst,cam_cfg_done,ae_cfg_done,input wire[8:0]level,
 output reg ae_req,output reg[15:0]ae,output reg[15:0]ag
);
 reg[15:0]map_ae,map_ag,shifted;
 always @*begin
  shifted={10'd0,1'b1,level[4:0]}<<level[7:5];
  if(level>=9'd192)begin
   map_ae=16'd1991;
   map_ag=level>=9'd352 ? 16'd176 : {7'd0,level}-16'd176;   // 16 + (T-192)
  end else begin
   map_ae=shifted>16'd1991 ? 16'd1991 : shifted;
   map_ag=16'd16;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin ae_req<=0;ae<=16'd1990;ag<=16'd17;end
  else if(ae_req)ae_req<=0;
  else if((ae!=map_ae || ag!=map_ag) && cam_cfg_done && ae_cfg_done)begin
   ae<=map_ae;ag<=map_ag;ae_req<=1;
  end
 end
endmodule
