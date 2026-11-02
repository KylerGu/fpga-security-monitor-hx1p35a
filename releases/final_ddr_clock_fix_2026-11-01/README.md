# 保存与恢复入口

本发布包来源：冻结提交 `a8c0ae5504c1352735915eac2878e5b947572293`，原仓库标签 `final-ddr-clock-fix-2026-11-01`。硬件源码提交 `f10e5845d347ae134a2beb1e45d77ee0f7319c12`。本入口是交付版重写，不包含开发仓库历史恢复流程。

1. 保存外层 RAR、外层文件清单和 SHA-256 指纹文件。
2. 先校验 RAR 的 SHA-256，再解压到新空目录，不覆盖开发仓库。
3. 在解压后的发布根目录执行 `python -B tools/verify.py`，核对 manifest 与 166 项冻结构建输入。
4. 已有 bit 可按[烧录说明](../../docs/HARDWARE_AND_FLASH.md)直接使用；要构建/仿真按[构建说明](../../docs/BUILD.md)安装合法依赖。

最终 bit：`bitstream/security_monitor_720p_ddr_fix.bit`，1,789,539 字节，SHA-256：`f787fd27c9d53362792d60e67884caa15f55bfa3df9f6659d756b129d1615e20`。

文件清单不将其自身摘要递归写入自身：`MANIFEST.json` 记录其余负载文件；`SHA256SUMS.txt` 另包含 MANIFEST 的摘要；外层指纹记录 RAR 及外层清单摘要。更改任何负载后都需重新生成版本清单和 RAR，不能沿用旧指纹。

不含旧 bit 或 Git 历史，不能在此包中 checkout 旧版本。原开发仓库和原标签保留在用户原位置，本次未修改；本地保存不等于已经异地备份。公开再分发状态见[第三方说明](../../docs/THIRD_PARTY.md)。
