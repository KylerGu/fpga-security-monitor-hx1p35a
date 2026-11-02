module security_overlay(input wire[11:0]x,y,input wire valid,input wire[255:0]meta,
 output reg hit,output reg[23:0]color);
 wire[7:0]rx=meta[173:166],ry=meta[165:158],rw=meta[157:150],rh=meta[149:142];
 wire[11:0]left={rx,3'b0},top={ry,3'b0};
 wire[11:0]right=({4'b0,rx}+{4'b0,rw})<<3,bottom=({4'b0,ry}+{4'b0,rh})<<3;
 wire[11:0]bl={meta[141:134],3'b0},bt={meta[133:126],3'b0};
 wire[11:0]br=({4'b0,meta[125:118]}+12'd1)<<3,bb=({4'b0,meta[117:110]}+12'd1)<<3;
 wire roi=(meta[207:206]==2 || meta[201]) && valid && x>=left && x<right && y>=top && y<bottom &&
    (x<left+2 || x>=right-2 || y<top+2 || y>=bottom-2);
 wire box=meta[207:206]==2 && valid && meta[205] && meta[204] &&
    x>=bl && x<br && y>=bt && y<bb && (x<bl+2 || x>=br-2 || y<bt+2 || y>=bb-2);
 reg[63:0]text;reg[7:0]ch;reg[34:0]font;
 wire[11:0]lx=x-700,ly=y-24;
 function[34:0]glyph;input[7:0]c;begin case(c)
  "A":glyph=35'b01110100011000111111100011000110001;
  "L":glyph=35'b10000100001000010000100001000011111;
  "R":glyph=35'b11110100011000111110101001001010001;
  "M":glyph=35'b10001110111010110101100011000110001;
  "E":glyph=35'b11111100001000011110100001000011111;
  "D":glyph=35'b11110100011000110001100011000111110;
  "I":glyph=35'b11111001000010000100001000010011111;
  "S":glyph=35'b01111100001000001110000010000111110;
  "T":glyph=35'b11111001000010000100001000010000100;
  "W":glyph=35'b10001100011000110101101011101110001;
  "X":glyph=35'b10001100010101000100010101000110001;
  "Y":glyph=35'b10001100010101000100001000010000100;
  "H":glyph=35'b10001100011000111111100011000110001;
  "G":glyph=35'b01110100011000010111100011000101111;
  default:glyph=0;
 endcase end endfunction
 always @*begin
  if(!valid)text="WAIT    ";
  else if(meta[201])case(meta[200:199])0:text="SET X   ";1:text="SET Y   ";2:text="SET W   ";default:text="SET H   ";endcase
  else if(meta[202])text="ALARM   ";
  else if(meta[23])text="LIGHT   ";   // global light change, motion not counted
  else if(meta[203])text="ARMED   ";
  else text="DISARM  ";
  ch=text >> ((7-lx[6:4])*8);font=glyph(ch);
  hit=0;color=0;
  if(box)begin hit=1;color=24'hfff000;end
  if(roi)begin hit=1;color=meta[202] ? 24'hff3030 : 24'h20ff60;end
  if(x>=700 && x<828 && y>=24 && y<40)begin
   hit=1;color=24'h102030;
   if(lx[3:1]<5 && ly<14 && font[34-(ly[3:1]*5+lx[3:1])])
    color=valid && meta[202] ? 24'hff3030 :
          valid && !meta[201] && meta[23] ? 24'hffd040 : 24'hffffff;
  end
 end
endmodule
