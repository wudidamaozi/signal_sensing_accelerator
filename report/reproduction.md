# 复现与版本

1. 解压到独立目录，不复制研发仓库的`.git`、虚拟环境、工具安装包或旧build。安装Python3.12和根requirements.txt。
2. 运行 `python sim/smoke.py --output build/output/offline_check`。核对SHA、30占用黄金样本和27项技能测试；失败时先看对应stdout/stderr，不跳过断言。
3. 需要RTL验证时安装Vivado2020.2，执行根README的两个动态输入仿真命令。初始化文件由冻结源的路径映射定位到本包，不依赖原电脑盘符。
4. 需要新bit时运行 `build/run_build.py`，它沿用实际采用的VIO/时钟/复位/布线配方；时序不通过就不会生成可验收镜像。新构建输出与历史报告分开。
5. USB线连接板载编程接口并供电，Vivado Hardware Manager确认一个xc7z020器件；设置EDGEAI_VIVADO_BIN，启动网页。没有SD卡也可用当前纯PL路线。
6. 按需执行 `board/run_board.py --program`。必须看实际bit/model身份、输出logits和周期；成功标准不是“看到DONE灯”。不写Flash。
7. 原始固定基准、交互接口和主机软件计时分别使用，不能把44381的交互分类记录改成44343，也不能把USB分钟级配置过程说成0.7ms整机响应。

AMD指南推荐2026.1/2025.2，也要求采用其他版本时说明并保证可复现。本包明确冻结Vivado/Vitis HLS2020.2、xPack RISC-V GCC15.2.0、hls4ml1.3.0、Python3.12与NumPy2.4.6，未宣称跨版本零修改验证。源和参数SHA用于核对身份，旧报告用于追溯，不替代本机重建日志。


## 最终发布补充

当前正式报告为design_report.pdf / design_report.docx。分类完整11982帧测试子集已包含，可运行python sim/reevaluate_classification.py --output build/output/full_test（从仓库根目录）。这只是软件参考重评，不表示全部帧已上板。

两项纯CPU构建、仿真和USB/JTAG入口见根README的新增复现入口。python sim/verify_release.py --output build/output/release_check --full-test 可检查包身份、两项参考、27项技能测试、10个variant依赖、4种方法各任务的8行数据、报告身份、本机HTTP入口及完整分类重评，不操作板卡。
