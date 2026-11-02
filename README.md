# FPGA 智能安防监控 · DDR 时钟修复最终版

本目录是比赛工程公开交付版：最终源码、工程/IP、约束、验证脚本及唯一最终 bit 齐全，不含原开发 Git 历史。比赛提交页面要求填写项目工程 GitHub 链接；项目提交者确认 IP 与例程来自比赛官方资料，并确认本仓库以 Public 方式提交。保留厂商版权、来源和既有使用说明，不给第三方代码追加开源许可证。软件安装、许可和硬件另备。

仓库：[KylerGu/fpga-security-monitor-hx1p35a](https://github.com/KylerGu/fpga-security-monitor-hx1p35a) · [交付下载](https://github.com/KylerGu/fpga-security-monitor-hx1p35a/releases/tag/final-ddr-clock-fix-2026-11-01)。

冻结提交：`a8c0ae5504c1352735915eac2878e5b947572293`  
原冻结标签：`final-ddr-clock-fix-2026-11-01`  
最终 bit：[security_monitor_720p_ddr_fix.bit](bitstream/security_monitor_720p_ddr_fix.bit)，1,789,539 字节。  
SHA-256：`f787fd27c9d53362792d60e67884caa15f55bfa3df9f6659d756b129d1615e20`

先运行 `python -B tools/verify.py` 校验文件，再按[硬件与烧录](docs/HARDWARE_AND_FLASH.md)使用已有 bit，无需重新编译。已有 Flash 校验及三次冷启动成功记录来自冻结验收中的用户反馈；本次整理没有操作开发板。

| 目录/文件 | 内容 |
|---|---|
| `project/user_source/` | 冻结 RTL、厂商生成 IP 与引脚/时序约束，保持原字节 |
| `project/td_project/` | TD 工程和冻结构建 Tcl；仅 `.al` 的项目目录元数据改为相对路径 |
| `project/simulation/` | 完整 35 项功能、1 项语法及 DDR 时钟测试所需输入与测试夹具 |
| `bitstream/` | 唯一最终 bit |
| `tools/` | 不依赖原仓库/Git 历史的完整性、构建、仿真入口 |
| `docs/` | 功能操作、硬件连接、构建依赖、验证边界及分发说明 |
| `metadata/` | 冻结身份、逐文件来源、原构建输入、依赖与本次检查记录 |
| `MANIFEST.json`、`SHA256SUMS.txt` | 文件大小、来源类别与 SHA-256 |
| `releases/final_ddr_clock_fix_2026-11-01/README.md` | 本发布版保存与恢复入口 |

阅读：[功能操作](docs/OPERATING.md) · [硬件与烧录](docs/HARDWARE_AND_FLASH.md) · [构建与依赖](docs/BUILD.md) · [验证与限制](docs/VALIDATION.md) · [第三方范围](docs/THIRD_PARTY.md) · [GitHub 发布提案](docs/GITHUB_PROPOSAL.md)。

本目录不包含旧工程/旧 bit、开发流水账、原始对话、报告或视频编辑材料、缓存和 EDA 工具安装包。少量旧行为参考模块是明确隔离的测试夹具，不参与 FPGA 构建；具体来源和变换见 `metadata/test_fixtures.json`。新生成的构建 bit 只能写入另一个工作目录，不替换这里的冻结 bit。
