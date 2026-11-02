// PASS means target passages. L>R/R>L are separate directional counts; LAST is
// the most recent confirmed passage, SIDE is the currently qualified origin.
// Two registered stages match the mixer. Snapshot once per displayed picture.
module security_pass_overlay(
 input wire clk,rst_n,user,input wire[11:0]x,y,input wire[39:0]status,
 output reg hit,output reg[23:0]color
);
 reg[39:0]shown;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)shown<=0;else if(user)shown<=status;
 wire[11:0]lx=x-12'd700,ly=y-12'd96,ly2=y-12'd120;
 wire label_area=x>=16 && x<152 && y>=184 && y<208;
 wire[11:0]label_x=x-12'd16,label_y=y-12'd184;
 wire second=y>=120;
 wire[3:0]row_y=second ? ly2[3:0] : ly[3:0];
 function[7:0]digit;input[3:0]d;digit=8'h30+{4'b0,d};endfunction
 reg[7:0]ch;
 always @*begin
  ch=" ";
  if(label_area)case(label_x[7:4])
   0:ch="P";1:ch="A";2:ch="S";3:ch="S";default:ch=" ";
  endcase else if(!second)case(lx[8:4])
   0:ch="P";1:ch="A";2:ch="S";3:ch="S";
   5:ch=digit(shown[35:32]);6:ch=digit(shown[31:28]);7:ch=digit(shown[27:24]);
   9:ch="L";10:ch=">";11:ch="R";
   13:ch=digit(shown[23:20]);14:ch=digit(shown[19:16]);15:ch=digit(shown[15:12]);
   17:ch="R";18:ch=">";19:ch="L";
   21:ch=digit(shown[11:8]);22:ch=digit(shown[7:4]);23:ch=digit(shown[3:0]);
   default:ch=" ";
  endcase else case(lx[8:4])
   0:ch="L";1:ch="A";2:ch="S";3:ch="T";
   5:ch=shown[37:36]==1 ? "L" : shown[37:36]==2 ? "R" : "-";
   6:ch=shown[37:36]!=0 ? ">" : "-";
   7:ch=shown[37:36]==1 ? "R" : shown[37:36]==2 ? "L" : "-";
   9:ch="S";10:ch="I";11:ch="D";12:ch="E";
   14:ch=shown[39:38]==1 ? "L" : shown[39:38]==2 ? "R" : "-";
   default:ch=" ";
  endcase
 end
 function[34:0]glyph;input[7:0]c;begin case(c)
  "P":glyph=35'b11110100011000111110100001000010000;
  "A":glyph=35'b01110100011000111111100011000110001;
  "S":glyph=35'b01111100001000001110000010000111110;
  "L":glyph=35'b10000100001000010000100001000011111;
  "R":glyph=35'b11110100011000111110101001001010001;
  "T":glyph=35'b11111001000010000100001000010000100;
  "I":glyph=35'b01110001000010000100001000010001110;
  "D":glyph=35'b11110100011000110001100011000111110;
  "E":glyph=35'b11111100001000011110100001000011111;
  ">":glyph=35'b10000010000010000010001000100010000;
  "-":glyph=35'b00000000000000011111000000000000000;
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
  default:glyph=0;
 endcase end endfunction
 reg a_pix;reg a_text,a_line,a_band;reg[2:0]a_col,a_row;reg[7:0]a_char;
 wire[34:0]bits=glyph(a_char);
 wire ink=a_pix && a_col<5 && a_row<7 && bits[34-(a_row*5+a_col)];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin a_pix<=0;a_text<=0;a_line<=0;a_band<=0;a_col<=0;a_row<=0;a_char<=0;hit<=0;color<=0;end
  else begin
   a_text<=label_area || (x>=700 && ((x<1084 && y>=96 && y<112) || (x<940 && y>=120 && y<136)));
   a_line<=x>=639 && x<=640 && y>=144 && y<696;
   a_band<=(x==616 || x==664) && y>=144 && y<696 && !y[3];
   a_col<=label_area ? label_x[3:1] : lx[3:1];
   a_row<=label_area ? label_y[3:1] : row_y[3:1];
   a_pix<=label_area ? label_y<14 : row_y<14;a_char<=ch;
   hit<=a_text || a_line || a_band;
   color<=a_text ? (ink ? 24'hffe060 : 24'h102030) : a_line ? 24'hffe060 : 24'h408080;
  end
 end
endmodule
