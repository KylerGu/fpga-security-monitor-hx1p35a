module isp_top (
    output wire[10:0] O_focus_score, output wire O_focus_valid,
    output wire O_raw_frame_start,O_raw_valid,O_raw_last,
    output wire[95:0]O_raw_rgb4,
    output wire[1:0]O_capture_mode,
    input [1:0] I_mode,
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready
);
 
wire         m_aixs_tvalid;  //synthesis keep 
  wire [127:0] m_aixs_tdata;  //synthesis keep 
  wire         m_aixs_tuser;  //synthesis keep 
  wire         m_aixs_tlast;  //synthesis keep 
  wire         m_aixs_tready;  //synthesis keep 
  
  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep 


  wire         awb_O_tlast;  //synthesis keep 
  wire         awb_O_tuser;  //synthesis keep 
  wire [ 95:0] awb_O_tdata;  //synthesis keep 
  wire         awb_O_tvalid;  //synthesis keep 
  wire         awb_O_tready;  //synthesis keep 

  wire         awb_O_tuser_128;  //synthesis keep 
  wire         awb_O_tvalid_128;  //synthesis keep 
  wire [127:0] awb_O_tdata_128;  //synthesis keep 

    wire         edge_O_tlast;  //synthesis keep
    wire         edge_O_tuser;  //synthesis keep
    wire [ 95:0] edge_O_tdata;  //synthesis keep
    wire         edge_O_tvalid;  //synthesis keep
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = awb_O_tlast    ;
  assign O_tuser  = awb_O_tuser_128    ;
  assign O_tvalid = awb_O_tvalid_128   ;
  
  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;
 
 
demosaic #(
    .IMG_HEIGHT          (720),  // 图像高度
    .IMG_WIDTH           (1280), // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);
 
data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(720),
    .IMG_WIDTH (1280)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

reg[1:0] security_frame_mode;
always @(posedge axi4s_video_aclk or negedge I_rst_n)
 if(!I_rst_n)security_frame_mode<=0;
 else if(awb_O_tuser)security_frame_mode<=I_mode;
assign O_capture_mode=awb_O_tuser ? I_mode : security_frame_mode;
assign O_raw_frame_start=awb_O_tuser;
assign O_raw_valid=awb_O_tvalid;
assign O_raw_last=awb_O_tlast;
assign O_raw_rgb4=awb_O_tdata;
edge_detect_96 #(
    .IMG_WIDTH (1280),
    .IMG_HEIGHT(720),
    .EDGE_TH   (11'd80)
) u_edge_detect_96 (
    .O_focus_score(O_focus_score),.O_focus_valid(O_focus_valid),
    .I_mode(O_capture_mode==2 ? 2'd0 : O_capture_mode),
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (awb_O_tlast),
    .I_tuser (awb_O_tuser),
    .I_tdata (awb_O_tdata),
    .I_tvalid(awb_O_tvalid),
    .I_tready(O_tready),
    .O_tlast (edge_O_tlast),
    .O_tuser (edge_O_tuser),
    .O_tdata (edge_O_tdata),
    .O_tvalid(edge_O_tvalid),
    .O_tready(awb_O_tready)
);

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( edge_O_tuser	    ),
        .I_96b_valid        ( edge_O_tvalid 		),
        .I_96b_data         ( edge_O_tdata		),
	
        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule
