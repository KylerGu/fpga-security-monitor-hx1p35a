# 硬件连接与烧录

需要 HX1P35A V1.0、SC520CS 对应摄像头模组与匹配排线、HDMI 显示器/线、可传数据的 USB 下载线及开发板规定的供电。摄像头接该板匹配的 MIPI 摄像头接口；按开发板手册核对排线方向和供电，再上电。本包未复印厂商手册，连接器编号和电源规格以所持硬件版本手册为准，不能套用其他板型引脚。

板载集成 DDR2：512 Mbit、x16；无需外接 DDR 模块。连接板载 HDMI 输出至显示器，USB 下载口至 PC。按板卡要求供电；仅电源灯亮不能证明 USB 数据连接正常。

关键 FPGA 引脚从冻结 `project/user_source/constraints_source/pin.adc` 提取：

| 信号 | 引脚 |
|---|---|
| 50 MHz 晶振 | C4 |
| KEY1 / KEY2 / KEY3 / KEY4 | D5 / A9 / B9 / C7 |
| SW1 / SW2 / SW3 / SW4 | A4 / B4 / E11 / D11 |
| LED[0..3] | D10 / E10 / C6 / D6 |
| 蜂鸣器低有效输出 | C12；高电平静音；SW5 硬件控制 |
| 摄像头 SCL / SDA / 参考时钟 / 复位 | K3 / J3 / L3 / L2 |
| HDMI 数据 CH0 / CH1 / CH2 正端 | G16 / F17 / H14 |
| HDMI 时钟正端 | C17 |

MIPI 专用 I/O、差分配对及 DDR 专用引脚由原器件/IP配置管理；不可只根据上表迁移板型。完整约束以包内 ADC、SDC 和 IP 配置为准。信号名 `O_cam_24m` 不表示精确 24 MHz：冻结 PLL 输出约 23.809524 MHz。

## 使用最终 bit

1. 在发布根目录运行 `python -B tools/verify.py`，确认 PASS。
2. 安装合法的 TD 6.2.168116、官方下载器驱动；启动 TD 安装目录下 `bin/bw.exe`（BitWriter）。
3. 选择 `AL-LINK-FT (Local Host)`、端口 `5555`，设置窗口 Refresh、Apply and Close，主窗口 Refresh；确认器件为 `PH1P35MDG324`。
4. 选择包内 `bitstream/security_monitor_720p_ddr_fix.bit`。临时下载用 `PROGRAM_SRAM`、5 MHz、Run；以本次新日志成功为准，旧绿色 100% 可能残留。
5. 固化用 `PROGRAM_FLASH`、5 MHz、128 Mbits；成功后对同一 bit 执行 `VERIFY_FLASH`。这些参数来自最终交付操作记录，应核对实际板卡 Flash 配置。
6. 冷启动检查需断开所有可能供电的连接，确认电源灯熄灭，再重新供电；不点 Run，不按复位，观察自动出图。

SRAM 下载断电丢失；Flash 决定下次上电启动内容。本次整理未执行任何烧录。冻结记录包含新版 Flash 写入/校验成功、3 次完全断电后自动出图的用户反馈，没有板内 SHA 读回或新版原始烧录日志。

无法连接时先检查 USB 数据线、Windows 下载器枚举、hwserver 和 5555 监听，再检查驱动。摄像头未连接通常不影响下载器枚举。黑屏时先区分下载成功与视频链路，核对摄像头排线、HDMI输入、SW状态和目标 bit。
