---
name: edgeai-int8-equivalence
description: Verify integer CNN numerical equivalence across independent NumPy, portable C and FPGA RTL paths when quantized model parameters and frozen traces are available.
---

# Integer CNN equivalence

Work from the caller's selected repository/model. Confirm the arithmetic contract before comparing results: signed input/weight widths, accumulator width, bias units, shift/rounding/tie rule, saturation, ReLU/pool order, GAP averaging and memory layout. Classification accuracy and numerical equivalence are different outcomes.

Freeze input/model/weight SHA256 before running. Compare independent boundary arrays and final logits, preferably byte-for-byte; a successful process exit or matching class alone is insufficient. If an optimized integer evaluator uses float operations, verify its exactness bound and compare against a separate integer implementation. Keep negative/halfway/saturation cases and intentionally misclassified inputs.

In the companion edge-AI repository, `reference/int8_modulation_cnn.py` is the independent NumPy oracle; `scripts/run_portable_cpu_baseline.py` verifies all boundary bytes through scalar/blocked C. Full RTL fixtures also require bias/shift metadata, not just activation arrays. Use fresh output paths and preserve rejected runs. Read the target model contract if the graph differs rather than assuming the fixed 2-32-64-64-4 graph is universal.

Real validated example: the original five IQ fixtures and four held-out digit fixtures pass C/NumPy checks; P33 has 144 independent integer cases and four full RTL fixtures. Missing `conv1_bias`/shift metadata caused an actual generator failure preserved in `experiments/p33_application_bringup_failed`.

Replay example, from the companion repository: `.venv-model/Scripts/python.exe scripts/run_portable_cpu_baseline.py --output build/new_cpu_check`. Run `scripts/run_digits_application.ps1` for its frozen second-application RTL fixtures. Report source identity, boundaries/counts checked, failures and scope; do not inherit FPGA timing for a newly trained model without a matching physical run.
