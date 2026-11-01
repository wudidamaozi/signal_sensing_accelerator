# 基于FPGA的信号感知加速系统

## 基于FPGA的信号感知加速系统技术文档

**[在线阅读 PDF](report/基于FPGA的信号感知加速系统技术文档.pdf) · [下载可编辑 Word](report/基于FPGA的信号感知加速系统技术文档.docx)**

这是已确认的V8最终技术文档，共28页。报告配图、实板照片、大模型协作记录及性能数据在[报告资料目录](report/README.md)。正式技术文档采用中文文件名，便于直接查找。


基于 AMD PYNQ-Z2（XC7Z020CLG400-1）的信号感知加速系统。RISC-V 软核负责任务配置，4×8 并行阵列执行 INT8 乘法、INT32 累加；支持无线调制识别与频谱占用检测。两个任务分别加载各自镜像，网页负责输入、量化与展示；分类另有主机 FP32 统计融合分支。

## 目录

| 目录 | 内容 |
|---|---|
| `src/rtl/` | 当前两任务及 hls4ml、im2col 对照的冻结 RTL，按字节相同内容去重；原文件名与路径映射见清单 |
| `src/hls/` | 两任务真正的 hls4ml 生成 C++、权重常量与必要公开头文件 |
| `src/firmware/` | 选中 RISC-V C 程序、配置头、链接脚本与编译身份 |
| `src/software/`、`src/web/` | 独立推理参考、精简网页服务与前端，不含训练环境和旧启动器 |
| `sim/` | 仿真入口、测试台、冻结日志及离线检查 |
| `build/` | 可复现 Vivado/HLS/固件构建入口、资源与时序报告；新结果写入 `build/output/` |
| `board/` | 实板镜像、约束、运行脚本及基准镜像 |
| `data/` | 冻结模型、小型演示输入、初始化 ROM 和黄金输出，不打包完整 RadioML |
| `skill/` | 两项可执行通用技能、三项工作流指南，含正反例和失效条件 |
| `report/` | 当前设计说明、指标证据、AI 协作选段、规范对应表和来源 SHA |

除两份正式技术文档按展示需要采用中文文件名外，工程代码与脚本路径采用英文小写；README.md、SKILL.md、LICENSE 和 Git 配置文件按约定保留名称。文件正文可用中文。研发仓库中未选中版本、工具安装目录、虚拟环境、完整数据集和旧历史不在本包内。

## 从零检查

需要 Python 3.12，依赖为 NumPy（本次验证 2.4.6）：

```sh
python -m pip install -r requirements.txt
python sim/smoke.py --output build/output/offline_check
```

检查文件身份、30 个占用黄金输入、两个独立参考调用和 27 项技能测试；**此命令不访问板卡**。输出目录须全新，失败日志保留，不覆盖旧记录。

## 网页演示

```sh
python build/run_web.py
```

打开 `http://127.0.0.1:8771/`。页面可查看准确率、板测基准、竞速回放和硬件图；实际推理按钮需要本机 FPGA。演示池为分类80帧、占用195帧。分类页另有“重新评估完整测试集”按钮，使用包内11982帧固定留出集逐帧运行本机INT8参考与FP32融合，不是FPGA板测；同一模型与数据重跑不改变准确率。该留出子集适用RadioML原数据许可，不包含训练集。

当前实板路线是 **USB/JTAG/VIO → AXI → 邮箱 → RISC-V → CNN 加速器**，不需要 SD 卡、网线或 PYNQ Linux。请安装 Vivado 2020.2 和板载 USB 驱动，启动本机硬件服务器，并按实际安装位置配置：

```powershell
$env:EDGEAI_VIVADO_BIN="VIVADO_BIN"
python build/run_web.py
```

`VIVADO_BIN` 应替换为本机包含 `vivado.bat` 的 bin 文件夹，不是账号或令牌。每次网页推理会切换对应易失配置，失败会报错，不以软件结果冒充实板。

## 独立实板与仿真

```sh
python board/run_board.py --task occupancy --program --output build/output/occupancy_board.json
python board/run_board.py --task classification --program --output build/output/classification_board.json
python sim/run_xsim.py --variant occupancy_live --vivado-bin VIVADO_BIN --output build/output/occupancy_sim
python sim/run_xsim.py --variant classification_live --vivado-bin VIVADO_BIN --output build/output/classification_sim
```

`--program` 明确允许下载易失 FPGA 配置，不写 Flash。Vivado 端口和时序错误、模型/bit SHA 不符、返回 logits 不一致都会导致失败。构建和可用 variant 见 `build/README.md`，复现步骤及工具版本说明见 `report/reproduction.md`。

## 已确认的结果

| 任务 | 实现 | 板内周期范围 | LUT / FF / BRAM36 / DSP |
|---|---|---:|---|
| 调制识别 | RISC-V纯软件 | 72713190 | 2827 / 3541 / 32.0 / 4 |
| 调制识别 | im2col＋4×8 GEMM | 1554656 | 7473 / 7349 / 18.5 / 36 |
| 调制识别 | hls4ml | 46283 | 36386 / 42260 / 17.0 / 68 |
| 调制识别 | 自研加速器 | 44343 | 7484 / 7350 / 18.5 / 36 |
| 频谱占用 | RISC-V纯软件 | 27075892–27082616 | 4054 / 4653 / 32.0 / 4 |
| 频谱占用 | im2col＋4×8 GEMM | 6840614–6851494 | 6881 / 6615 / 53.5 / 36 |
| 频谱占用 | hls4ml | 37552 | 28586 / 46590 / 20.0 / 46 |
| 频谱占用 | 自研加速器 | 35629 | 8556 / 8019 / 20.0 / 30 |

名义时钟50MHz，数值来自既有实板计数与完整PL实现。主机预处理、USB配置与分类融合不计入CNN区间；分类CPU为五段计数之和，占用为邮箱输入复制至logits。CPU纯软件使用128KiB RAM且没有CNN硬件实例；分类加速器基准为16KiB，频谱占用自研/hls4ml为8KiB、im2col为128KiB。资源包含处理器、存储和基准调试逻辑，不能解释为独立计算核面积。网页动态分类44381周期与固定基准44343周期分别保存。

## 新增复现入口

```sh
python sim/verify_release.py --output build/output/release_check
python sim/reevaluate_classification.py --output build/output/full_classification_test
```

第一条只运行离线和本机HTTP检查；加`--full-test`会重新计算11982帧。第二条为独立完整测试集重评入口。两者不操作FPGA。

两个CPU-only实现已纳入`build/variants.json`，名称为`classification_cpu`和`occupancy_cpu`。源码分别位于`src/rtl/cpu_only/`与`src/firmware/cpu_only/`，ROM在`data/memory/`，镜像在`board/benchmarks/`，原始结果在`report/evidence/`。可通过统一入口重新构建或仿真：

```sh
python sim/run_xsim.py --variant classification_cpu --vivado-bin VIVADO_BIN --output build/output/classification_cpu_sim
python build/run_build.py --variant classification_cpu --vivado-bin VIVADO_BIN
python build/compile_cpu.py --task classification --toolchain-bin RISCV_GCC_BIN --output build/output/classification_cpu_firmware
```

将classification替换为occupancy可处理另一任务。固件编译使用xPack RISC-V GCC15.2.0-1，编译入口核对二进制与冻结板测程序完全一致。CPU实板入口需明确允许下载易失配置：

```sh
python board/run_cpu.py --task classification --program --output build/output/classification_cpu_board
```

以上VIVADO_BIN与RISCV_GCC_BIN均替换为本机相应bin目录，不包含账号或凭据。输出目录须全新。此次发布没有重新上板，既有板测证据保持；源码路径适配、固件二进制重建和离线验证单独记录。

## 提交与授权

自研部分使用 MIT；第三方代码保留原许可，RadioML来源样本另适用CC BY-NC-SA 4.0，详见 `third_party_notices.md`。指南推荐工具为2026.1/2025.2，本项目现有数据来自2020.2，已按其“其他版本须说明并保证可复现”的条款单列。正式平台上传材料及尚需人工核对的报告项见 `report/requirements_matrix.md`，不把工程包通过等同于视频、签署件和最终PDF已提交。
