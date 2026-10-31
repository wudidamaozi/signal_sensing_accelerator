---
name: pynq-overlay-preflight
description: Check PYNQ bit and HWH pairs, IP address maps and bounded MMIO before explicitly loading an overlay; reusable across single-clock MMIO projects with caller-supplied manifests.
---

# PYNQ镜像与MMIO预检

使用调用者提供的镜像与清单，先验SHA及同名bit/HWH，再检查HWH的IP地址范围，最后按用户要求加载。IP名称、基址和范围均通过清单指定，可用于CNN之外的图像滤波、计数器或其他MMIO IP。

阅读 [操作说明与边界](references/usage.md)。本目录 `scripts/preflight.py` 默认只核验文件；`--inspect-hwh` 在PYNQ环境解析HWH但不下载；`--program` 才显式重配置PL。执行硬件操作须符合当前用户请求，不能将文档示例视为执行授权。

```sh
python scripts/preflight.py --root ./overlay --manifest overlay.json
python scripts/preflight.py --root ./overlay --manifest overlay.json --inspect-hwh
```

后续寄存器访问使用同文件的`BoundedMMIO`，所有偏移按32位对齐并限制在清单范围内。ABI、模型身份、复位及黄金输出由应用层继续验证。

运行 `python scripts/self_test.py` 可在普通PC完成仿真对象测试。效果记录为主机对象测试；实际下载与新板卡兼容性由目标PYNQ环境验证。
