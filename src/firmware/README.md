# Firmware

occupancy/为实际选中服务，compile_occupancy.py要求重编译二进制SHA一致。classification/保留实际控制程序及生成头文件，编译宏见original_commands.jsonl。im2col/保留公开Caffe展开算法的项目移植及比较参数；不同固件配置/内存布局不混用。模型和程序ROM均已包含，重建PL不需要先运行训练。
