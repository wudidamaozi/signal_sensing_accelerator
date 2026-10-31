---
name: edge-int8-validation
description: Validate integer neural-network boundaries and FPGA routed timing, and record comparable optimization trials using explicit model, workload and measurement identities.
---

# INT8边界与FPGA试验验证

适用于已能导出整数边界的推理实现，以及已从实现报告提取时序字段的FPGA工程。输入来自调用者，不依赖信号类别、阵列尺寸或本机路径。

先读取 [工作流与来源](references/workflow.md)，确定整数契约、独立参考和计时边界。使用本目录内脚本：

```sh
python scripts/check_npz_equivalence.py --expected golden.npz --actual rtl.npz --keys input_q,layer1_q,logits
python scripts/check_routed_summary.py routed.json
```

NPZ按字段逐字节比较，dtype与shape也须相同。时序摘要必须明确器件、周期、实现范围、setup/hold裕量和路由错误。单独通过摘要检查仅说明这些显式字段满足门槛；完整实现仍须查看约束覆盖和DRC。

新增试验时复制 [summary模板](assets/trial_summary.json)，在新目录记录接受或拒绝及理由。先保留基线，运行修改与真实回退，并核对源身份。改变模型、输入、编译参数、时钟或计时边界时，解释差异后再决定能否计算直接速度比。

将准确率、层输出、XSim周期、板内计数、主机往返和功耗分别记录。模型回答给出的是候选判断，运行输出决定是否接受。

运行 `python scripts/self_test.py` 可在临时目录复核正例与故障注入；需要Python 3.11+和NumPy。失效边界、历史效果和可迁移提示词见工作流文档。
