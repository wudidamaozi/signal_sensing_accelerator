"""Independent NumPy reference for the deployed INT8 modulation CNN."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np


def round_shift(values: np.ndarray, shift: int) -> np.ndarray:
    """Apply a power-of-two scale with half-away-from-zero rounding."""

    values = np.asarray(values, dtype=np.int64)
    if shift == 0:
        return values
    if shift < 0:
        return values << (-shift)
    half = np.int64(1 << (shift - 1))
    magnitude = np.abs(values)
    rounded = (magnitude + half) >> shift
    return np.where(values < 0, -rounded, rounded)


def conv1d_accumulate(
    inputs: np.ndarray,
    weights: np.ndarray,
    biases: np.ndarray,
    padding: int,
) -> np.ndarray:
    """Return exact signed INT64 convolution accumulators for one sample."""

    inputs = np.asarray(inputs, dtype=np.int64)
    weights = np.asarray(weights, dtype=np.int64)
    biases = np.asarray(biases, dtype=np.int64)
    if inputs.ndim != 2 or weights.ndim != 3:
        raise ValueError("expected inputs [C,L] and weights [O,C,K]")
    if inputs.shape[0] != weights.shape[1]:
        raise ValueError("input and weight channel counts differ")
    padded = np.pad(inputs, ((0, 0), (padding, padding)))
    windows = np.lib.stride_tricks.sliding_window_view(
        padded, weights.shape[2], axis=1
    )
    matrix = windows.transpose(1, 0, 2).reshape(windows.shape[1], -1)
    flattened_weights = weights.reshape(weights.shape[0], -1)
    return matrix @ flattened_weights.T + biases.reshape(1, -1)


def requantize_relu(accumulators: np.ndarray, shifts: np.ndarray) -> np.ndarray:
    shifts = np.asarray(shifts, dtype=np.int32)
    if accumulators.ndim != 2 or shifts.shape != (accumulators.shape[1],):
        raise ValueError("expected accumulators [L,O] and one shift per output channel")
    shifted = np.empty_like(accumulators, dtype=np.int64)
    for shift in np.unique(shifts):
        mask = shifts == shift
        shifted[:, mask] = round_shift(accumulators[:, mask], int(shift))
    return np.clip(shifted, 0, 127).astype(np.int8)


def max_pool2(inputs: np.ndarray) -> np.ndarray:
    if inputs.shape[1] % 2:
        raise ValueError("pool input length must be even")
    return inputs.reshape(inputs.shape[0], -1, 2).max(axis=2)


def rounded_average(inputs: np.ndarray) -> np.ndarray:
    sums = np.asarray(inputs, dtype=np.int64).sum(axis=1)
    length = inputs.shape[1]
    magnitude = np.abs(sums)
    rounded = (magnitude + length // 2) // length
    return np.where(sums < 0, -rounded, rounded).astype(np.int8)


@dataclass(frozen=True)
class QuantizedParameters:
    input_exponent: int
    conv1_output_exponent: int
    conv2_output_exponent: int
    conv3_output_exponent: int
    conv1_weight_exponent: np.ndarray
    conv2_weight_exponent: np.ndarray
    conv3_weight_exponent: np.ndarray
    classifier_weight_exponent: int
    conv1_weight: np.ndarray
    conv1_bias: np.ndarray
    conv2_weight: np.ndarray
    conv2_bias: np.ndarray
    conv3_weight: np.ndarray
    conv3_bias: np.ndarray
    classifier_weight: np.ndarray
    classifier_bias: np.ndarray

    @classmethod
    def load(cls, path: Path) -> "QuantizedParameters":
        with np.load(path, allow_pickle=False) as archive:
            scalar = lambda name: int(archive[name].item())
            return cls(
                input_exponent=scalar("input_exponent"),
                conv1_output_exponent=scalar("conv1_output_exponent"),
                conv2_output_exponent=scalar("conv2_output_exponent"),
                conv3_output_exponent=scalar("conv3_output_exponent"),
                conv1_weight_exponent=archive["conv1_weight_exponent"].copy(),
                conv2_weight_exponent=archive["conv2_weight_exponent"].copy(),
                conv3_weight_exponent=archive["conv3_weight_exponent"].copy(),
                classifier_weight_exponent=scalar("classifier_weight_exponent"),
                conv1_weight=archive["conv1_weight"].copy(),
                conv1_bias=archive["conv1_bias"].copy(),
                conv2_weight=archive["conv2_weight"].copy(),
                conv2_bias=archive["conv2_bias"].copy(),
                conv3_weight=archive["conv3_weight"].copy(),
                conv3_bias=archive["conv3_bias"].copy(),
                classifier_weight=archive["classifier_weight"].copy(),
                classifier_bias=archive["classifier_bias"].copy(),
            )


def quantize_input(samples: np.ndarray, exponent: int) -> np.ndarray:
    scaled = np.asarray(samples, dtype=np.float64) / (2.0**exponent)
    rounded = np.where(scaled < 0, np.ceil(scaled - 0.5), np.floor(scaled + 0.5))
    return np.clip(rounded, -128, 127).astype(np.int8)


def infer_trace(
    sample: np.ndarray, parameters: QuantizedParameters
) -> dict[str, np.ndarray]:
    """Return every frozen integer boundary used for layer-level verification."""

    q = quantize_input(sample, parameters.input_exponent)

    mac1 = conv1d_accumulate(
        q,
        parameters.conv1_weight,
        np.zeros(parameters.conv1_bias.shape, dtype=np.int32),
        3,
    )
    acc1 = mac1 + parameters.conv1_bias.astype(np.int64).reshape(1, -1)
    shift1 = (
        parameters.conv1_output_exponent
        - parameters.input_exponent
        - parameters.conv1_weight_exponent
    )
    q1 = requantize_relu(acc1, shift1).T
    pool1 = max_pool2(q1)

    mac2 = conv1d_accumulate(
        pool1,
        parameters.conv2_weight,
        np.zeros(parameters.conv2_bias.shape, dtype=np.int32),
        2,
    )
    acc2 = mac2 + parameters.conv2_bias.astype(np.int64).reshape(1, -1)
    shift2 = (
        parameters.conv2_output_exponent
        - parameters.conv1_output_exponent
        - parameters.conv2_weight_exponent
    )
    q2 = requantize_relu(acc2, shift2).T
    pool2 = max_pool2(q2)

    mac3 = conv1d_accumulate(
        pool2,
        parameters.conv3_weight,
        np.zeros(parameters.conv3_bias.shape, dtype=np.int32),
        1,
    )
    acc3 = mac3 + parameters.conv3_bias.astype(np.int64).reshape(1, -1)
    shift3 = (
        parameters.conv3_output_exponent
        - parameters.conv2_output_exponent
        - parameters.conv3_weight_exponent
    )
    q3 = requantize_relu(acc3, shift3).T
    pooled = rounded_average(q3)

    logits = (
        parameters.classifier_weight.astype(np.int64)
        @ pooled.astype(np.int64)
        + parameters.classifier_bias.astype(np.int64)
    )
    return {
        "input_q": q,
        "conv1_mac": mac1,
        "conv1_acc": acc1,
        "conv1_q": q1,
        "pool1_q": pool1,
        "conv2_mac": mac2,
        "conv2_acc": acc2,
        "conv2_q": q2,
        "pool2_q": pool2,
        "conv3_mac": mac3,
        "conv3_acc": acc3,
        "conv3_q": q3,
        "global_average_q": pooled,
        "logits": logits,
    }


def infer_one(sample: np.ndarray, parameters: QuantizedParameters) -> np.ndarray:
    return infer_trace(sample, parameters)["logits"]
