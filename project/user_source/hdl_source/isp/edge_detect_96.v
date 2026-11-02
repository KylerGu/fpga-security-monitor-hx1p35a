module edge_detect_96 #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter EDGE_TH    = 11'd80
)(
    output reg [10:0] O_focus_score,
    output reg O_focus_valid,
    input [1:0]         I_mode,
    input               I_clk,
    input               I_rst_n,
    input               I_tlast,
    input               I_tuser,
    input      [95:0]   I_tdata,
    input               I_tvalid,
    input               I_tready,
    output reg          O_tlast,
    output reg          O_tuser,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output              O_tready
);

assign O_tready = I_tready;
reg [1:0] frame_mode;
// The production AWB forwards frame-start before its delayed pixel stream.
// Accept that notification even when there is no valid pixel on this cycle.
wire [1:0] pixel_mode = I_tuser ? I_mode : frame_mode;
always @(posedge I_clk or negedge I_rst_n)
    if(!I_rst_n) frame_mode <= 0;
    else if(I_tuser) frame_mode <= I_mode;


// Full precision weighted grayscale: floor((R + 2*G + B)/4).
// Ten-bit sum preserves white=255; do not reuse the truncated Sobel luminance.
function [23:0] grayscale_rgb;
 input [23:0] pixel;
 reg [9:0] sum;
 begin
  sum={2'b0,pixel[23:16]}+{1'b0,pixel[15:8],1'b0}+{2'b0,pixel[7:0]};
  grayscale_rgb={sum[9:2],sum[9:2],sum[9:2]};
 end
endfunction
wire [23:0] pix0 = I_tdata[95:72];
wire [23:0] pix1 = I_tdata[71:48];
wire [23:0] pix2 = I_tdata[47:24];
wire [23:0] pix3 = I_tdata[23:0];

// Low-cost luminance approximation: R/4 + G/2 + B/4.  Its maximum is
// 253, so it cannot overflow an 8-bit result and requires no divider.
wire [7:0] gray0 = {2'b0,pix0[23:18]} + {1'b0,pix0[15:9]} + {2'b0,pix0[7:2]};
wire [7:0] gray1 = {2'b0,pix1[23:18]} + {1'b0,pix1[15:9]} + {2'b0,pix1[7:2]};
wire [7:0] gray2 = {2'b0,pix2[23:18]} + {1'b0,pix2[15:9]} + {2'b0,pix2[7:2]};
wire [7:0] gray3 = {2'b0,pix3[23:18]} + {1'b0,pix3[15:9]} + {2'b0,pix3[7:2]};

localparam IMG_WIDTH_GRP = (IMG_WIDTH >> 2);

// Use two grayscale samples per 4-pixel input beat.  Each sample represents
// a neighbouring pair of pixels, providing 640 horizontal edge samples while
// keeping the two line buffers small enough for this device.
wire [8:0] pair_sum0 = {1'b0,gray0} + {1'b0,gray1};
wire [8:0] pair_sum1 = {1'b0,gray2} + {1'b0,gray3};
// One preparation stage separates AWB clipping/luminance from Sobel.
// RAW, GRAY and frame controls share the same added cycle.
reg [95:0] prepared_raw, prepared_gray;
reg [7:0] pair0, pair1;
reg prepared_valid, prepared_user, prepared_last;
reg [1:0] prepared_mode;
always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        prepared_raw <= 0; prepared_gray <= 0;
        pair0 <= 0; pair1 <= 0;
        prepared_valid <= 0; prepared_user <= 0; prepared_last <= 0;
        prepared_mode <= 0;
    end else begin
        prepared_raw <= I_tvalid ? I_tdata : 96'd0;
        prepared_gray <= I_tvalid ? {grayscale_rgb(pix0),grayscale_rgb(pix1),grayscale_rgb(pix2),grayscale_rgb(pix3)} : 96'd0;
        pair0 <= pair_sum0[8:1]; pair1 <= pair_sum1[8:1];
        prepared_valid <= I_tvalid;
        prepared_user <= I_tuser;
        prepared_last <= I_tlast;
        prepared_mode <= pixel_mode;
    end
end

(* ram_style = "block" *) reg [15:0] line1_mem [0:IMG_WIDTH_GRP-1];
(* ram_style = "block" *) reg [15:0] line2_mem [0:IMG_WIDTH_GRP-1];

reg [10:0] x_grp;
reg [10:0] y_pos;

wire [15:0] top_word = line2_mem[x_grp];
wire [15:0] mid_word = line1_mem[x_grp];
wire [15:0] bot_word = {pair0,pair1};

wire [7:0] top0 = top_word[15:8];
wire [7:0] top1 = top_word[7:0];
wire [7:0] mid0 = mid_word[15:8];
wire [7:0] mid1 = mid_word[7:0];

reg [7:0] top_prev2, top_prev1;
reg [7:0] mid_prev2, mid_prev1;
reg [7:0] bot_prev2, bot_prev1;

function [21:0] sobel_gradient;
    input [7:0] a00, a01, a02;
    input [7:0] a10, a11, a12;
    input [7:0] a20, a21, a22;
    reg [9:0] left_sum, right_sum, top_sum, bottom_sum;
    reg signed [10:0] gx_f, gy_f;
    begin
        // Balanced positive sums: each side is at most 1020, difference
        // at most +/-1020. Preserve the original integer Sobel result.
        left_sum   = ({2'b0,a00} + {2'b0,a20}) + {1'b0,a10,1'b0};
        right_sum  = ({2'b0,a02} + {2'b0,a22}) + {1'b0,a12,1'b0};
        top_sum    = ({2'b0,a00} + {2'b0,a02}) + {1'b0,a01,1'b0};
        bottom_sum = ({2'b0,a20} + {2'b0,a22}) + {1'b0,a21,1'b0};
        gx_f = $signed({1'b0,right_sum}) - $signed({1'b0,left_sum});
        gy_f = $signed({1'b0,top_sum}) - $signed({1'b0,bottom_sum});
        sobel_gradient = {gx_f,gy_f};
    end
endfunction

// Two Sobel windows are evaluated per input beat. Each result is duplicated
// to its corresponding pair of output pixels.
wire [21:0] gradient0 = sobel_gradient(top_prev2,top_prev1,top0,
                             mid_prev2,mid_prev1,mid0,
                             bot_prev2,bot_prev1,pair0);
wire [21:0] gradient1 = sobel_gradient(top_prev1,top0,top1,
                             mid_prev1,mid0,mid1,
                             bot_prev1,pair0,pair1);

wire window_valid = (y_pos >= 11'd2) && (x_grp != 11'd0) && !prepared_user;
// Register the gradients before absolute value, magnitude and threshold.
// This cuts the asynchronous line-memory -> arithmetic -> output path.
reg [21:0] gradient0_reg, gradient1_reg;
reg [95:0] gradient_raw, gradient_gray;
reg gradient_valid, gradient_user, gradient_last, gradient_window_valid;
reg [1:0] gradient_mode;
function [13:0] gradient_magnitude;
    input [21:0] packed_gradient;
    reg signed [10:0] gx, gy;
    reg [10:0] ax, ay;
    begin
        gx=packed_gradient[21:11]; gy=packed_gradient[10:0];
        ax=gx[10] ? (~gx+1'b1) : gx;
        ay=gy[10] ? (~gy+1'b1) : gy;
        gradient_magnitude={3'b0,ax}+{3'b0,ay};
    end
endfunction
wire edge0 = gradient_window_valid && (gradient_magnitude(gradient0_reg) >= EDGE_TH);
wire edge1 = gradient_window_valid && (gradient_magnitude(gradient1_reg) >= EDGE_TH);
wire [23:0] out0 = edge0 ? 24'hffffff : 24'h000000;
wire [23:0] out1 = edge1 ? 24'hffffff : 24'h000000;
always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        O_tlast <= 0; O_tuser <= 0; O_tvalid <= 0; O_tdata <= 0;
    end else begin
        O_tlast <= gradient_last; O_tuser <= gradient_user;
        O_tvalid <= gradient_valid;
        if (!gradient_valid) O_tdata <= 0;
        else case (gradient_mode)
            2'd0: O_tdata <= gradient_raw;
            2'd3: O_tdata <= gradient_gray;
            default: O_tdata <= {out0,out0,out1,out1};
        endcase
    end
end

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        gradient0_reg <= 0; gradient1_reg <= 0;
        gradient_raw <= 0; gradient_gray <= 0;
        gradient_valid <= 0; gradient_user <= 0; gradient_last <= 0;
        gradient_window_valid <= 0; gradient_mode <= 0;
        x_grp    <= 11'd0;
        y_pos    <= 11'd0;
        top_prev2 <= 8'd0; top_prev1 <= 8'd0;
        mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
        bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
        // Do not clear line memories here.  A reset loop turns the 10-Kbit
        // buffers into slice registers on this device.  The first two rows
        // are masked by window_valid and naturally initialize both buffers.
    end else begin
        gradient0_reg <= gradient0; gradient1_reg <= gradient1;
        gradient_raw <= prepared_raw; gradient_gray <= prepared_gray;
        gradient_last <= prepared_last; gradient_user <= prepared_user;
        gradient_valid <= prepared_valid;
        gradient_window_valid <= window_valid;
        gradient_mode <= prepared_mode;

        if(prepared_user && !prepared_valid) begin
            x_grp <= 0; y_pos <= 0;
            top_prev2 <= 0; top_prev1 <= 0;
            mid_prev2 <= 0; mid_prev1 <= 0;
            bot_prev2 <= 0; bot_prev1 <= 0;
        end else if(prepared_valid) begin
            line2_mem[x_grp] <= mid_word;
            line1_mem[x_grp] <= bot_word;

            top_prev2 <= top0; top_prev1 <= top1;
            mid_prev2 <= mid0; mid_prev1 <= mid1;
            bot_prev2 <= pair0; bot_prev1 <= pair1;

            if(prepared_user) begin
                x_grp <= 11'd1;
                y_pos <= 11'd0;
            end else if(x_grp == IMG_WIDTH_GRP - 1) begin
                x_grp <= 11'd0;
                if(y_pos == IMG_HEIGHT - 1)
                    y_pos <= 11'd0;
                else
                    y_pos <= y_pos + 1'b1;
                top_prev2 <= 8'd0; top_prev1 <= 8'd0;
                mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
                bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
            end else begin
                x_grp <= x_grp + 1'b1;
            end
        end
    end
end

// Focus ROI: source support lies within the displayed center 256x256 box.
// 64 groups x 256 rows = 16384 samples. Sum fits in 25 bits (max 1976/sample).
reg focus_roi, focus_end, focus_start;
reg [24:0] focus_sum;
reg [14:0] focus_count;
wire [13:0] focus_mag = gradient_magnitude(gradient0_reg);
wire [10:0] focus_weight = focus_mag >= 14'd64 ? focus_mag[10:0]-11'd64 : 11'd0;
always @(posedge I_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin
  focus_roi<=0;focus_end<=0;focus_start<=0;focus_sum<=0;focus_count<=0;
  O_focus_score<=0;O_focus_valid<=0;
 end else begin
  focus_roi<=prepared_valid && window_valid && x_grp>=128 && x_grp<192 && y_pos>=232 && y_pos<488;
  focus_end<=prepared_valid && x_grp==IMG_WIDTH_GRP-1 && y_pos==IMG_HEIGHT-1;
  focus_start<=prepared_user;
  O_focus_valid<=0;
  if(focus_start)begin focus_sum<=0;focus_count<=0;end
  else if(focus_roi)begin focus_sum<=focus_sum+focus_weight;focus_count<=focus_count+1'b1;end
  if(focus_end && focus_count==15'd16384)begin
   O_focus_score<=focus_sum[24:14];O_focus_valid<=1;
  end
 end
end

endmodule
