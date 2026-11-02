module hdmi_mixer #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    parameter integer DEBUG_MODE = 0,
    parameter integer BRIGHTNESS_ENABLE = 0,
    parameter integer FOCUS_ENABLE = 0,
    parameter integer PASS_ENABLE = 0
)(
    input wire I_focus_switch,I_focus_reset,I_focus_valid,
    input wire[20:0] I_focus_data,
    input wire[39:0] I_pass_status,
    input wire [1:0]  I_mode,
    input wire[255:0] I_security_meta,
    input wire I_security_valid,
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data
);

    reg [1:0] frame_mode, mode_1d, mode_2d;
    wire [1:0] pixel_mode = (I_video_user && I_video_de) ? I_mode : frame_mode;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin frame_mode<=0;mode_1d<=0;mode_2d<=0;end
        else begin
            if(I_video_user && I_video_de) frame_mode<=I_mode;
            mode_1d<=pixel_mode;mode_2d<=mode_1d;
        end
    end
    // Fixed post-DDR transfer. Enabled by the production top; no board switch.
    // Reuses the original pixel register; detector, AE and AWB inputs are untouched.
    // RAW and MOTION only. GRAY/EDGE and all original overlays retain Color values.
    wire brightness_for_pixel = (BRIGHTNESS_ENABLE != 0) && (pixel_mode == 0 || pixel_mode == 2);
    function [7:0] F_brightness;
        input [7:0] value;
        begin
            case(value)
                8'd0:F_brightness=8'd0; 8'd1:F_brightness=8'd1; 8'd2:F_brightness=8'd2; 8'd3:F_brightness=8'd3;
                8'd4:F_brightness=8'd4; 8'd5:F_brightness=8'd5; 8'd6:F_brightness=8'd6; 8'd7:F_brightness=8'd7;
                8'd8:F_brightness=8'd8; 8'd9:F_brightness=8'd9; 8'd10:F_brightness=8'd10; 8'd11:F_brightness=8'd11;
                8'd12:F_brightness=8'd12; 8'd13:F_brightness=8'd13; 8'd14:F_brightness=8'd14; 8'd15:F_brightness=8'd15;
                8'd16:F_brightness=8'd16; 8'd17:F_brightness=8'd17; 8'd18:F_brightness=8'd18; 8'd19:F_brightness=8'd20;
                8'd20:F_brightness=8'd21; 8'd21:F_brightness=8'd22; 8'd22:F_brightness=8'd23; 8'd23:F_brightness=8'd24;
                8'd24:F_brightness=8'd26; 8'd25:F_brightness=8'd27; 8'd26:F_brightness=8'd29; 8'd27:F_brightness=8'd30;
                8'd28:F_brightness=8'd31; 8'd29:F_brightness=8'd33; 8'd30:F_brightness=8'd34; 8'd31:F_brightness=8'd35;
                8'd32:F_brightness=8'd37; 8'd33:F_brightness=8'd38; 8'd34:F_brightness=8'd40; 8'd35:F_brightness=8'd41;
                8'd36:F_brightness=8'd42; 8'd37:F_brightness=8'd44; 8'd38:F_brightness=8'd45; 8'd39:F_brightness=8'd47;
                8'd40:F_brightness=8'd49; 8'd41:F_brightness=8'd50; 8'd42:F_brightness=8'd52; 8'd43:F_brightness=8'd53;
                8'd44:F_brightness=8'd55; 8'd45:F_brightness=8'd56; 8'd46:F_brightness=8'd58; 8'd47:F_brightness=8'd59;
                8'd48:F_brightness=8'd61; 8'd49:F_brightness=8'd63; 8'd50:F_brightness=8'd64; 8'd51:F_brightness=8'd66;
                8'd52:F_brightness=8'd68; 8'd53:F_brightness=8'd69; 8'd54:F_brightness=8'd71; 8'd55:F_brightness=8'd73;
                8'd56:F_brightness=8'd74; 8'd57:F_brightness=8'd76; 8'd58:F_brightness=8'd77; 8'd59:F_brightness=8'd80;
                8'd60:F_brightness=8'd81; 8'd61:F_brightness=8'd83; 8'd62:F_brightness=8'd84; 8'd63:F_brightness=8'd87;
                8'd64:F_brightness=8'd88; 8'd65:F_brightness=8'd89; 8'd66:F_brightness=8'd90; 8'd67:F_brightness=8'd92;
                8'd68:F_brightness=8'd93; 8'd69:F_brightness=8'd94; 8'd70:F_brightness=8'd95; 8'd71:F_brightness=8'd97;
                8'd72:F_brightness=8'd98; 8'd73:F_brightness=8'd99; 8'd74:F_brightness=8'd100; 8'd75:F_brightness=8'd101;
                8'd76:F_brightness=8'd103; 8'd77:F_brightness=8'd104; 8'd78:F_brightness=8'd105; 8'd79:F_brightness=8'd106;
                8'd80:F_brightness=8'd107; 8'd81:F_brightness=8'd109; 8'd82:F_brightness=8'd110; 8'd83:F_brightness=8'd111;
                8'd84:F_brightness=8'd112; 8'd85:F_brightness=8'd113; 8'd86:F_brightness=8'd114; 8'd87:F_brightness=8'd116;
                8'd88:F_brightness=8'd117; 8'd89:F_brightness=8'd118; 8'd90:F_brightness=8'd119; 8'd91:F_brightness=8'd120;
                8'd92:F_brightness=8'd121; 8'd93:F_brightness=8'd123; 8'd94:F_brightness=8'd124; 8'd95:F_brightness=8'd125;
                8'd96:F_brightness=8'd126; 8'd97:F_brightness=8'd127; 8'd98:F_brightness=8'd128; 8'd99:F_brightness=8'd129;
                8'd100:F_brightness=8'd130; 8'd101:F_brightness=8'd131; 8'd102:F_brightness=8'd133; 8'd103:F_brightness=8'd134;
                8'd104:F_brightness=8'd135; 8'd105:F_brightness=8'd136; 8'd106:F_brightness=8'd137; 8'd107:F_brightness=8'd138;
                8'd108:F_brightness=8'd139; 8'd109:F_brightness=8'd140; 8'd110:F_brightness=8'd141; 8'd111:F_brightness=8'd142;
                8'd112:F_brightness=8'd143; 8'd113:F_brightness=8'd144; 8'd114:F_brightness=8'd146; 8'd115:F_brightness=8'd147;
                8'd116:F_brightness=8'd148; 8'd117:F_brightness=8'd149; 8'd118:F_brightness=8'd150; 8'd119:F_brightness=8'd151;
                8'd120:F_brightness=8'd152; 8'd121:F_brightness=8'd153; 8'd122:F_brightness=8'd154; 8'd123:F_brightness=8'd155;
                8'd124:F_brightness=8'd156; 8'd125:F_brightness=8'd157; 8'd126:F_brightness=8'd158; 8'd127:F_brightness=8'd159;
                8'd128:F_brightness=8'd160; 8'd129:F_brightness=8'd161; 8'd130:F_brightness=8'd162; 8'd131:F_brightness=8'd163;
                8'd132:F_brightness=8'd164; 8'd133:F_brightness=8'd165; 8'd134:F_brightness=8'd166; 8'd135:F_brightness=8'd167;
                8'd136:F_brightness=8'd168; 8'd137:F_brightness=8'd169; 8'd138:F_brightness=8'd170; 8'd139:F_brightness=8'd171;
                8'd140:F_brightness=8'd172; 8'd141:F_brightness=8'd173; 8'd142:F_brightness=8'd173; 8'd143:F_brightness=8'd174;
                8'd144:F_brightness=8'd175; 8'd145:F_brightness=8'd176; 8'd146:F_brightness=8'd177; 8'd147:F_brightness=8'd178;
                8'd148:F_brightness=8'd179; 8'd149:F_brightness=8'd180; 8'd150:F_brightness=8'd181; 8'd151:F_brightness=8'd182;
                8'd152:F_brightness=8'd183; 8'd153:F_brightness=8'd184; 8'd154:F_brightness=8'd184; 8'd155:F_brightness=8'd185;
                8'd156:F_brightness=8'd186; 8'd157:F_brightness=8'd187; 8'd158:F_brightness=8'd188; 8'd159:F_brightness=8'd189;
                8'd160:F_brightness=8'd190; 8'd161:F_brightness=8'd191; 8'd162:F_brightness=8'd192; 8'd163:F_brightness=8'd192;
                8'd164:F_brightness=8'd193; 8'd165:F_brightness=8'd194; 8'd166:F_brightness=8'd195; 8'd167:F_brightness=8'd196;
                8'd168:F_brightness=8'd197; 8'd169:F_brightness=8'd197; 8'd170:F_brightness=8'd198; 8'd171:F_brightness=8'd199;
                8'd172:F_brightness=8'd200; 8'd173:F_brightness=8'd201; 8'd174:F_brightness=8'd202; 8'd175:F_brightness=8'd202;
                8'd176:F_brightness=8'd203; 8'd177:F_brightness=8'd204; 8'd178:F_brightness=8'd205; 8'd179:F_brightness=8'd206;
                8'd180:F_brightness=8'd206; 8'd181:F_brightness=8'd207; 8'd182:F_brightness=8'd208; 8'd183:F_brightness=8'd209;
                8'd184:F_brightness=8'd210; 8'd185:F_brightness=8'd210; 8'd186:F_brightness=8'd211; 8'd187:F_brightness=8'd212;
                8'd188:F_brightness=8'd213; 8'd189:F_brightness=8'd213; 8'd190:F_brightness=8'd214; 8'd191:F_brightness=8'd215;
                8'd192:F_brightness=8'd216; 8'd193:F_brightness=8'd216; 8'd194:F_brightness=8'd217; 8'd195:F_brightness=8'd218;
                8'd196:F_brightness=8'd219; 8'd197:F_brightness=8'd219; 8'd198:F_brightness=8'd220; 8'd199:F_brightness=8'd221;
                8'd200:F_brightness=8'd222; 8'd201:F_brightness=8'd222; 8'd202:F_brightness=8'd223; 8'd203:F_brightness=8'd224;
                8'd204:F_brightness=8'd224; 8'd205:F_brightness=8'd225; 8'd206:F_brightness=8'd226; 8'd207:F_brightness=8'd226;
                8'd208:F_brightness=8'd227; 8'd209:F_brightness=8'd228; 8'd210:F_brightness=8'd229; 8'd211:F_brightness=8'd229;
                8'd212:F_brightness=8'd230; 8'd213:F_brightness=8'd231; 8'd214:F_brightness=8'd231; 8'd215:F_brightness=8'd232;
                8'd216:F_brightness=8'd233; 8'd217:F_brightness=8'd233; 8'd218:F_brightness=8'd234; 8'd219:F_brightness=8'd234;
                8'd220:F_brightness=8'd235; 8'd221:F_brightness=8'd236; 8'd222:F_brightness=8'd236; 8'd223:F_brightness=8'd237;
                8'd224:F_brightness=8'd238; 8'd225:F_brightness=8'd238; 8'd226:F_brightness=8'd239; 8'd227:F_brightness=8'd239;
                8'd228:F_brightness=8'd240; 8'd229:F_brightness=8'd241; 8'd230:F_brightness=8'd241; 8'd231:F_brightness=8'd242;
                8'd232:F_brightness=8'd242; 8'd233:F_brightness=8'd243; 8'd234:F_brightness=8'd244; 8'd235:F_brightness=8'd244;
                8'd236:F_brightness=8'd245; 8'd237:F_brightness=8'd245; 8'd238:F_brightness=8'd246; 8'd239:F_brightness=8'd246;
                8'd240:F_brightness=8'd247; 8'd241:F_brightness=8'd248; 8'd242:F_brightness=8'd248; 8'd243:F_brightness=8'd249;
                8'd244:F_brightness=8'd249; 8'd245:F_brightness=8'd250; 8'd246:F_brightness=8'd250; 8'd247:F_brightness=8'd251;
                8'd248:F_brightness=8'd251; 8'd249:F_brightness=8'd252; 8'd250:F_brightness=8'd252; 8'd251:F_brightness=8'd253;
                8'd252:F_brightness=8'd253; 8'd253:F_brightness=8'd254; 8'd254:F_brightness=8'd254; 8'd255:F_brightness=8'd255;
                default:F_brightness=value;
            endcase
        end
    endfunction
    wire mode_label_hit;
    wire [23:0] mode_label_color;
    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [23:0] S_video_data_1d;
    reg [23:0] S_video_data_2d;
    reg [11:0] S_x;
    reg [11:0] S_y;
    reg [11:0] S_x_1d;
    reg [11:0] S_x_2d;
    reg [11:0] S_y_1d;
    reg [11:0] S_y_2d;
    wire focus_hit;wire[23:0]focus_color;
    generate if(FOCUS_ENABLE)begin:g_focus
      focus_assist u_focus(.clk(I_clk),.rst_n(I_rst_n),.user(I_video_user),
       .sw_enable(I_focus_switch),.sw_reset(I_focus_reset),.sample_valid(I_focus_valid),.sample(I_focus_data),
       .x(S_x),.y(S_y),.hit(focus_hit),.color(focus_color));
    end else begin:g_no_focus
      assign focus_hit=1'b0;assign focus_color=24'd0;
    end endgenerate
    wire pass_hit;wire[23:0]pass_color;
    // Scene belongs to the selected frame, never live switch levels.
    reg pass_show;
    always @(posedge I_clk or negedge I_rst_n)
      if(!I_rst_n)pass_show<=0;
      else if(I_video_user && I_video_de)
        pass_show<=(PASS_ENABLE != 0) && I_security_valid && I_security_meta[17] && !I_security_meta[201] && I_mode==0;
    generate if(PASS_ENABLE)begin:g_pass
      security_pass_overlay u_pass(.clk(I_clk),.rst_n(I_rst_n),.user(I_video_user),
       .x(S_x),.y(S_y),.status(I_pass_status),.hit(pass_hit),.color(pass_color));
    end else begin:g_no_pass
      assign pass_hit=1'b0;assign pass_color=24'd0;
    end endgenerate
    wire security_hit;wire[23:0]security_color;
    security_overlay u_security_overlay(S_x_2d,S_y_2d,I_security_valid,I_security_meta,security_hit,security_color);
    // Red target box/status: fed from stage-0 counters, registered to align with S_x_2d.
    wire color_hit;wire[23:0]color_color;
    security_color_overlay u_color_overlay(.clk(I_clk),.rst_n(I_rst_n),.user(I_video_user),.x(S_x),.y(S_y),
        .valid(I_security_valid),.meta(I_security_meta),.hit(color_hit),.color(color_color));
    display_mode_label u_mode_label(.x(S_x_2d),.y(S_y_2d),.mode(mode_2d),.hit(mode_label_hit),.color(mode_label_color));


    reg        S_osd_hit;
    reg [23:0] S_osd_color;
    reg [3:0]  S_char_idx;
    reg [2:0]  S_char_row;
    reg [2:0]  S_char_col;
    reg [4:0]  S_char_bits;
    reg        S_char_on;
    reg        S_logo_blue_on;
    reg        S_logo_red_on;
    reg [11:0] S_logo_tmp_y;
    reg [3:0]  S_logo_red_band;
    reg [11:0] S_logo_red_x_start;
    reg [11:0] S_logo_red_x_end;
    reg [14:0] S_logo_addr;
    wire[24:0] S_logo_pixel;
    reg [31:0] S_frame_cnt;
    reg [11:0] S_dyn_x;
    reg [11:0] S_dyn_y;
    reg [3:0]  S_dyn_char;
    reg [2:0]  S_dyn_col;
    reg [2:0]  S_dyn_row;
    reg [4:0]  S_dyn_bits;
    reg        S_dyn_on;
    reg [3:0]  S_dyn_digit_idx;
    reg [11:0] S_dyn_digit_x;
    reg [6:0]  S_dyn_seg;
    reg [3:0]  S_cnt_d0;
    reg [3:0]  S_cnt_d1;
    reg [3:0]  S_cnt_d2;
    reg [3:0]  S_cnt_d3;
    reg [3:0]  S_cnt_d4;
    reg [3:0]  S_cnt_d5;
    reg [2:0]  S_lbl_row;
    reg [2:0]  S_lbl_col;
    reg [1:0]  S_lbl_idx;
    reg [4:0]  S_lbl_bits;
    reg [6:0]  S_lbl_local_x;
    reg [3:0]  S_dyn_dec_digit;
    reg [4:0]  S_cn_local_x;
    reg [4:0]  S_cn_local_y;
    reg [3:0]  S_cn_col;
    reg [3:0]  S_cn_row;
    reg [15:0] S_cn_row_bits;
    reg        S_cn_on;
    reg [9:0]  S_cn_scale_x;
    reg [9:0]  S_cn_scale_y;
    reg [7:0]  S_pf_char;
    reg [4:0]  S_pf_local_x;
    reg [4:0]  S_pf_local_y;
    reg [3:0]  S_pf_col;
    reg [3:0]  S_pf_row;
    wire [15:0] S_pf_row_bits;
    reg        S_pf_on;
    reg [9:0]  S_pf_scale_x;
    reg [9:0]  S_pf_scale_y;

    localparam LOGO_X = 12'd0;
    localparam LOGO_Y = 12'd0;
    localparam LOGO_W = 12'd160;
    localparam LOGO_H = 12'd160;

    localparam COLOR_LOGO_BLUE   = 24'h1f315c;
    localparam COLOR_LOGO_RED    = 24'hec1c2d;
    localparam COLOR_TEXT        = 24'h00e6ff;
    localparam DYN_OSD_X         = 12'd375;
    localparam DYN_OSD_Y         = 12'd120;
    localparam DYN_OSD_W         = 12'd200;
    localparam DYN_OSD_H         = 12'd24;
    localparam CN_Y_OFFSET       = 12'd2;
    localparam COLOR_DYN_TEXT    = 24'hfff200;
    localparam CHAR_AN           = 8'h80;
    localparam CHAR_LU           = 8'h81;
    localparam CHAR_C            = 8'h43;
    localparam CHAR_N            = 8'h4e;
    localparam CHAR_T            = 8'h54;
    localparam CHAR_0            = 8'h30;
    localparam CHAR_COLON        = 8'h3a;

    function [4:0] F_logo_text_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'd0: begin
                    case(I_row) // A
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b11111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd1: begin
                    case(I_row) // N
                        3'd0: F_logo_text_bits = 5'b10001;
                        3'd1: F_logo_text_bits = 5'b11001;
                        3'd2: F_logo_text_bits = 5'b10101;
                        3'd3: F_logo_text_bits = 5'b10011;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd2: begin
                    case(I_row) // L
                        3'd0: F_logo_text_bits = 5'b10000;
                        3'd1: F_logo_text_bits = 5'b10000;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10000;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd3: begin
                    case(I_row) // O
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b10001;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd4: begin
                    case(I_row) // G
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd5: begin
                    case(I_row) // I
                        3'd0: F_logo_text_bits = 5'b11111;
                        3'd1: F_logo_text_bits = 5'b00100;
                        3'd2: F_logo_text_bits = 5'b00100;
                        3'd3: F_logo_text_bits = 5'b00100;
                        3'd4: F_logo_text_bits = 5'b00100;
                        3'd5: F_logo_text_bits = 5'b00100;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd6: begin
                    case(I_row) // C
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                default: F_logo_text_bits = 5'b00000;
            endcase
        end
    endfunction

    // 7-seg bit mapping: {a,b,c,d,e,f,g}
    function [6:0] F_hex7seg;
        input [3:0] I_hex;
        begin
            case(I_hex)
                4'h0: F_hex7seg = 7'b1111110;
                4'h1: F_hex7seg = 7'b0110000;
                4'h2: F_hex7seg = 7'b1101101;
                4'h3: F_hex7seg = 7'b1111001;
                4'h4: F_hex7seg = 7'b0110011;
                4'h5: F_hex7seg = 7'b1011011;
                4'h6: F_hex7seg = 7'b1011111;
                4'h7: F_hex7seg = 7'b1110000;
                4'h8: F_hex7seg = 7'b1111111;
                4'h9: F_hex7seg = 7'b1111011;
                4'ha: F_hex7seg = 7'b1110111;
                4'hb: F_hex7seg = 7'b0011111;
                4'hc: F_hex7seg = 7'b1001110;
                4'hd: F_hex7seg = 7'b0111101;
                4'he: F_hex7seg = 7'b1001111;
                4'hf: F_hex7seg = 7'b1000111;
                default: F_hex7seg = 7'b0000000;
            endcase
        end
    endfunction

    function [4:0] F_cnt_label_bits;
        input [1:0] I_idx;
        input [2:0] I_row;
        begin
            case(I_idx)
                2'd0: begin // C
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b01110;
                        3'd1: F_cnt_label_bits = 5'b10001;
                        3'd2: F_cnt_label_bits = 5'b10000;
                        3'd3: F_cnt_label_bits = 5'b10000;
                        3'd4: F_cnt_label_bits = 5'b10000;
                        3'd5: F_cnt_label_bits = 5'b10001;
                        3'd6: F_cnt_label_bits = 5'b01110;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                2'd1: begin // N
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b10001;
                        3'd1: F_cnt_label_bits = 5'b11001;
                        3'd2: F_cnt_label_bits = 5'b10101;
                        3'd3: F_cnt_label_bits = 5'b10011;
                        3'd4: F_cnt_label_bits = 5'b10001;
                        3'd5: F_cnt_label_bits = 5'b10001;
                        3'd6: F_cnt_label_bits = 5'b10001;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                2'd2: begin // T
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b11111;
                        3'd1: F_cnt_label_bits = 5'b00100;
                        3'd2: F_cnt_label_bits = 5'b00100;
                        3'd3: F_cnt_label_bits = 5'b00100;
                        3'd4: F_cnt_label_bits = 5'b00100;
                        3'd5: F_cnt_label_bits = 5'b00100;
                        3'd6: F_cnt_label_bits = 5'b00100;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                default: begin // ':'
                    case(I_row)
                        3'd2: F_cnt_label_bits = 5'b00100;
                        3'd5: F_cnt_label_bits = 5'b00100;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
            endcase
        end
    endfunction

    // Minimal 16x16 Chinese bitmap rows for "an" and "lu".
    function [15:0] F_cn16_row;
        input I_char; // 0: an, 1: lu
        input [3:0] I_row;
        begin
            if(!I_char) begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h0200;
                    4'd1:  F_cn16_row = 16'h7ff0;
                    4'd2:  F_cn16_row = 16'h4410;
                    4'd3:  F_cn16_row = 16'h0400;
                    4'd4:  F_cn16_row = 16'h7ff0;
                    4'd5:  F_cn16_row = 16'h0840;
                    4'd6:  F_cn16_row = 16'h1040;
                    4'd7:  F_cn16_row = 16'h1c80;
                    4'd8:  F_cn16_row = 16'h0300;
                    4'd9:  F_cn16_row = 16'h0cc0;
                    4'd10: F_cn16_row = 16'h7020;
                    4'd11: F_cn16_row = 16'h0000;
                    4'd12: F_cn16_row = 16'h0000;
                    4'd13: F_cn16_row = 16'h0000;
                    4'd14: F_cn16_row = 16'h0000;
                    4'd15: F_cn16_row = 16'h0000;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
            else begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h79e0;
                    4'd1:  F_cn16_row = 16'h4a20;
                    4'd2:  F_cn16_row = 16'h4d40;
                    4'd3:  F_cn16_row = 16'h7880;
                    4'd4:  F_cn16_row = 16'h1140;
                    4'd5:  F_cn16_row = 16'h1630;
                    4'd6:  F_cn16_row = 16'h5be0;
                    4'd7:  F_cn16_row = 16'h5220;
                    4'd8:  F_cn16_row = 16'h5220;
                    4'd9:  F_cn16_row = 16'h5be0;
                    4'd10: F_cn16_row = 16'h6220;
                    4'd11: F_cn16_row = 16'h0000;
                    4'd12: F_cn16_row = 16'h0000;
                    4'd13: F_cn16_row = 16'h0000;
                    4'd14: F_cn16_row = 16'h0000;
                    4'd15: F_cn16_row = 16'h0000;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
        end
    endfunction

    function [4:0] F_dyn_char_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'h0: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10011; 3'd3:F_dyn_char_bits=5'b10101; 3'd4:F_dyn_char_bits=5'b11001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h1: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00100; 3'd1:F_dyn_char_bits=5'b01100; 3'd2:F_dyn_char_bits=5'b00100; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b00100; 3'd5:F_dyn_char_bits=5'b00100; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h2: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b00110; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'h3: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h4: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00010; 3'd1:F_dyn_char_bits=5'b00110; 3'd2:F_dyn_char_bits=5'b01010; 3'd3:F_dyn_char_bits=5'b10010; 3'd4:F_dyn_char_bits=5'b11111; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b00010; default:F_dyn_char_bits=5'b00000; endcase end
                4'h5: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b11110; 3'd3:F_dyn_char_bits=5'b00001; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h6: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00110; 3'd1:F_dyn_char_bits=5'b01000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h7: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00010; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b01000; 3'd6:F_dyn_char_bits=5'b01000; default:F_dyn_char_bits=5'b00000; endcase end
                4'h8: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h9: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01111; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b11100; default:F_dyn_char_bits=5'b00000; endcase end
                4'ha: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11111; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b10001; default:F_dyn_char_bits=5'b00000; endcase end
                4'hb: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hc: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b10000; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hd: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b10001; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'he: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'hf: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b10000; default:F_dyn_char_bits=5'b00000; endcase end
                default: F_dyn_char_bits = 5'b00000;
            endcase
        end
    endfunction

    // Unified prefix character library (16x16 rows): an/lu/C/N/T/:
    function [15:0] F_osd_char16_row;
        input [7:0] I_char;
        input [3:0] I_row;
        begin
            case(I_char)
                CHAR_AN: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h0200;
                        4'd1:  F_osd_char16_row = 16'h7ff0;
                        4'd2:  F_osd_char16_row = 16'h4410;
                        4'd3:  F_osd_char16_row = 16'h0400;
                        4'd4:  F_osd_char16_row = 16'h7ff0;
                        4'd5:  F_osd_char16_row = 16'h0840;
                        4'd6:  F_osd_char16_row = 16'h1040;
                        4'd7:  F_osd_char16_row = 16'h1c80;
                        4'd8:  F_osd_char16_row = 16'h0300;
                        4'd9:  F_osd_char16_row = 16'h0cc0;
                        4'd10: F_osd_char16_row = 16'h7020;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_LU: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h79e0;
                        4'd1:  F_osd_char16_row = 16'h4a20;
                        4'd2:  F_osd_char16_row = 16'h4d40;
                        4'd3:  F_osd_char16_row = 16'h7880;
                        4'd4:  F_osd_char16_row = 16'h1140;
                        4'd5:  F_osd_char16_row = 16'h1630;
                        4'd6:  F_osd_char16_row = 16'h5be0;
                        4'd7:  F_osd_char16_row = 16'h5220;
                        4'd8:  F_osd_char16_row = 16'h5220;
                        4'd9:  F_osd_char16_row = 16'h5be0;
                        4'd10: F_osd_char16_row = 16'h6220;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_C: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h03f0;
                        4'd3:  F_osd_char16_row = 16'h0c0c;
                        4'd4:  F_osd_char16_row = 16'h1800;
                        4'd5:  F_osd_char16_row = 16'h3000;
                        4'd6:  F_osd_char16_row = 16'h3000;
                        4'd7:  F_osd_char16_row = 16'h3000;
                        4'd8:  F_osd_char16_row = 16'h3000;
                        4'd9:  F_osd_char16_row = 16'h3000;
                        4'd10: F_osd_char16_row = 16'h1800;
                        4'd11: F_osd_char16_row = 16'h0c0c;
                        4'd12: F_osd_char16_row = 16'h03f0;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_N: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h300c;
                        4'd3:  F_osd_char16_row = 16'h380c;
                        4'd4:  F_osd_char16_row = 16'h3c0c;
                        4'd5:  F_osd_char16_row = 16'h360c;
                        4'd6:  F_osd_char16_row = 16'h330c;
                        4'd7:  F_osd_char16_row = 16'h318c;
                        4'd8:  F_osd_char16_row = 16'h30cc;
                        4'd9:  F_osd_char16_row = 16'h306c;
                        4'd10: F_osd_char16_row = 16'h303c;
                        4'd11: F_osd_char16_row = 16'h301c;
                        4'd12: F_osd_char16_row = 16'h300c;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_T: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h3ffc;
                        4'd3:  F_osd_char16_row = 16'h03c0;
                        4'd4:  F_osd_char16_row = 16'h03c0;
                        4'd5:  F_osd_char16_row = 16'h03c0;
                        4'd6:  F_osd_char16_row = 16'h03c0;
                        4'd7:  F_osd_char16_row = 16'h03c0;
                        4'd8:  F_osd_char16_row = 16'h03c0;
                        4'd9:  F_osd_char16_row = 16'h03c0;
                        4'd10: F_osd_char16_row = 16'h03c0;
                        4'd11: F_osd_char16_row = 16'h03c0;
                        4'd12: F_osd_char16_row = 16'h03c0;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_COLON: begin
                    case(I_row)
                        4'd6:  F_osd_char16_row = 16'h0180;
                        4'd7:  F_osd_char16_row = 16'h0180;
                        4'd10: F_osd_char16_row = 16'h0180;
                        4'd11: F_osd_char16_row = 16'h0180;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                default: F_osd_char16_row = 16'h0000;
            endcase
        end
    endfunction

    assign O_video_rd_en = I_video_de;

    anlogic_logo_rom u_anlogic_logo_rom(
        .I_addr  ( S_logo_addr  ),
        .O_pixel ( S_logo_pixel )
    );

    // Compute the logo address alongside the existing coordinate pipeline.
    // It reaches stage 2 with S_x_2d/S_y_2d, so ROM decoding no longer shares
    // one pixel period with multiplication. Output pixel latency is unchanged.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) S_logo_addr <= 15'd0;
        else if(S_video_de_1d &&
                S_x_1d >= LOGO_X && S_x_1d < LOGO_X + LOGO_W &&
                S_y_1d >= LOGO_Y && S_y_1d < LOGO_Y + LOGO_H)
            S_logo_addr <= (S_y_1d-LOGO_Y)*LOGO_W + (S_x_1d-LOGO_X);
        else S_logo_addr <= 15'd0;
    end

    osd_char_lib u_osd_char_lib(
        .I_char     ( S_pf_char     ),
        .I_row      ( S_pf_row      ),
        .O_row_bits ( S_pf_row_bits )
    );

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_user) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_de) begin
            if(I_video_last) begin
                S_x <= 12'd0;
                S_y <= S_y + 12'd1;
            end
            else begin
                S_x <= S_x + 12'd1;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n)begin
      if(!I_rst_n)begin S_frame_cnt<=0;S_cnt_d0<=0;S_cnt_d1<=0;S_cnt_d2<=0;
        S_cnt_d3<=0;S_cnt_d4<=0;S_cnt_d5<=0;end
      else if(I_video_user)begin
        S_frame_cnt<=I_security_meta[255:224];
        {S_cnt_d5,S_cnt_d4,S_cnt_d3,S_cnt_d2,S_cnt_d1,S_cnt_d0}<=I_security_meta[197:174];
      end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x_1d <= 12'd0;
            S_x_2d <= 12'd0;
            S_y_1d <= 12'd0;
            S_y_2d <= 12'd0;
        end
        else begin
            S_x_1d <= S_x;
            S_x_2d <= S_x_1d;
            S_y_1d <= S_y;
            S_y_2d <= S_y_1d;
        end
    end

    always @(*) begin
        S_osd_hit   = 1'b0;
        S_osd_color = 24'd0;
        S_char_idx = 4'd0;
        S_char_row = 3'd0;
        S_char_col = 3'd0;
        S_char_bits = 5'd0;
        S_char_on = 1'b0;
        S_logo_blue_on = 1'b0;
        S_logo_red_on = 1'b0;
        S_logo_tmp_y = 12'd0;
        S_logo_red_band = 4'd0;
        S_logo_red_x_start = 12'd0;
        S_logo_red_x_end = 12'd0;
        S_dyn_x = 12'd0;
        S_dyn_y = 12'd0;
        S_dyn_char = 4'd0;
        S_dyn_col = 3'd0;
        S_dyn_row = 3'd0;
        S_dyn_bits = 5'd0;
        S_dyn_on = 1'b0;
        S_dyn_digit_idx = 4'd0;
        S_dyn_digit_x = 12'd0;
        S_dyn_seg = 7'd0;
        S_lbl_row = 3'd0;
        S_lbl_col = 3'd0;
        S_lbl_idx = 2'd0;
        S_lbl_bits = 5'd0;
        S_lbl_local_x = 7'd0;
        S_dyn_dec_digit = 4'd0;
        S_cn_local_x = 5'd0;
        S_cn_local_y = 5'd0;
        S_cn_col = 4'd0;
        S_cn_row = 4'd0;
        S_cn_row_bits = 16'd0;
        S_cn_on = 1'b0;
        S_cn_scale_x = 10'd0;
        S_cn_scale_y = 10'd0;
        S_pf_char = 8'd0;
        S_pf_local_x = 5'd0;
        S_pf_local_y = 5'd0;
        S_pf_col = 4'd0;
        S_pf_row = 4'd0;
        S_pf_on = 1'b0;
        S_pf_scale_x = 10'd0;
        S_pf_scale_y = 10'd0;

        if(S_video_de_2d) begin
            if((S_x_2d >= LOGO_X) && (S_x_2d < (LOGO_X + LOGO_W)) &&
               (S_y_2d >= LOGO_Y) && (S_y_2d < (LOGO_Y + LOGO_H))) begin
                if(S_logo_pixel[24]) begin
                    S_osd_hit   = 1'b1;
                    S_osd_color = S_logo_pixel[23:0];
                end
            end

            if((!S_osd_hit) &&
               (S_x_2d >= DYN_OSD_X) && (S_x_2d < (DYN_OSD_X + DYN_OSD_W)) &&
               (S_y_2d >= DYN_OSD_Y) && (S_y_2d < (DYN_OSD_Y + DYN_OSD_H))) begin
                S_dyn_x = S_x_2d - DYN_OSD_X;
                S_dyn_y = S_y_2d - DYN_OSD_Y;

                // Unified prefix render using one character library.
                // an:[0..23], lu:[24..47], C:[52..67], N:[68..83], T:[84..99], :[100..107]
                if((S_dyn_x < 12'd108) && (S_dyn_y < 12'd24)) begin
                    if((S_dyn_x < 12'd24) || ((S_dyn_x >= 12'd24) && (S_dyn_x < 12'd48))) begin
                        if(S_dyn_y >= CN_Y_OFFSET)
                            S_pf_local_y = S_dyn_y - CN_Y_OFFSET;
                        else
                            S_pf_local_y = 5'd31;

                        if(S_dyn_x < 12'd24) begin
                            S_pf_char = CHAR_AN;
                            S_pf_local_x = S_dyn_x;
                        end
                        else begin
                            S_pf_char = CHAR_LU;
                            S_pf_local_x = S_dyn_x - 12'd24;
                        end

                        if((S_pf_local_x < 5'd24) && (S_pf_local_y < 5'd24)) begin
                            S_pf_scale_x = S_pf_local_x * 10'd16;
                            S_pf_scale_y = S_pf_local_y * 10'd16;
                            S_pf_col = S_pf_scale_x / 10'd24;
                            S_pf_row = S_pf_scale_y / 10'd24;
                            case(S_pf_col)
                                4'd0:  S_pf_on = S_pf_row_bits[15];
                                4'd1:  S_pf_on = S_pf_row_bits[14];
                                4'd2:  S_pf_on = S_pf_row_bits[13];
                                4'd3:  S_pf_on = S_pf_row_bits[12];
                                4'd4:  S_pf_on = S_pf_row_bits[11];
                                4'd5:  S_pf_on = S_pf_row_bits[10];
                                4'd6:  S_pf_on = S_pf_row_bits[9];
                                4'd7:  S_pf_on = S_pf_row_bits[8];
                                4'd8:  S_pf_on = S_pf_row_bits[7];
                                4'd9:  S_pf_on = S_pf_row_bits[6];
                                4'd10: S_pf_on = S_pf_row_bits[5];
                                4'd11: S_pf_on = S_pf_row_bits[4];
                                4'd12: S_pf_on = S_pf_row_bits[3];
                                4'd13: S_pf_on = S_pf_row_bits[2];
                                4'd14: S_pf_on = S_pf_row_bits[1];
                                4'd15: S_pf_on = S_pf_row_bits[0];
                                default: S_pf_on = 1'b0;
                            endcase
                        end
                    end
                    else if((S_dyn_x >= 12'd52) && (S_dyn_x < 12'd100) && (S_dyn_y >= 12'd4) && (S_dyn_y < 12'd20)) begin
                        if(S_dyn_x < 12'd68) begin
                            S_pf_char = CHAR_C;
                            S_pf_local_x = S_dyn_x - 12'd52;
                        end
                        else if(S_dyn_x < 12'd84) begin
                            S_pf_char = CHAR_N;
                            S_pf_local_x = S_dyn_x - 12'd68;
                        end
                        else begin
                            S_pf_char = CHAR_T;
                            S_pf_local_x = S_dyn_x - 12'd84;
                        end
                        S_pf_local_y = S_dyn_y - 12'd4;
                        S_pf_col = S_pf_local_x[3:0];
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end
                    else if((S_dyn_x >= 12'd100) && (S_dyn_x < 12'd108) && (S_dyn_y >= 12'd4) && (S_dyn_y < 12'd20)) begin
                        S_pf_char = CHAR_COLON;
                        S_pf_local_x = S_dyn_x - 12'd100;
                        S_pf_local_y = S_dyn_y - 12'd4;
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd8;
                        S_pf_row = S_pf_local_y[3:0];
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                    end

                    if(S_pf_on)
                        S_dyn_on = 1'b1;
                end

                // Decimal 6 digits starts at x=110. Each digit is 15x24.
                if((S_dyn_x >= 12'd110) && (S_dyn_x < 12'd200)) begin
                    if(S_dyn_x < 12'd125) begin
                        S_dyn_digit_idx = 4'd0;
                        S_dyn_digit_x = S_dyn_x - 12'd110;
                        S_dyn_dec_digit = S_cnt_d5;
                    end
                    else if(S_dyn_x < 12'd140) begin
                        S_dyn_digit_idx = 4'd1;
                        S_dyn_digit_x = S_dyn_x - 12'd125;
                        S_dyn_dec_digit = S_cnt_d4;
                    end
                    else if(S_dyn_x < 12'd155) begin
                        S_dyn_digit_idx = 4'd2;
                        S_dyn_digit_x = S_dyn_x - 12'd140;
                        S_dyn_dec_digit = S_cnt_d3;
                    end
                    else if(S_dyn_x < 12'd170) begin
                        S_dyn_digit_idx = 4'd3;
                        S_dyn_digit_x = S_dyn_x - 12'd155;
                        S_dyn_dec_digit = S_cnt_d2;
                    end
                    else if(S_dyn_x < 12'd185) begin
                        S_dyn_digit_idx = 4'd4;
                        S_dyn_digit_x = S_dyn_x - 12'd170;
                        S_dyn_dec_digit = S_cnt_d1;
                    end
                    else begin
                        S_dyn_digit_idx = 4'd5;
                        S_dyn_digit_x = S_dyn_x - 12'd185;
                        S_dyn_dec_digit = S_cnt_d0;
                    end

                    // Render decimal digits through unified 16x16 character library.
                    // Keep enlarged 15x24 box for readability.
                    if((S_dyn_digit_x < 12'd15) && (S_dyn_y < 12'd24)) begin
                        S_pf_char = CHAR_0 + {4'd0, S_dyn_dec_digit};
                        S_pf_local_x = S_dyn_digit_x[4:0];
                        S_pf_local_y = S_dyn_y[4:0];
                        S_pf_scale_x = S_pf_local_x * 10'd16;
                        S_pf_scale_y = S_pf_local_y * 10'd16;
                        S_pf_col = S_pf_scale_x / 10'd15;
                        S_pf_row = S_pf_scale_y / 10'd24;
                        case(S_pf_col)
                            4'd0:  S_pf_on = S_pf_row_bits[15];
                            4'd1:  S_pf_on = S_pf_row_bits[14];
                            4'd2:  S_pf_on = S_pf_row_bits[13];
                            4'd3:  S_pf_on = S_pf_row_bits[12];
                            4'd4:  S_pf_on = S_pf_row_bits[11];
                            4'd5:  S_pf_on = S_pf_row_bits[10];
                            4'd6:  S_pf_on = S_pf_row_bits[9];
                            4'd7:  S_pf_on = S_pf_row_bits[8];
                            4'd8:  S_pf_on = S_pf_row_bits[7];
                            4'd9:  S_pf_on = S_pf_row_bits[6];
                            4'd10: S_pf_on = S_pf_row_bits[5];
                            4'd11: S_pf_on = S_pf_row_bits[4];
                            4'd12: S_pf_on = S_pf_row_bits[3];
                            4'd13: S_pf_on = S_pf_row_bits[2];
                            4'd14: S_pf_on = S_pf_row_bits[1];
                            4'd15: S_pf_on = S_pf_row_bits[0];
                            default: S_pf_on = 1'b0;
                        endcase
                        if(S_pf_on)
                            S_dyn_on = 1'b1;
                    end
                end

                if(S_dyn_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            O_hdmi_vsync     <= S_video_vsync_2d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            O_hdmi_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            O_hdmi_de        <= S_video_de_2d;
            S_video_data_1d  <= brightness_for_pixel ?
                {F_brightness(I_video_rd_data[23:16]),F_brightness(I_video_rd_data[15:8]),F_brightness(I_video_rd_data[7:0])} : I_video_rd_data;
            S_video_data_2d  <= S_video_data_1d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd128)
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < 12'd256)
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < 12'd384)
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < 12'd640)
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < 12'd896)
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h202020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= I_video_rd_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd256)
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                if(S_video_de_2d && security_hit)
                    O_hdmi_data <= security_color;
                else if(S_video_de_2d && focus_hit)
                    O_hdmi_data <= focus_color;
                else if(S_video_de_2d && color_hit)
                    O_hdmi_data <= color_color;
                else if(S_video_de_2d && pass_show && pass_hit)
                    O_hdmi_data <= pass_color;
                else if(S_video_de_2d && mode_label_hit)
                    O_hdmi_data <= mode_label_color;
                else if(S_osd_hit)
                    O_hdmi_data <= S_osd_color;
                else
                    O_hdmi_data <= S_video_data_2d;
            end
        end
    end

endmodule

// Independent HDMI-domain focus readout. Raw video pipeline is unchanged.
module focus_assist(
 input wire clk,rst_n,user,sw_enable,sw_reset,sample_valid,
 input wire[20:0]sample,input wire[11:0]x,y,
 output reg hit,output reg[23:0]color
);
 (* async_reg="true" *) reg[1:0]es,rs;
 reg ep,rp,en,reset_level;
 reg[9:0]exposure;
 reg[3:0]settle;
 reg[5:0]age;
 reg[12:0]filtered;
 reg[10:0]peak;
 reg ready;
 wire[12:0]next_filtered=filtered-{2'b0,filtered[12:2]}+{2'b0,sample[10:0]};
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin es<=0;rs<=0;ep<=0;rp<=0;en<=0;reset_level<=0;exposure<=0;settle<=0;age<=63;filtered<=0;peak<=0;ready<=0;end
  else begin
   es<={es[0],sw_enable};rs<={rs[0],sw_reset};
   if(user)begin
    ep<=es[1];rp<=rs[1];
    if(ep==es[1])en<=es[1];
    if(rp==rs[1])reset_level<=rs[1];
    if(age<63)age<=age+1'b1;
   end
   if(!en || (user && ((ep==es[1] && en!=es[1]) || (rp==rs[1] && reset_level!=rs[1]))) || age>=30)begin
    filtered<=0;peak<=0;ready<=0;settle<=0;
   end else if(sample_valid)begin
    if(sample[20:11]!=exposure)begin exposure<=sample[20:11];settle<=0;filtered<=0;peak<=0;ready<=0;end
    else if(settle<8)begin settle<=settle+1'b1;filtered<={sample[10:0],2'b0};end
    else begin
     filtered<=next_filtered;ready<=1;
     if(next_filtered[12:2]>peak)peak<=next_filtered[12:2];
    end
   end
   // Fresh handshake only; repeated display frames do not count as samples.
   if(sample_valid)begin age<=0;exposure<=sample[20:11];end
  end
 end
 function[15:0]dab;input[15:0]v;integer i;begin
  dab=v;for(i=0;i<4;i=i+1)if(v[i*4+:4]>=5)dab[i*4+:4]=v[i*4+:4]+4'd3;
 end endfunction
 reg[10:0]cs,ps;reg[15:0]cw,pw,cd,pd;reg[3:0]step;reg busy,show,good;
 wire[15:0]ca=dab(cw),pa=dab(pw);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin cs<=0;ps<=0;cw<=0;pw<=0;cd<=0;pd<=0;step<=0;busy<=0;show<=0;good<=0;end
  else if(user)begin
   cs<=filtered[12:2];ps<=peak;cw<=0;pw<=0;step<=0;busy<=1;show<=en;good<=ready;
  end else if(busy)begin
   cw<={ca[14:0],cs[10]};pw<={pa[14:0],ps[10]};cs<={cs[9:0],1'b0};ps<={ps[9:0],1'b0};step<=step+1'b1;
   if(step==10)begin busy<=0;cd<={ca[14:0],cs[10]};pd<={pa[14:0],ps[10]};end
  end
 end
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
  "W":glyph=35'b10001100011000110101101011101110001;
  "I":glyph=35'b01110001000010000100001000010001110;
  default:glyph=35'b0;
 endcase end endfunction

 // Text at x=512,y=504, 16px cells: F nnnn P nnnn, or WAIT.
 wire[11:0]lx=x-12'd512,ly=y-12'd504;
 reg a_box,a_text,a_good;reg[2:0]a_row,a_col;reg[7:0]a_char;
 reg[7:0]ch;
 always @*begin
  ch=" ";
  if(!good)case(lx[7:4]) 0:ch="W";1:ch="A";2:ch="I";3:ch="T";default:ch=" ";endcase
  else case(lx[7:4])
   0:ch="F";2:ch=8'h30+cd[15:12];3:ch=8'h30+cd[11:8];4:ch=8'h30+cd[7:4];5:ch=8'h30+cd[3:0];
   7:ch="P";9:ch=8'h30+pd[15:12];10:ch=8'h30+pd[11:8];11:ch=8'h30+pd[7:4];12:ch=8'h30+pd[3:0];
   default:ch=" ";endcase
 end
 wire[34:0]bits=glyph(a_char);
 wire ink=a_col<5 && a_row<7 && bits[34-(a_row*5+a_col)];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin a_box<=0;a_text<=0;a_good<=0;a_row<=0;a_col<=0;a_char<=0;hit<=0;color<=0;end
  else begin
   a_box<=show && x>=512 && x<768 && y>=232 && y<488 && (x<514 || x>=766 || y<234 || y>=486);
   a_text<=show && x>=512 && x<720 && y>=504 && y<520;
   a_row<=ly[3:1];a_col<=lx[3:1];a_char<=ch;a_good<=good;
   hit<=a_box || a_text;
   color<=a_box ? 24'h40ffff : (ink ? (a_good ? 24'h40ffff : 24'hffff40) : 24'h102030);
  end
 end
endmodule
