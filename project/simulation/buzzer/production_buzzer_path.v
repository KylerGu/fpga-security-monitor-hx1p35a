module production_buzzer_path(
 input wire I_sys_clk,S_rst_sys,
 input wire S_capture_overflow,S_camera_interrupted,S_camera_armed,S_camera_alarm,
 input wire[63:0]S_control,
 output wire[3:0]O_security_led,output wire O_buzzer_n
);
    (* async_reg="true" *)reg[3:0]S_led_sync1,S_led_sync2;
    always @(posedge I_sys_clk or negedge S_rst_sys)
      if(!S_rst_sys)begin S_led_sync1<=0;S_led_sync2<=0;end
      else begin S_led_sync1<={S_capture_overflow,S_camera_interrupted,S_camera_armed,S_camera_alarm};S_led_sync2<=S_led_sync1;end
    assign O_security_led=S_led_sync2;
    // Reuse the synchronized alarm; local disarm/setup also mutes immediately.
    security_buzzer u_security_buzzer(.clk(I_sys_clk),.rst_n(S_rst_sys),
      .enable(S_led_sync2[0] && S_control[3] && !S_control[4]),
      .buzzer_n(O_buzzer_n));
endmodule
