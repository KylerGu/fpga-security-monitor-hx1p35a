// Red-target box and status line for the HDMI mixer.
// Inputs x,y are the mixer's stage-0 counters; hit/color are registered twice
// so they align with the mixer's S_x_2d/S_y_2d output stage.
// The display descriptor is constant during an active picture, so derived
// geometry is simply re-registered every cycle. Coordinates are converted to
// decimal by a short sequential converter started at each frame's first pixel.
// Descriptor bits: [62] complete, [61] found, [60:53] xmin, [52:45] xmax,
// [44:38] ymin, [37:31] ymax (8x8 block units), [30:24] red block count (<=127),
// [22:21] sensitivity level, shown as S0..S3 at the end of the line.
// Third line (y=72): `FPS nn LAT nF` from [74:67] camera fps (BCD) and [66:63]
// display lag in frames; hidden while fps is 0 (no measurement yet). It ends with
// `AE ttt` (auto exposure on, [81]) or `FX ttt` (fixed), ttt = level {[80:75],[20:18]}.
module security_color_overlay_reference(
 input wire clk,input wire rst_n,input wire user,
 input wire[11:0]x,input wire[11:0]y,
 input wire valid,input wire[255:0]meta,
 output reg hit,output reg[23:0]color
);
 localparam[11:0]TX=12'd700,TY=12'd48,TW=12'd336,TH=12'd16,TY2=12'd72,TW2=12'd320;
 localparam[23:0]BOX=24'hff40ff,TEXT_FOUND=24'hff6060,TEXT_NONE=24'hb0b0b0,BACK=24'h102030,PERF=24'h60e0ff;
 wire[7:0]bxmin=meta[60:53],bxmax=meta[52:45];
 wire[6:0]bymin=meta[44:38],bymax=meta[37:31],blocks=meta[30:24];
 wire[8:0]xsum={1'b0,bxmin}+{1'b0,bxmax}+9'd1;
 wire[7:0]ysum={1'b0,bymin}+{1'b0,bymax}+8'd1;
 reg en,found,en2,ae_on;reg[1:0]sens;reg[7:0]fps;reg[3:0]lag;reg[8:0]ae_level;
 reg[11:0]bl,br,bt,bb,bli,bri,bti,bbi;
 reg[10:0]xbin;reg[9:0]ybin;reg[6:0]nbin;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   en<=0;found<=0;sens<=0;en2<=0;fps<=0;lag<=0;ae_on<=0;ae_level<=0;bl<=0;br<=0;bt<=0;bb<=0;bli<=0;bri<=0;bti<=0;bbi<=0;xbin<=0;ybin<=0;nbin<=0;
  end else begin
   en<=valid && meta[62];found<=meta[61];sens<=meta[22:21];
   en2<=valid && meta[74:67]!=0;fps<=meta[74:67];lag<=meta[66:63];
   ae_on<=meta[81];ae_level<={meta[80:75],meta[20:18]};
   bl<={1'b0,bxmin,3'b0};br<={1'b0,bxmax,3'b0}+12'd8;
   bt<={2'b0,bymin,3'b0};bb<={2'b0,bymax,3'b0}+12'd8;
   bli<={1'b0,bxmin,3'b0}+12'd2;bri<={1'b0,bxmax,3'b0}+12'd6;
   bti<={2'b0,bymin,3'b0}+12'd2;bbi<={2'b0,bymax,3'b0}+12'd6;
   xbin<={xsum,2'b0};ybin<={ysum,2'b0};nbin<=blocks>7'd99 ? 7'd99 : blocks;
  end
 end
 // Sequential double-dabble: 11 shift steps, all three values in parallel.
 function[15:0]dab;input[15:0]v;integer i;begin
  dab=v;
  for(i=0;i<4;i=i+1)if(v[i*4+:4]>=4'd5)dab[i*4+:4]=v[i*4+:4]+4'd3;
 end endfunction
 reg start_d,busy;reg[3:0]step;
 reg[10:0]xs,ys,ns,ls;reg[15:0]xw,yw,nw,lw;
 reg[15:0]xd,yd,nd,ld;
 wire[15:0]xa=dab(xw),ya=dab(yw),na=dab(nw),la=dab(lw);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   start_d<=0;busy<=0;step<=0;xs<=0;ys<=0;ns<=0;xw<=0;yw<=0;nw<=0;xd<=0;yd<=0;nd<=0;ls<=0;lw<=0;ld<=0;
  end else begin
   start_d<=user;
   if(start_d)begin
    busy<=1;step<=0;xs<=xbin;ys<={1'b0,ybin};ns<={4'b0,nbin};ls<={2'b0,ae_level};xw<=0;yw<=0;nw<=0;lw<=0;
   end else if(busy)begin
    xw<={xa[14:0],xs[10]};yw<={ya[14:0],ys[10]};nw<={na[14:0],ns[10]};lw<={la[14:0],ls[10]};
    xs<={xs[9:0],1'b0};ys<={ys[9:0],1'b0};ns<={ns[9:0],1'b0};ls<={ls[9:0],1'b0};
    step<=step+1'b1;
    if(step==4'd10)begin
     busy<=0;xd<={xa[14:0],xs[10]};yd<={ya[14:0],ys[10]};nd<={na[14:0],ns[10]};ld<={la[14:0],ls[10]};
    end
   end
  end
 end
 function[7:0]digit;input[3:0]d;digit=8'h30+{4'b0,d};endfunction
 function[34:0]glyph;input[7:0]c;begin case(c)
  "R":glyph=35'b11110100011000111110101001001010001;
  "E":glyph=35'b11111100001000011110100001000011111;
  "D":glyph=35'b11110100011000110001100011000111110;
  "X":glyph=35'b10001100010101000100010101000110001;
  "F":glyph=35'b11111100001000011110100001000010000;
  "P":glyph=35'b11110100011000111110100001000010000;
  "L":glyph=35'b10000100001000010000100001000011111;
  "A":glyph=35'b01110100011000111111100011000110001;
  "T":glyph=35'b11111001000010000100001000010000100;
  "S":glyph=35'b01111100001000001110000010000111110;
  "Y":glyph=35'b10001100010101000100001000010000100;
  "N":glyph=35'b10001110011010110011100011000110001;
  "O":glyph=35'b01110100011000110001100011000101110;
  "0":glyph=35'b01110100011001110101110011000101110;
  "1":glyph=35'b00100011000010000100001000010001110;
  "2":glyph=35'b01110100010000100010001000100011111;
  "3":glyph=35'b11110000010000101110000010000111110;
  "4":glyph=35'b00010001100101010010111110001000010;
  "5":glyph=35'b11111100001111000001000011000101110;
  "6":glyph=35'b00110010001000011110100011000101110;
  "7":glyph=35'b11111000010001000100010000100001000;
  "8":glyph=35'b01110100011000101110100011000101110;
  "9":glyph=35'b01110100011000101111000010001001100;
  default:glyph=35'b0;
 endcase end endfunction
 // Stage A: comparisons and character selection.
 wire[11:0]lx=x-TX,ly=y-TY,ly2=y-TY2;
 wire row2=y>=TY2;
 wire[3:0]lyr=row2 ? ly2[3:0] : ly[3:0];
 reg a_xin,a_yin,a_edge,a_text,a_perf,a_pix;reg[2:0]a_col,a_row;reg[7:0]a_char;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin a_xin<=0;a_yin<=0;a_edge<=0;a_text<=0;a_perf<=0;a_pix<=0;a_col<=0;a_row<=0;a_char<=0;end
  else begin
   a_xin<=x>=bl && x<br;a_yin<=y>=bt && y<bb;
   a_edge<=x<bli || x>=bri || y<bti || y>=bbi;
   a_text<=x>=TX && x<TX+TW && y>=TY && y<TY+TH;
   a_perf<=x>=TX && x<TX+TW2 && y>=TY2 && y<TY2+TH;
   a_pix<=lx[3:1]<3'd5 && lyr<4'd14;
   a_col<=lx[3:1];a_row<=lyr[3:1];
   if(row2)case(lx[8:4])
    5'd0:a_char<="F";5'd1:a_char<="P";5'd2:a_char<="S";
    5'd4:a_char<=digit(fps[7:4]);5'd5:a_char<=digit(fps[3:0]);
    5'd7:a_char<="L";5'd8:a_char<="A";5'd9:a_char<="T";
    5'd11:a_char<=digit(lag);5'd12:a_char<="F";
    5'd14:a_char<=ae_on ? "A" : "F";5'd15:a_char<=ae_on ? "E" : "X";
    5'd17:a_char<=digit(ld[11:8]);5'd18:a_char<=digit(ld[7:4]);5'd19:a_char<=digit(ld[3:0]);
    default:a_char<=" ";
   endcase else if(found)case(lx[8:4])
    5'd0:a_char<="R";5'd1:a_char<="E";5'd2:a_char<="D";5'd4:a_char<="X";
    5'd5:a_char<=digit(xd[15:12]);5'd6:a_char<=digit(xd[11:8]);
    5'd7:a_char<=digit(xd[7:4]);5'd8:a_char<=digit(xd[3:0]);
    5'd10:a_char<="Y";5'd11:a_char<=digit(yd[11:8]);
    5'd12:a_char<=digit(yd[7:4]);5'd13:a_char<=digit(yd[3:0]);
    5'd15:a_char<="N";5'd16:a_char<=digit(nd[7:4]);5'd17:a_char<=digit(nd[3:0]);
    5'd19:a_char<="S";5'd20:a_char<=digit({2'b0,sens});
    default:a_char<=" ";
   endcase else case(lx[8:4])
    5'd0:a_char<="R";5'd1:a_char<="E";5'd2:a_char<="D";
    5'd4:a_char<="N";5'd5:a_char<="O";5'd6:a_char<="N";5'd7:a_char<="E";
    5'd15:a_char<="N";5'd16:a_char<=digit(nd[7:4]);5'd17:a_char<=digit(nd[3:0]);
    5'd19:a_char<="S";5'd20:a_char<=digit({2'b0,sens});
    default:a_char<=" ";
   endcase
  end
 end
 // Stage B: glyph bit and final colour.
 wire[34:0]font=glyph(a_char);
 wire[5:0]bit_index=6'd34-({3'b0,a_row}*6'd5+{3'b0,a_col});
 wire text_on=a_pix && font[bit_index];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin hit<=0;color<=0;end
  else begin
   hit<=0;color<=0;
   if(en && found && a_xin && a_yin && a_edge)begin hit<=1;color<=BOX;end
   if(en && a_text)begin
    hit<=1;color<=text_on ? (found ? TEXT_FOUND : TEXT_NONE) : BACK;
   end
   if(en2 && a_perf)begin hit<=1;color<=text_on ? PERF : BACK;end
  end
 end
endmodule
