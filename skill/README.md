# Reusable skills

本目录面向陌生队伍独立使用；不需要本项目的模型或FPGA即可运行前两项自测。

| 技能 | 适用与用法 | 已验证效果 | 失效边界 |
|---|---|---|---|
| edge-int8-validation | 比对整数NPZ边界；检查布线摘要。运行scripts/self_test.py | 14个正反例；值、dtype、shape、缺字段、非有限裕量等错误被拒绝 | 两份数据共享错误或摘要遗漏约束时，仍需独立参考和完整实现报告 |
| pynq-overlay-preflight | bit/HWH身份与映射、MMIO边界。运行scripts/self_test.py | 13项主机对象测试；路径、SHA、IP及范围检查。短路径与长路径规范化在副本中修正 | 单时钟32位MMIO；DMA、IRQ、多时钟、USB/LTX需对应适配；不以mock代替实板 |
| edgeai-experiment-evidence | 阅读SKILL.md，复用试验身份、失败保留和配对对照流程 | 本项目的模型/输入/时钟/接口对齐、拒绝宽阵列和历史混比的记录 | 不同模型或边界不能强算倍率 |
| edgeai-int8-equivalence | 阅读SKILL.md，组织NumPy/C/RTL独立边界比对 | 当前项目逐层整数与logits检查 | 数值一致不能替代数据集准确率与泛化验证 |
| edgeai-resource-triage | 阅读SKILL.md，区分容量、时序、OOC和完整实现 | 同32PE候选与基线配对，setup/hold/路由共同门禁 | 资源放得下不代表时序通过；不推断未测功耗 |

```sh
python edge-int8-validation/scripts/self_test.py
python pynq-overlay-preflight/scripts/self_test.py
```

每项入口内保留来源案例与排查过程。前两项能单独复制运行，依赖Python3.11+及NumPy。通用PYNQ技能不绑定本作品，也不意味着本作品当前使用PYNQ Overlay；当前演示走USB/JTAG。
