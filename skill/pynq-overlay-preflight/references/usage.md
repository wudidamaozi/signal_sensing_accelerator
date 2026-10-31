# 使用说明

## 适用范围

单时钟、32位MMIO IP；镜像提供同目录同名 `.bit` / `.hwh`，使用PYNQ Overlay的ip_dict。清单参数与信号识别任务、板型、网络大小无关。文件检查与测试仅依赖Python 3.10+；解析HWH或下载时使用目标板镜像随附的PYNQ版本。API依据PYNQ 3.0 Overlay文档。

## 清单与命令

在工程目录外保存清单也可，`--root`始终指定镜像根目录。SHA用 `python -m` 所在环境的hashlib或系统SHA256工具计算并填入，不能填占位字符串：

```json
{
  "bit": "filter.bit", "hwh": "filter.hwh",
  "bit_sha256": "填写实际64位十六进制SHA256",
  "hwh_sha256": "填写实际64位十六进制SHA256",
  "ip_name": "filter_0", "base_address": 1136656384, "address_range": 4096
}
```

1. 普通电脑执行 `python scripts/preflight.py --root ./overlay --manifest overlay.json`，预期输出`PASS_FILES_ONLY`。
2. 目标PYNQ板执行同一命令加 `--inspect-hwh`，预期`PASS_HWH_NO_DOWNLOAD`。
3. 明确要加载该镜像时加 `--program`，预期`PASS_PROGRAMMED`。该步骤重配置PL，运行中的IP状态会被替换。
4. 应用导入`BoundedMMIO(base_address,address_range)`，调用read32/write32；按自身ABI启动并验证输出。

## 提炼依据与已验证效果

此前工程导出器假设HWH在 `.srcs/hw_handoff`，Vivado 2020.2实际位于 `.gen/hw_handoff`；采用配对镜像清单和SHA，使查找位置与应用接口分离。2026-10-29原PYNQ适配器有7项主机测试。本包将文件预检、解析与下载拆开，并允许调用者指定窗口大小；新增自测覆盖两种IP名称/地址/窗口、错误SHA、错误IP/基址/范围、路径逃逸、同名配对、缺HWH、MMIO对齐/越界及合法读写，记录在技能包evidence目录。

观察：人为损坏权重SRAM后，控制软复位没有恢复初始化值。因此应用恢复必须区分控制状态与模型存储，并以黄金输出核验恢复结果。

## 失效条件

文件SHA与地址一致不证明算法正确或来源可信；期望SHA须由使用者信任的构建过程生成。多个IP、DMA/cache一致性、多时钟、IRQ和多人并发需要应用自行适配。纯PL USB/JTAG bit配套LTX，不能用本Skill的PYNQ bit/HWH流程代替。主机测试采用合成文件及模拟对象，不代表在不同物理板卡上运行；更换板卡须重新生成匹配器件、时钟和PS配置的镜像并运行黄金输入。

官方依据：https://pynq.readthedocs.io/en/v3.0.0/pynq_libraries/overlay.html
