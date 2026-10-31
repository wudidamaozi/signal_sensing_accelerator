---
name: edgeai-experiment-evidence
description: Collect reproducible FPGA CNN benchmark evidence and source-backed figures with controlled comparison boundaries and preserved rejected trials.
---

# Experiment evidence and figures

Use the caller's question and agreed workload. A valid speedup pairs model/input/arithmetic/compiler/CPU/tool/device/clock/timing boundary; label differences and limit the ratio when a condition differs. Separate simulator cycles, software timing, physical references and measured board results.

Use a fresh trial directory with summary, source/fixture/firmware identity, exact command, correctness, full/stage cycles, size/resources, decision and compact raw logs. Reconcile mutually exclusive stages; do not add overlapping counters. Preserve failed/slower variants and baseline switches. Reused physical reports require matching compute/ROM/shell/firmware identity and explicit disclosure.

Keep meaningful strong baselines. Mark failing timing points on resource plots; sparse configurations do not justify interpolation. Record units/source paths, export tables and inspect rendered labels. Warm intervals containing verification are not peak streaming throughput.

Real companion example: P30 matches latest M28c, im2col and HLS S3c under the same CPU/fixture boundary, retains faster HLS S2d, and audits reused physical identity. P34 checks 200 unique class/SNR-balanced inputs and 20 warm calls per array. P35 exports six PNG/SVG figures; overlapping labels were repaired after visual inspection.

Replay from that repository: `.venv-model/Scripts/python.exe scripts/plot_preboard_results.py` uses archived sources; `scripts/run_m28_candidate.ps1 ... -FullData` generates fresh measurements. For another repository, adapt to its schema instead of copying hardcoded counts. Deliver supported findings and limitations without fabricated metrics or inferred personal ownership.
