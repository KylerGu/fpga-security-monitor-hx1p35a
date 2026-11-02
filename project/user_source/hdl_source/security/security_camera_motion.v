module security_camera_motion #(parameter WIDTH=1280,HEIGHT=720,CLOCKS_PER_MS=50000,
 LIGHT_QUAD_MIN=(WIDTH/16)*(HEIGHT/16)*2/5,LIGHT_HOLD=30)(
 input wire clk,rst_n,input wire frame_start,in_valid,line_last,
 input wire[95:0]rgb4,input wire[1:0]mode,input wire[63:0]control,
 output reg[31:0]frame_id,output reg result_valid,output reg[255:0]result_data,
 output wire alarm,output wire armed_status,output wire interrupted,
 input wire ref_clk,ref_rst_n,input wire[63:0]ref_control
);
 wire[15:0]version=control[54:39];
 wire[7:0]rx=control[38:31],ry=control[30:23],rw=control[22:15],rh=control[14:7];
 wire[1:0]edit_item=control[6:5];
 wire setting=control[4],armed=control[3],clear_toggle=control[2];
 assign armed_status=ref_control[3] && !ref_control[4];
 (* async_reg="true" *)reg interrupted1,interrupted2;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin interrupted1<=1;interrupted2<=1;end
  else begin interrupted1<=interrupted;interrupted2<=interrupted1;end
 end
 reg fs,iv,ll;reg[31:0]gray4;
 function[7:0]gray;input[23:0]p;reg[9:0]s;begin
  s={2'b0,p[23:16]}+{1'b0,p[15:8],1'b0}+{2'b0,p[7:0]};gray=s[9:2];
 end endfunction
 reg[15:0]frame_version;reg[7:0]fx,fy,fw,fh;reg[1:0]frame_mode,frame_item;
 reg frame_pass; // descriptor[17], paired with this captured picture
 reg frame_setting,history_dirty,frame_ae;reg[1:0]frame_sens;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin fs<=0;iv<=0;ll<=0;gray4<=0;frame_id<=0;frame_version<=0;
   fx<=40;fy<=22;fw<=80;fh<=45;frame_mode<=0;frame_item<=0;frame_setting<=0;history_dirty<=1;frame_sens<=0;frame_ae<=0;frame_pass<=0;end
  else begin
   fs<=frame_start;iv<=in_valid;ll<=line_last;
   gray4<={gray(rgb4[95:72]),gray(rgb4[71:48]),gray(rgb4[47:24]),gray(rgb4[23:0])};
   if(frame_start)begin
    frame_id<=frame_id+1'b1;frame_version<=version;fx<=rx;fy<=ry;fw<=rw;fh<=rh;
    frame_mode<=mode;frame_item<=edit_item;frame_setting<=setting;frame_sens<=control[56:55];frame_ae<=control[57];frame_pass<=control[59];
    history_dirty<=version!=frame_version || interrupted2 || setting;
   end
  end
 end
 wire ss,sv,sl,se,sa,dv,dl,done,fault,busy;
 wire[13:0]a,da;wire[7:0]g,cur,prev,difference;
 security_downsample4 #(WIDTH,HEIGHT) scaler(clk,!rst_n,fs,iv,ll,gray4,ss,sv,sl,se,sa,a,g);
 // The scaler updates g on the rising edge; the frame store consumes it on the
 // next rising edge. Capture the same byte halfway between those edges so its
 // direct ERAM write-data path has half a cycle of hold margin. Valid/address
 // and the frame-difference pipeline retain their original rising-edge timing.
 reg[7:0]cache_gray_hold;
 always @(negedge clk or negedge rst_n)begin
  if(!rst_n)cache_gray_hold<=0;
  else cache_gray_hold<=g;
 end
 security_frame_diff #((WIDTH/8)*(HEIGHT/8)) cache(clk,!rst_n,ss,sa||(ss&&history_dirty),sv,se,a,cache_gray_hold,
   dv,dl,da,cur,prev,difference,done,fault,busy);
 reg[7:0]x,y,xmin,ymin,xmax,ymax;
 reg[13:0]all_count,region_count,diff_count;
 wire moving=difference>8'd20;
 wire inside=x>=fx && {1'b0,x}<{1'b0,fx}+{1'b0,fw} &&
             y>=fy && {1'b0,y}<{1'b0,fy}+{1'b0,fh};
 wire detector_valid=diff_count==(WIDTH/8)*(HEIGHT/8);
 // Global light change: every quadrant of the small image has at least
 // LIGHT_QUAD_MIN moving pixels (default 40%). A person near the lens rarely
 // covers all four quadrants, so local motion is still counted. The light
 // frame and the following LIGHT_HOLD frames (exposure settling) are not
 // counted as motion; descriptor bit [23] reports the suppression.
 reg[11:0]quad0,quad1,quad2,quad3;reg[3:0]quad_full;
 reg[7:0]light_hold;reg light_frame;
 wire[1:0]quad={y>=HEIGHT/16,x>=WIDTH/16};
 wire light_now=detector_valid && &quad_full;
 wire light_block=light_now || light_hold!=0;
 wire alarm_request_ready,alarm_reply_valid;wire[26:0]alarm_reply;
 security_alarm_bridge #(.CLOCKS_PER_MS(CLOCKS_PER_MS)) events(
  clk,rst_n,ref_clk,ref_rst_n,ref_control[3],ref_control[4],ref_control[2],
  done,region_count>=8 && !light_block,detector_valid,
  alarm_request_ready,alarm_reply_valid,alarm_reply,alarm,interrupted);
 // Red target detection shares the raw stream; results ride in descriptor bits [62:24],
 // the per-frame sensitivity level in [22:21].
 wire color_complete,color_found;wire[13:0]color_blocks;
 wire[7:0]color_xmin,color_xmax;wire[6:0]color_ymin,color_ymax;
 security_color_detect #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) color(clk,!rst_n,frame_start,in_valid,line_last,rgb4,frame_sens,
   color_complete,color_found,color_blocks,color_xmin,color_xmax,color_ymin,color_ymax);
 wire[6:0]color_blocks7=color_blocks>14'd127 ? 7'd127 : color_blocks[6:0];
 // Camera frame rate, BCD frames per second (descriptor [74:67]); the 1 s window is
 // control[58], toggled from the 50 MHz crystal domain.
 wire[7:0]fps_bcd;
 security_fps_meter fps(clk,rst_n,frame_start,control[58],fps_bcd);
 // Auto exposure level T (descriptor {[80:75],[20:18]}, enable in [81]); see security_auto_exposure.
 wire[8:0]ae_level;
 // Board test 2026-10-26: target 110 / ceiling 352 settles a normal room near T=335 (~22x gain);
 // brighter and judged clearer than the former fixed T=320 despite more visible noise.
 security_auto_exposure #(.PIXELS((WIDTH/8)*(HEIGHT/8)),.TARGET(110),.MAX_LEVEL(9'd352)) exposure(clk,rst_n,control[57],ss,sv,se,sa,g,ae_level);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin x<=0;y<=0;xmin<=255;ymin<=255;xmax<=0;ymax<=0;
   all_count<=0;region_count<=0;diff_count<=0;result_valid<=0;result_data<=0;
   quad0<=0;quad1<=0;quad2<=0;quad3<=0;quad_full<=0;light_hold<=0;light_frame<=0;end
  else begin
   result_valid<=0;
   if(ss)begin x<=0;y<=0;xmin<=255;ymin<=255;xmax<=0;ymax<=0;
    all_count<=0;region_count<=0;diff_count<=0;
    quad0<=0;quad1<=0;quad2<=0;quad3<=0;quad_full<=0;end
   if(dv)begin
    diff_count<=diff_count+1'b1;
    if(x==WIDTH/8-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
    if(moving)begin
     all_count<=all_count+1'b1;
     if(inside)region_count<=region_count+1'b1;
     if(x<xmin)xmin<=x;if(x>xmax)xmax<=x;
     if(y<ymin)ymin<=y;if(y>ymax)ymax<=y;
     case(quad)
      2'd0:begin quad0<=quad0+1'b1;if(quad0==LIGHT_QUAD_MIN-1)quad_full[0]<=1'b1;end
      2'd1:begin quad1<=quad1+1'b1;if(quad1==LIGHT_QUAD_MIN-1)quad_full[1]<=1'b1;end
      2'd2:begin quad2<=quad2+1'b1;if(quad2==LIGHT_QUAD_MIN-1)quad_full[2]<=1'b1;end
      default:begin quad3<=quad3+1'b1;if(quad3==LIGHT_QUAD_MIN-1)quad_full[3]<=1'b1;end
     endcase
    end
   end
   if(done)begin
    light_frame<=light_block;
    if(light_now)light_hold<=LIGHT_HOLD;
    else if(light_hold!=0)light_hold<=light_hold-1'b1;
   end
   // Save the completed frame before requesting its crystal-domain decision.
   // Alarm fields are filled from the coherent response below, then published.
   if(done && alarm_request_ready)begin
    result_data<={frame_id,frame_version,frame_mode,detector_valid,all_count>=8,
       armed,1'b0,frame_setting,frame_item,1'b0,24'b0,
       fx,fy,fw,fh,xmin,ymin,xmax,ymax,region_count,all_count,
       frame_ae,ae_level[8:3],fps_bcd,4'b0,color_complete,color_found,color_xmin,color_xmax,color_ymin,color_ymax,color_blocks7,light_block,frame_sens,ae_level[2:0],frame_pass,17'b0};
   end
   if(alarm_reply_valid)begin
    result_valid<=1;
    result_data[203:202]<=alarm_reply[26:25];
    result_data[198]<=alarm_reply[24];
    result_data[197:174]<=alarm_reply[23:0];
   end
  end
 end
endmodule

// Frames started per second, counted in BCD (saturates at 99). Each change of
// `second` (a 1 Hz toggle from the crystal clock) closes a window and holds its count.
module security_fps_meter(
 input wire clk,rst_n,frame_start,second,output reg[7:0]fps_bcd
);
 reg second_d;reg[7:0]count;
 wire inc=frame_start && count!=8'h99;
 wire[7:0]next=!inc ? count : count[3:0]==4'd9 ? {count[7:4]+4'd1,4'd0} : {count[7:4],count[3:0]+4'd1};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin second_d<=0;count<=0;fps_bcd<=0;end
  else begin
   second_d<=second;
   if(second!=second_d)begin fps_bcd<=next;count<=0;end
   else count<=next;
  end
 end
endmodule
