---
name: edgeai-resource-triage
description: Evaluate FPGA inference resource capacity and internal timing separately using implementation reports and simulator cycles when selecting array sizes or clocks.
---

# FPGA resource and clock triage

Use the caller's exact device, speed grade, tool version, clock and system boundary. Separate HLS estimates, synthesis, routed resources, OOC internal timing and board measurements. Normalize BRAM18K versus BRAM36 units and include CPU shells/read-memory replicas.

A design fits only if every reported resource fits. A clock candidate passes internal timing after complete routing and nonnegative setup AND hold; inspect route/DRC too. Tool exit status alone may not reflect the timing gate. OOC excludes board pins, clock/reset adapters and external budgets.

Convert cycles to a calculated estimate only using a clock constraint that passed for that source/device. Do not convert failed timing into achieved latency or infer verified maximum frequency from WNS. A lower clock is a separate trial with its own identity and reports. Match actual frequency in speedup denominators.

Real companion-repository example: M29 widened arrays fit 7010 but fail 100MHz; the fresh 4x4 7010 probe also fails setup -0.116ns. P31 reruns all three at 80MHz and passes. The 8x8 consumes 68/80 DSP versus 4x8 36/80. HLS S3c remains too large in LUT/FF for 7010 after FIFO BRAM reduction.

Replay from that repository: `scripts/run_m22a_postroute.ps1 -Variant M28c -TileRows 4 -TileCols 8 -Part xc7z010clg400-1 -ClockPeriodNs 12.5 -FirmwareHex <frozen.hex> -OutputRoot <new-build-path>`. This runs internal implementation, not board programming. Conclude capacity, clock acceptance and remaining board evidence independently.
