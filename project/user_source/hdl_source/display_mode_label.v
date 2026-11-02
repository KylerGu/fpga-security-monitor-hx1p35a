module display_mode_label(input [11:0] x,y,input [1:0] mode,output wire hit,output wire [23:0] color);
wire [11:0] lx=x-12'd16, ly=y-12'd184;
reg [7:0] ch;
reg [34:0] bits;
wire [2:0] row=ly[3:1];
wire [3:0] index=lx[7:4];
always @* begin
 ch=0;
 case(mode)
 2'd0: case(index)
 4'd0: ch=8'd82;
 4'd1: ch=8'd65;
 4'd2: ch=8'd87;
 default: ch=0;
 endcase
 2'd1: case(index)
 4'd0: ch=8'd69;
 4'd1: ch=8'd68;
 4'd2: ch=8'd71;
 4'd3: ch=8'd69;
 default: ch=0;
 endcase
 2'd2: case(index)
 4'd0: ch="M";4'd1: ch="O";4'd2: ch="T";4'd3: ch="I";4'd4: ch="O";4'd5: ch="N";
 default:ch=0;
 endcase
 2'd3: case(index)
 4'd0: ch=8'd71;
 4'd1: ch=8'd82;
 4'd2: ch=8'd65;
 4'd3: ch=8'd89;
 default: ch=0;
 endcase
 default: ch=0;
 endcase
 bits=0;
 case(ch)
 8'd82: bits=35'b11110100011000111110101001001010001;
 8'd65: bits=35'b01110100011000111111100011000110001;
 8'd87: bits=35'b10001100011000110101101011101110001;
 8'd69: bits=35'b11111100001000011110100001000011111;
 8'd68: bits=35'b11110100011000110001100011000111110;
 8'd71: bits=35'b01110100011000010111100011000101110;
 8'd79: bits=35'b01110100011000110001100011000101110;
 8'd83: bits=35'b01111100001000001110000010000111110;
 8'd43: bits=35'b00000001000010011111001000010000000;
 8'd89: bits=35'b10001100010101000100001000010000100;
 "M":bits=35'b10001110111010110101100011000110001;
 "T":bits=35'b11111001000010000100001000010000100;
 "I":bits=35'b11111001000010000100001000010011111;
 "N":bits=35'b10001110011010110011100011000110001;
 default: bits=0;
 endcase
end
assign hit=(x>=16 && x<152 && y>=184 && y<208);
wire ink=(lx[3:1]<5 && ly<14) ? bits[34-(row*5+lx[3:1])] : 1'b0;
assign color=ink ? 24'h00ffff : 24'h101820;
endmodule
