module security_controls #(parameter DEBOUNCE=1000000,LONG_PRESS=100000000,CLOCKS_PER_SEC=50000000)(
 input wire clk,rst_n,input wire[2:0]key_n,input wire setup_switch,
 output reg[1:0]mode,output wire[63:0]control,input wire ae_switch
);
 // [58] 1 Hz toggle from this (crystal) clock: frame-rate window in the camera domain.
 // [57] SW2 auto exposure enable (up = on), synchronised.
 (* async_reg="true" *)reg ae1,ae2;reg second;reg[25:0]second_count;
 (* async_reg="true" *)reg[3:0]sync1,sync2;
 reg[3:0]stable;reg[19:0]deb[0:3];
 wire[3:0]raw={setup_switch,key_n};
 wire[3:0]change={(sync2[3]!=stable[3] && deb[3]==DEBOUNCE-1),
  (sync2[2]!=stable[2] && deb[2]==DEBOUNCE-1),
  (sync2[1]!=stable[1] && deb[1]==DEBOUNCE-1),
  (sync2[0]!=stable[0] && deb[0]==DEBOUNCE-1)};
 wire[2:0]press=change[2:0]&~sync2[2:0];
 wire release4=change[2] && sync2[2];
 reg[26:0]held;reg long_done;
 reg pass_view; // control[59]: PASS scene, reuses RAW pixels
 reg armed,clear_toggle;reg[1:0]item,sens;
 reg[7:0]rx,ry,rw,rh;reg[15:0]version;
 integer i;
 // [56:55] red-detection sensitivity S0..S3 (KEY3 while in RAW cycles it; default S2,
 // chosen from 2026-10-26 board test: unlit red N=99 at S2, 0 at S1; S3 background 1-2 blocks).
 assign control={4'b0,pass_view,second,ae2,sens,version,rx,ry,rw,rh,item,stable[3],armed,clear_toggle,2'b0};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin sync1<=4'b0111;sync2<=4'b0111;stable<=4'b0111;
   for(i=0;i<4;i=i+1)deb[i]<=0;
   held<=0;long_done<=0;armed<=0;clear_toggle<=0;item<=0;sens<=2;
   rx<=40;ry<=22;rw<=80;rh<=45;version<=0;mode<=0;pass_view<=0;
   ae1<=0;ae2<=0;second<=0;second_count<=0;
  end else begin
   ae1<=ae_switch;ae2<=ae1;
   if(second_count==CLOCKS_PER_SEC-1)begin second_count<=0;second<=!second;end
   else second_count<=second_count+1'b1;
   sync1<=raw;sync2<=sync1;
   for(i=0;i<4;i=i+1)begin
    if(sync2[i]==stable[i])deb[i]<=0;
    else if(deb[i]==DEBOUNCE-1)begin stable[i]<=sync2[i];deb[i]<=0;end
    else deb[i]<=deb[i]+1'b1;
   end
   if(stable[2])held<=0;else if(held<LONG_PRESS)held<=held+1'b1;
   if(press[2])long_done<=0;
   if(!stable[2] && held==LONG_PRESS-1 && !long_done)begin
    long_done<=1;if(!stable[3])clear_toggle<=!clear_toggle;
   end
   if(change[3])begin armed<=0;version<=version+1'b1;held<=0;long_done<=1;end
   else if(stable[3])begin
    if(press[0])item<=item+1'b1;
    if(press[1] || press[2])begin
     case(item)
      0:if(press[1] && rx>0)begin rx<=rx-1'b1;version<=version+1'b1;end
        else if(press[2] && {1'b0,rx}+{1'b0,rw}<160)begin rx<=rx+1'b1;version<=version+1'b1;end
      1:if(press[1] && ry>0)begin ry<=ry-1'b1;version<=version+1'b1;end
        else if(press[2] && {1'b0,ry}+{1'b0,rh}<90)begin ry<=ry+1'b1;version<=version+1'b1;end
      2:if(press[1] && rw>8)begin rw<=rw-1'b1;version<=version+1'b1;end
        else if(press[2] && {1'b0,rx}+{1'b0,rw}<160)begin rw<=rw+1'b1;version<=version+1'b1;end
      3:if(press[1] && rh>8)begin rh<=rh-1'b1;version<=version+1'b1;end
        else if(press[2] && {1'b0,ry}+{1'b0,rh}<90)begin rh<=rh+1'b1;version<=version+1'b1;end
     endcase
    end
   end else begin
    if(press[1])begin
     if(mode==0 && !pass_view)sens<=sens+1'b1;
     else begin mode<=0;pass_view<=0;end
    end else if(press[0])begin
     if(pass_view)begin mode<=0;pass_view<=0;end
     else case(mode)
      0:mode<=3;3:mode<=1;1:mode<=2;
      default:begin mode<=0;pass_view<=1;end
     endcase
    end
    if(release4 && !long_done)armed<=!armed;
   end
  end
 end
endmodule
