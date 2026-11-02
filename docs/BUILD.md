# 构建、仿真与依赖

本包提供冻结构建输入和独立入口；不需要原开发仓库、旧工程或 Git 历史。**它不是包含 EDA 工具和许可的离线自足环境。** 本次实际验证范围见 [VALIDATION.md](VALIDATION.md)，不要把工程展开成功当成全流程布局布线/时序通过。

| 依赖 | 版本/用途 | 是否随包 |
|---|---|---|
| Windows x64 | 本次检查平台；其他系统未验证 | 否 |
| Anlogic Tang Dynasty | 6.2.168116，构建日志标识 Built Jun 12 2025；含 PH1P35 器件库、BitWriter、`sim_release/ph1p` | 否，合法安装及许可另备 |
| DDR IP | `MIS_DDRF6F1D0P0_1.1` 的冻结生成结果；构建不重新生成 | 仅项目所需生成文件；保留版权及比赛资料来源 |
| ModelSim Altera Starter Edition | vsim 10.3c / Altera 14.1，2014.09 Sep 20 2014 | 否，仿真时另备 |
| Python | 本次 3.13；脚本仅标准库，预期 3.10+，其他版本未实测 | 否 |
| Git | 仅未来创建独立发布仓库时使用；构建/仿真不需要 | 否 |

从发布根目录在 PowerShell 执行，工作目录必须不存在；使用短英文路径可减少老工具的路径兼容问题：

```powershell
python -B tools/verify.py
$env:TD_ROOT = 'D:/TD'  # 改为本机合法安装位置
$env:VSIM = 'D:/altera/14.1/modelsim_ase/win32aloem/vsim.exe'
python -B tools/run.py elaborate --work D:/fpga_checks/elaborate_01
python -B tools/run.py simulate --work D:/fpga_checks/simulate_01
python -B tools/run.py build --work D:/fpga_checks/build_01
```

`--td-root`、`--vsim` 可代替环境变量。入口先验证交付文件，再复制到独立工作目录。`.al` 的项目根目录只在工作副本中写成当前绝对路径；源码、引脚和 SDC 不改。运行 TD 的目录为工作副本，不会回写发布源文件或原开发仓库。每次仿真使用新目录和独立 TEMP/TMP，不采纳旧成功日志。

`elaborate` 运行原编译 Tcl 至 `commit_param -step rtl` 之前：导入器件、展开顶层、加载引脚/IP/SDC，不做综合优化、布局布线或 bitgen。`simulate` 执行 35 项功能、1 项语法以及实际 DDR PLL/时钟 RTL 模型专项；不验证完整 DDR 控制器与 DRAM 协议。两份亮度参考模块仅为对比测试夹具，来源与模块重命名记录在 `metadata/test_fixtures.json`，不加入 TD 工程。

`build` 依次运行冻结的 `compile_security.tcl`、`bitgen_security.tcl`，输出在工作目录的 `project/td_project/security_build/`。入口 PASS 只表示工具流程结束和生成文件存在；必须审查 `final_timing.rpt`、`checks.rpt`、各 CDC bundle/sync 报告及告警，再上板验证。它不把新 bit 认证为冻结最终版，也不覆盖随包 bit。工具/路径/随机因素可能令重新生成的 bit 与冻结 SHA 不同，不能悄悄替换最终 bit。

冻结 DDR 参数：参考 50 MHz，DDR 266.667 MHz，用户/控制 66.667 MHz，配置 50 MHz，tCK=3750 ps、MDL HALF、nREFI/nRFC/nWR=2080/28/4。PLL0 VCO 800 MHz、PLL1 VCO 1600 MHz。原生成过程采用厂商 Dependency/Tcl 脚本与已冻结接口种子，并非 GUI 导出；最终生成结果已随包，稳定恢复不需要重走生成过程。旧的依赖 Git/历史基线的生成、scope 和发布脚本不作为本包入口。

`sim/fileset/fileset_mis.f` 中 `<mis_path>` 是厂商通用仿真文件集占位符，主工程和本包专项仿真不调用该模板。若另建完整 DRAM 仿真需自行提供合法模型并替换占位符。DDR3/DDR4 头文件出现在未启用的条件编译分支中，当前 `DRAM_DDR2` 配置不使用它们。

项目可执行引用不再指向 `D:/FPGA_2026`。保留的原始元数据中工具模型路径只是冻结证据来源；不会被独立入口作为固定安装路径执行。TD/ModelSim 的安装目录仍须由使用者配置。

另有两处厂商 RAM 文件头保留 `E:/vlkus/...` 原生成路径，仅为注释；不参与工程加载，未为清理路径而改动冻结源码。路径审计记录在 `metadata/path_audit.json`。
