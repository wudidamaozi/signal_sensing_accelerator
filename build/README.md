# 构建入口

环境：Vivado/Vitis HLS 2020.2，器件 `xc7z020clg400-1`，125MHz板载时钟经MMCM生成名义50MHz。此版本是已有仿真、布线与实板记录的复现环境，不宣称已在2025.2或2026.1复测。

`variants.json` 列出6个受控比较镜像和2个动态网页镜像，给出完整源依赖和原文件SHA。文件去重只合并字节相同的源；不因为同名而把分类与占用的不同私有副本混在一起。

```sh
python build/run_build.py --variant occupancy_live --vivado-bin VIVADO_BIN
python build/run_build.py --variant classification_live --vivado-bin VIVADO_BIN
python build/run_build.py --variant occupancy_native --vivado-bin VIVADO_BIN
```

新构建的初始化路径在生成副本中转为本机绝对路径，冻结源不改。原Vivado工程配方保留其VIO配置、约束、布局布线和时序门禁。`reports/` 为此前对应源的实际实现记录；新构建结果写入 `output/`，不能把历史记录改名当成新实现。

HLS源与常量在 `src/hls/`；从工程根调用安装的Vitis HLS：

```sh
vitis_hls -f build/scripts/hls_occupancy.tcl
vitis_hls -f build/scripts/hls_classification.tcl
```

占用HLS需维持2048的数组分割上限；2020.2对该上游配置命令会产生已归档的选项信息，配方保留其显式记录。完整HLS重综合可能较久，本轮工程包不会以文件检查冒充重新综合完成。两任务的冻结综合RTL也已包含，可直接重建PL镜像。

占用固件精确复编译：

```sh
python build/compile_occupancy.py --toolchain-prefix RISCV_GCC_PREFIX --output build/output/firmware_check
```

前缀应指向xPack RISC-V GCC15.2.0的 `riscv-none-elf-`，程序会核对二进制SHA，不只检查编译退出值。工具链与AMD工具不随包分发。


## 2026-11-01 最终补充

新增classification_cpu和occupancy_cpu，共10个variant。CPU-only构建和仿真与原8个实现共用入口；其固件源码在src/firmware/cpu_only，已归档程序与128KiB RAM初始化在data/memory。编译CPU固件使用compile_cpu.py，需显式传入xPack RISC-V GCC15.2.0-1的bin目录，并核对最终program.bin身份。不会下载或打包工具链。

网页现已接入完整分类测试集重评与四种实现对照；完整重评始终是本机软件计算。report/design_report.pdf和.docx为最终V8文档，报告图表、协作选段与CPU证据一起提供。旧的package_validation记录对应首版导出；本次验证见report/release_validation.json。
