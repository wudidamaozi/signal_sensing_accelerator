# 基于FPGA的信号感知加速系统

正式设计报告以本目录的[PDF](design_report.pdf)与[可编辑Word](design_report.docx)为准，两者对应已确认的V8，共28页。报告按最终提交工程和CPU补充结果撰写，不用历史候选版本替代最终成果。

四种实现为RISC-V纯软件、自研4×8加速器、hls4ml和Caffe im2col移植＋4×8 GEMM。原始数值见four_method_board_results.csv；模型准确率与板内CNN计时采用报告中各自的测试范围。

配套材料：figures下的图表、实板照片及真实返回截图；ai_collaboration.md的过程整理；ai_collaboration.jsonl的原始交互选段；evidence中的模型、实板与实现记录；skill_fix中的脚本修正记录。report_quality_check.json记录报告结构与版式核验。

本次发布补齐11月1日分类完整测试集重评入口和两项CPU-only对照依赖，主CNN模型、4×8加速器及已确认镜像不变。CPU源代码、内存初始化、构建脚本和板测入口已整理进标准目录，不要求接收方使用原研发电脑路径。完整分类留出重评使用包内11982帧，是本机软件推理，不是FPGA板测。
