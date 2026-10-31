# Signal Sensing Accelerator

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

工程内路径采用英文小写；README.md、SKILL.md、LICENSE 和 Git 配置文件按约定保留名称。文件正文可用中文。研发仓库中未选中版本、工具安装目录、虚拟环境、完整数据集和旧历史不在本包内。

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

打开 `http://127.0.0.1:8771/`。页面可查看准确率、板测基准、竞速回放和硬件图；实际推理按钮需要本机 FPGA。演示池为分类80帧、占用195帧，曲线来自已归档完整留出集，不把小池重新算成完整准确率。

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

| 任务 | 本系统板内周期 | hls4ml板内周期 | 本系统 LUT / FF / BRAM36 / DSP |
|---|---:|---:|---|
| 调制识别（固定基准输入） | 44343 | 46283 | 7484 / 7350 / 18.5 / 36 |
| 占用检测（两输入相同周期） | 35629 | 37552 | 8556 / 8019 / 20 / 30 |

表中资源均为包含处理器、存储和测试/调试逻辑的基准工程，不混入较小的网页 VIO 镜像。名义时钟50MHz，占用0.71258ms，对hls4ml低5.12%；完整对照及输入数量见 `report/evidence/`。网页交互分类已有44381周期的独立接口记录，不能替换44343基准数字。板内周期不包含USB配置、主机预处理或分类融合时间；竞速动画是实测周期比例回放。

## 提交与授权

自研部分使用 MIT；第三方代码保留原许可，RadioML来源样本另适用CC BY-NC-SA 4.0，详见 `third_party_notices.md`。指南推荐工具为2026.1/2025.2，本项目现有数据来自2020.2，已按其“其他版本须说明并保证可复现”的条款单列。正式平台上传材料及尚需人工核对的报告项见 `report/requirements_matrix.md`，不把工程包通过等同于视频、签署件和最终PDF已提交。
