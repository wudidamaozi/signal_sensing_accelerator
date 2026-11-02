# 换机运行：工程补充入口

技术报告Word/PDF及其原复现说明保持冻结。本文件仅补充换机安装、网页启动与检查入口，不改变模型、硬件和报告指标。

## Windows启动网页

1. 安装64位Python 3.12，并使`python`命令可用。
2. 解压RAR或下载GitHub源码到独立目录，首次联网运行`setup_windows.cmd`。只安装项目本地`.venv`和固定版本NumPy，不需要训练框架。
3. 运行`start_web.cmd`，打开`http://127.0.0.1:8771/`。不要直接双击HTML文件。

无板时默认选择“本机软件参考推理”：分类、占用、波形、频谱、结果导出、完整分类重评、性能对照和硬件图均可使用。软件结果明确标注来源；性能对照保留技术文档的归档实板数据，不把当前电脑的软件耗时写成FPGA时延。

命令行等价入口：

```sh
python build/setup_environment.py
.venv/Scripts/python.exe build/run_web.py --backend software
```

## 连接FPGA

按冻结技术文档安装Vivado2020.2及USB驱动、连接PYNQ-Z2。启动前设置本机工具目录：

```powershell
$env:EDGEAI_VIVADO_BIN="D:/your_vivado/Vivado/2020.2/bin"
.venv/Scripts/python.exe build/run_web.py --backend fpga
```

路径换成新电脑的实际目录。在两任务的“结果来源”中选择USB FPGA推理；板卡失败会显示错误，不会自动换成软件结果。原命令`python build/run_web.py`仍默认FPGA，保持技术文档行为。端口被占用时显式使用`--port 8773`，不静默切换端口。

## 验证与仿真

冻结文档中的`sim/verify_release.py --full-test`命令继续可用。新增补充检查：

```sh
.venv/Scripts/python.exe sim/check_portability.py --output build/output/portable_check
.venv/Scripts/python.exe sim/reevaluate_occupancy.py --output build/output/occupancy_full_test
```

输出目录需全新。两任务固定对照的真实测试台配置已修正，原`sim/run_xsim.py --variant ...`接口不变。需要RTL仿真时使用Vivado2020.2；不需要从开发电脑复制虚拟环境、旧build、完整RadioML或工具安装目录。

Vivado2020.2的仿真输出目录使用纯英文路径，例如`--output D:/fpga_runs/occupancy_sim`。入口会把必要存储文件复制到该输出目录，避免工具处理源目录中的中文/空格路径；交付原始RTL不改。

完整占用固定留出输入/标签以分片形式放在`data/fixtures/occupancy_test/`，用于重算文档中的INT8准确率/Pd/Pfa；不是新采集数据，也不用于重训或调参。完整分类测试集保持原11982帧。网页和数据来自包内文件，不依赖旧电脑盘符、旧8768端口或CDN。
