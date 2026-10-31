#include "accelerator_regs.h"
#ifndef NETWORK_DATA_HEADER
#define NETWORK_DATA_HEADER "generated/full_network_data.h"
#endif
#include NETWORK_DATA_HEADER

static uint32_t trace_checks=1u;
#define HOST_RESULT (*(volatile uint32_t *)0x20000000u)
#ifndef MAX_K
#define MAX_K 64u
#endif
#if MAX_K < 64 || MAX_K > 255
#error "K depth must fit the 8-bit descriptor and 4 KiB operand window"
#endif
#define Q_PING_BASE 0u
#define Q_PONG_BASE 4096u
#ifndef ENABLE_LOCAL_Q_REUSE
#define ENABLE_LOCAL_Q_REUSE 1
#endif
#ifndef ENABLE_INCREMENTAL_K
#define ENABLE_INCREMENTAL_K 1
#endif
#ifndef ENABLE_SPLIT_PROFILE
#define ENABLE_SPLIT_PROFILE 0
#endif
#ifndef ENABLE_PACKED_WINDOW
#define ENABLE_PACKED_WINDOW 1
#endif
#ifndef ENABLE_HW_WINDOW_LOADER
#define ENABLE_HW_WINDOW_LOADER 0
#endif
#ifndef ENABLE_HW_WEIGHT_LOADER
#define ENABLE_HW_WEIGHT_LOADER 0
#endif
#ifndef ENABLE_FUSED_GAP
#define ENABLE_FUSED_GAP 0
#endif
#ifndef FUSED_GAP_SKIP_Q_WRITE
#define FUSED_GAP_SKIP_Q_WRITE 0
#endif
#ifndef ENABLE_EXPLICIT_IM2COL
#define ENABLE_EXPLICIT_IM2COL 0
#endif
#ifndef ENABLE_BENCHMARK_OUTPUT
#define ENABLE_BENCHMARK_OUTPUT 0
#endif
#ifndef ENABLE_LOADER_OVERLAP
#define ENABLE_LOADER_OVERLAP 0
#endif
#ifndef ENABLE_INPUT_TILE_REUSE
#define ENABLE_INPUT_TILE_REUSE 0
#endif
#ifndef ENABLE_DIRECT_WEIGHTS
#define ENABLE_DIRECT_WEIGHTS 0
#endif
#ifndef ENABLE_CHAINED_POST
#define ENABLE_CHAINED_POST 0
#endif
#ifndef ENABLE_DESCRIPTOR_REUSE
#define ENABLE_DESCRIPTOR_REUSE 0
#endif
#ifndef ENABLE_AUTONOMOUS_LAYER
#define ENABLE_AUTONOMOUS_LAYER 0
#endif
#ifndef ENABLE_HW_CLASSIFIER_INPUT
#define ENABLE_HW_CLASSIFIER_INPUT 0
#endif
#if ENABLE_HW_CLASSIFIER_INPUT && !ENABLE_HW_WINDOW_LOADER
#error "Classifier gathering requires the hardware input loader"
#endif
#if ENABLE_AUTONOMOUS_LAYER && (!ENABLE_HW_WINDOW_LOADER || !ENABLE_DIRECT_WEIGHTS || !ENABLE_CHAINED_POST)
#error "Autonomous layers require implicit input, resident weights and chaining"
#endif
#if ENABLE_DIRECT_WEIGHTS && !ENABLE_HW_WEIGHT_LOADER
#error "Direct weights use the hardware weight descriptor registers"
#endif
#if ENABLE_LOADER_OVERLAP && !ENABLE_HW_WEIGHT_LOADER
#error "Loader overlap requires the hardware weight loader"
#endif
#if ENABLE_INPUT_TILE_REUSE && !ENABLE_HW_WINDOW_LOADER && !ENABLE_EXPLICIT_IM2COL
#error "Input reuse requires an implicit loader or explicit im2col"
#endif
#if ENABLE_EXPLICIT_IM2COL && ENABLE_HW_WINDOW_LOADER
#error "Explicit im2col and implicit hardware window loading are alternative paths"
#endif

#if ENABLE_EXPLICIT_IM2COL
/* Public Caffe lowering, materialized once per spatial tile and reused across N. */
extern void edge_caffe_im2col_tile(const signed char *input, int channels,
    int width, int kernel, signed char *columns);
static signed char im2col_patch[64u * 22u];
static union {
    signed char bytes[192u * 16u];
    uint32_t words[192u * 4u];
} im2col_columns;
#endif
#if ENABLE_BENCHMARK_OUTPUT
static volatile int32_t benchmark_logits[4];
#endif

static uint32_t pack_and_load_cycles;
static uint32_t gemm_wait_cycles;
static uint32_t postprocess_cycles;
static uint32_t hardware_gemm_cycles;
static uint32_t hardware_compute_cycles;
static uint32_t hardware_post_cycles;
#if ENABLE_SPLIT_PROFILE
static uint32_t setup_cycles;
static uint32_t input_pack_cycles;
static uint32_t weight_load_cycles;
#endif

static uint32_t read_cycles(void)
{
    uint32_t value;
    __asm__ volatile ("rdcycle %0" : "=r"(value));
    return value;
}

static void emit_metric(uint32_t metric, uint32_t value)
{
    HOST_RESULT = 0xa5000000u | metric;
    HOST_RESULT = value;
}

static __attribute__((noreturn)) void report_and_halt(uint32_t result)
{
    HOST_RESULT = result;
    __asm__ volatile ("ebreak");
    for (;;) {
    }
}

#if ENABLE_HW_WEIGHT_LOADER && !ENABLE_DIRECT_WEIGHTS
static void wait_weight_loader(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_WLOAD_STATUS;
        if (timeout-- == 0u)
            report_and_halt(diagnostic);
    } while ((status & ACCEL_WLOAD_STATUS_DONE) == 0u);
    if ((status & (ACCEL_WLOAD_STATUS_BUSY | ACCEL_WLOAD_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}
#endif

#if ENABLE_FUSED_GAP
static void wait_gap(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_GAP_STATUS;
        if (timeout-- == 0u)
            report_and_halt(diagnostic);
    } while ((status & ACCEL_GAP_STATUS_DONE) == 0u);
    if ((status & (ACCEL_GAP_STATUS_BUSY | ACCEL_GAP_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}
#endif

static int32_t q_read_i8(uint32_t byte_index)
{
    uint32_t value = (ACCEL_Q[byte_index >> 2] >> ((byte_index & 3u) * 8u)) & 0xffu;
    return value < 128u ? (int32_t)value : (int32_t)value - 256;
}

#if ENABLE_EXPLICIT_IM2COL
static void prepare_im2col_tile(uint32_t channels, uint32_t input_length,
    uint32_t input_base, uint32_t output_start, uint32_t tile_m,
    uint32_t kernel, uint32_t padding)
{
    uint32_t patch_width = tile_m + kernel - 1u;
    uint32_t channel;
    for (channel = 0; channel < channels; ++channel) {
        uint32_t position;
        uint32_t cached_index = 0xffffffffu;
        uint32_t cached_word = 0u;
        for (position = 0; position < patch_width; ++position) {
            int32_t source_position = (int32_t)(output_start + position)
                - (int32_t)padding;
            uint32_t value = 0u;
            if (source_position >= 0 && (uint32_t)source_position < input_length) {
                uint32_t address = input_base + channel * input_length
                    + (uint32_t)source_position;
                uint32_t word_index = address >> 2;
                if (word_index != cached_index) {
                    cached_word = ACCEL_Q[word_index];
                    cached_index = word_index;
                }
                value = (cached_word >> ((address & 3u) * 8u)) & 0xffu;
            }
            im2col_patch[channel * patch_width + position] = (signed char)value;
        }
    }
    edge_caffe_im2col_tile(im2col_patch, (int)channels, (int)patch_width,
        (int)kernel, im2col_columns.bytes);
}
#endif

static uint32_t fnv_q(uint32_t byte_base, uint32_t byte_count)
{
    uint32_t hash = 0x811c9dc5u;
    uint32_t index;
    for (index = 0; index < byte_count; ++index) {
        hash ^= (uint32_t)(q_read_i8(byte_base + index) & 0xff);
        hash *= 0x01000193u;
    }
    return hash;
}

static void load_parameters_raw(
    const int32_t *bias, const uint32_t *shift, uint32_t channels)
{
    uint32_t channel;
    for (channel = 0; channel < channels; ++channel) {
        ACCEL_BIAS[channel] = bias[channel];
        ACCEL_SHIFT[channel] = shift[channel];
    }
}

static void load_parameters(const int32_t *bias,const uint32_t *shift,uint32_t channels) {
 (void)shift;(void)channels;
 (*(volatile uint32_t *)(ACCEL_BASE+0x00c4u))=(bias==conv1_bias)?0u:(bias==conv2_bias)?1u:2u;
}
static void wait_gemm(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_STATUS;
        if (timeout-- == 0u)
            report_and_halt(diagnostic);
    } while ((status & ACCEL_STATUS_DONE) == 0u);
    if ((status & (ACCEL_STATUS_BUSY | ACCEL_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}

static void wait_post(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_POST_STATUS;
        if (timeout-- == 0u)
            report_and_halt(diagnostic);
    } while ((status & ACCEL_POST_STATUS_DONE) == 0u);
    if ((status & (ACCEL_POST_STATUS_BUSY | ACCEL_POST_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}

#if ENABLE_CHAINED_POST
static void wait_chain(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_CHAIN_STATUS;
        if (timeout-- == 0u) report_and_halt(diagnostic);
    } while ((status & ACCEL_STATUS_DONE) == 0u);
    if ((status & (ACCEL_STATUS_BUSY | ACCEL_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}
#endif

#if ENABLE_HW_WINDOW_LOADER
static void wait_loader(uint32_t diagnostic)
{
    uint32_t timeout = 100000u;
    uint32_t status;
    do {
        status = ACCEL_LOAD_STATUS;
        if (timeout-- == 0u)
            report_and_halt(diagnostic);
    } while ((status & ACCEL_LOAD_STATUS_DONE) == 0u);
    if ((status & (ACCEL_LOAD_STATUS_BUSY | ACCEL_LOAD_STATUS_ERROR)) != 0u)
        report_and_halt(diagnostic + 1u);
}
#endif

static void run_conv_layer(
    uint32_t m_total,
    uint32_t n_total,
    uint32_t k_total,
    uint32_t kernel,
    uint32_t padding,
    uint32_t input_length,
    uint32_t output_length,
    uint32_t input_q_base,
    uint32_t output_q_base,
    uint32_t weight_byte_base,
    uint32_t pool,
    uint32_t diagnostic)
{
    uint32_t m_offset;
    uint32_t n_offset;
    uint32_t k_offset;
#if ENABLE_AUTONOMOUS_LAYER
    if ((m_total & 15u) == 0u && (n_total == 16u || n_total == 32u || n_total == 64u)
        && k_total <= MAX_K) {
        uint32_t cycle_start = read_cycles();
        uint32_t timeout = 100000u;
        uint32_t status;
        ACCEL_CONTROL = ACCEL_CONTROL_CLEAR_STATUS;
        ACCEL_M = 16u; ACCEL_N = 16u; ACCEL_K = k_total;
        ACCEL_MODE = ACCEL_MODE_OVERWRITE;
        ACCEL_LOAD_OUTPUT_BASE = 0u;
        ACCEL_LOAD_INPUT_LENGTH = input_length;
        ACCEL_LOAD_KERNEL = kernel; ACCEL_LOAD_PADDING = padding;
        ACCEL_LOAD_CHANNEL_BASE = input_q_base; ACCEL_LOAD_START_TAP = 0u;
        ACCEL_WLOAD_START_WORD = weight_byte_base >> 2;
        ACCEL_WLOAD_STRIDE = n_total >> 2;
        ACCEL_POST_CONTROL = ACCEL_POST_CONTROL_CLEAR_STATUS;
        ACCEL_POST_POSITIONS = 16u; ACCEL_POST_CHANNELS = 16u;
        ACCEL_POST_OPTIONS = pool ? ACCEL_POST_OPTION_POOL : 0u;
        ACCEL_POST_Q_STRIDE = output_length;
        ACCEL_POST_PARAM_BASE = 0u; ACCEL_POST_Q_BASE = output_q_base;
        ACCEL_LAYER_M = m_total; ACCEL_LAYER_N = n_total;
        pack_and_load_cycles += read_cycles() - cycle_start;
        cycle_start = read_cycles();
        ACCEL_LAYER_CONTROL = ACCEL_CHAIN_START | ACCEL_CHAIN_CLEAR;
        do {
            status = ACCEL_LAYER_STATUS;
            if (timeout-- == 0u) report_and_halt(diagnostic + 10u);
        } while ((status & ACCEL_STATUS_DONE) == 0u);
        if ((status & (ACCEL_STATUS_BUSY | ACCEL_STATUS_ERROR)) != 0u)
            report_and_halt(diagnostic + 11u);
        // Includes input loading, GEMM and POST inside one layer command.
        gemm_wait_cycles += read_cycles() - cycle_start;
        hardware_gemm_cycles += ACCEL_LAYER_GEMM;
        hardware_compute_cycles += ACCEL_LAYER_COMPUTE;
        hardware_post_cycles += ACCEL_LAYER_POST;
        return;
    }
#endif
#if ENABLE_DESCRIPTOR_REUSE
    // Use the fast path only for whole 16x16 tiles and a complete K reduction.
    // Tails or split-K retain the general per-command descriptor sequence.
    uint32_t whole_tiles = (m_total & 15u) == 0u && (n_total & 15u) == 0u
        && k_total <= MAX_K;
    if (whole_tiles) {
        uint32_t setup_start = read_cycles();
        ACCEL_CONTROL = ACCEL_CONTROL_CLEAR_STATUS;
        ACCEL_M = 16u;
        ACCEL_N = 16u;
        ACCEL_K = k_total;
        ACCEL_MODE = ACCEL_MODE_OVERWRITE;
#if ENABLE_HW_WINDOW_LOADER
        ACCEL_LOAD_INPUT_LENGTH = input_length;
        ACCEL_LOAD_KERNEL = kernel;
        ACCEL_LOAD_PADDING = padding;
        ACCEL_LOAD_CHANNEL_BASE = input_q_base;
        ACCEL_LOAD_START_TAP = 0u;
#endif
#if ENABLE_HW_WEIGHT_LOADER
        ACCEL_WLOAD_STRIDE = n_total >> 2;
        ACCEL_WLOAD_CONTROL = ACCEL_WLOAD_CONTROL_CLEAR_STATUS;
#endif
        ACCEL_POST_CONTROL = ACCEL_POST_CONTROL_CLEAR_STATUS;
        ACCEL_POST_POSITIONS = 16u;
        ACCEL_POST_CHANNELS = 16u;
        ACCEL_POST_OPTIONS = pool ? ACCEL_POST_OPTION_POOL : 0u;
        ACCEL_POST_Q_STRIDE = output_length;
        pack_and_load_cycles += read_cycles() - setup_start;
    }
#endif
    for (m_offset = 0; m_offset < m_total; m_offset += 16u) {
        uint32_t tile_m = m_total - m_offset < 16u ? m_total - m_offset : 16u;
#if ENABLE_EXPLICIT_IM2COL
        uint32_t preparation_start = read_cycles();
        uint32_t channels = 0u;
        uint32_t remainder = k_total;
        /* PicoRV32 has multiply but no hardware divide in this configuration. */
        while (remainder >= kernel) {
            remainder -= kernel;
            ++channels;
        }
        prepare_im2col_tile(channels, input_length, input_q_base,
            m_offset, tile_m, kernel, padding);
        pack_and_load_cycles += read_cycles() - preparation_start;
#endif
        for (n_offset = 0; n_offset < n_total; n_offset += 16u) {
            uint32_t tile_n = n_total - n_offset < 16u ? n_total - n_offset : 16u;
            for (k_offset = 0; k_offset < k_total; k_offset += MAX_K) {
                uint32_t tile_k = k_total - k_offset < MAX_K ? k_total - k_offset : MAX_K;
#if ENABLE_HW_WINDOW_LOADER || ENABLE_EXPLICIT_IM2COL
#if ENABLE_INPUT_TILE_REUSE
                /* Reuse only when the entire reduction fits: no stale partial K. */
                uint32_t load_input = k_total > MAX_K || n_offset == 0u;
#else
                uint32_t load_input = 1u;
#endif
#endif
#if !ENABLE_HW_WINDOW_LOADER
                uint32_t row_tile;
#endif
#if !ENABLE_HW_WEIGHT_LOADER
                uint32_t column_tile;
#endif
#if !ENABLE_HW_WEIGHT_LOADER || !ENABLE_HW_WINDOW_LOADER
                uint32_t local_k;
#endif
                uint32_t cycle_start = read_cycles();
#if ENABLE_SPLIT_PROFILE
                uint32_t split_start = cycle_start;
#endif

#if ENABLE_DESCRIPTOR_REUSE
                if (!whole_tiles) {
#endif
                ACCEL_CONTROL = ACCEL_CONTROL_CLEAR_STATUS;
                ACCEL_M = tile_m;
                ACCEL_N = tile_n;
                ACCEL_K = tile_k;
                ACCEL_MODE = k_offset == 0u ? ACCEL_MODE_OVERWRITE : ACCEL_MODE_ACCUMULATE;
#if ENABLE_DESCRIPTOR_REUSE
                }
#endif
#if ENABLE_SPLIT_PROFILE
                setup_cycles += read_cycles() - split_start;
                split_start = read_cycles();
#endif

#if ENABLE_EXPLICIT_IM2COL
                if (load_input) {
                for (row_tile = 0; row_tile < (tile_m + 3u) / 4u; ++row_tile) {
                    for (local_k = 0; local_k < tile_k; ++local_k) {
                        uint32_t word = 0u;
                        if ((tile_m & 3u) == 0u) {
                            word = im2col_columns.words[
                                (k_offset + local_k) * (tile_m >> 2) + row_tile];
                        } else {
                            uint32_t lane;
                            for (lane = 0; lane < 4u; ++lane) {
                                uint32_t row = row_tile * 4u + lane;
                                if (row < tile_m)
                                    word |= ((uint32_t)im2col_columns.bytes[
                                        (k_offset + local_k) * tile_m + row] & 0xffu)
                                        << (lane * 8u);
                            }
                        }
                        ACCEL_A[row_tile * MAX_K + local_k] = word;
                    }
                }
                }
#elif ENABLE_HW_WINDOW_LOADER
                if (load_input) {
                    uint32_t start_channel = 0u;
                    uint32_t start_tap = k_offset;
                    while (start_tap >= kernel) {
                        start_tap -= kernel;
                        ++start_channel;
                    }
                    ACCEL_LOAD_OUTPUT_BASE = m_offset;
#if ENABLE_DESCRIPTOR_REUSE
                    if (!whole_tiles) {
#endif
                    ACCEL_LOAD_INPUT_LENGTH = input_length;
                    ACCEL_LOAD_KERNEL = kernel;
                    ACCEL_LOAD_PADDING = padding;
                    ACCEL_LOAD_CHANNEL_BASE = input_q_base
                        + start_channel * input_length;
                    ACCEL_LOAD_START_TAP = start_tap;
                    ACCEL_LOAD_CONTROL = ACCEL_LOAD_CONTROL_CLEAR_STATUS;
#if ENABLE_DESCRIPTOR_REUSE
                    }
#endif
#if !ENABLE_LOADER_OVERLAP
                    ACCEL_LOAD_CONTROL = ACCEL_LOAD_CONTROL_START;
                    wait_loader(diagnostic + 4u);
#endif
                }
#else
                for (row_tile = 0; row_tile < (tile_m + 3u) / 4u; ++row_tile) {
#if ENABLE_INCREMENTAL_K
                    uint32_t input_channel = 0u;
                    uint32_t tap = k_offset;
                    while (tap >= kernel) {
                        tap -= kernel;
                        ++input_channel;
                    }
#endif
#if ENABLE_LOCAL_Q_REUSE
                    uint32_t q_tag_0 = 0xffffffffu;
                    uint32_t q_tag_1 = 0xffffffffu;
                    uint32_t q_word_0 = 0u;
                    uint32_t q_word_1 = 0u;
                    uint32_t q_replace = 0u;
#endif
                    for (local_k = 0; local_k < tile_k; ++local_k) {
                        uint32_t word = 0u;
#if !ENABLE_INCREMENTAL_K
                        uint32_t flat_k = k_offset + local_k;
                        uint32_t input_channel;
                        uint32_t tap;
                        input_channel = 0u;
                        tap = flat_k;
                        while (tap >= kernel) {
                            tap -= kernel;
                            ++input_channel;
                        }
#endif
#if ENABLE_PACKED_WINDOW
                        uint32_t first_position = m_offset + row_tile * 4u;
                        int32_t first_input_position = (int32_t)first_position
                            + (int32_t)tap - (int32_t)padding;
                        if (first_position + 3u < m_total
                            && first_input_position >= 0
                            && (uint32_t)first_input_position + 3u < input_length) {
                            uint32_t byte_address = input_q_base
                                + input_channel * input_length
                                + (uint32_t)first_input_position;
                            uint32_t word_index = byte_address >> 2;
                            uint32_t shift = (byte_address & 3u) * 8u;
                            uint32_t first_word = ACCEL_Q[word_index];
                            if (shift == 0u) {
                                word = first_word;
                            } else {
                                uint32_t second_word = ACCEL_Q[word_index + 1u];
                                word = (first_word >> shift)
                                    | (second_word << (32u - shift));
                            }
                        } else
#endif
                        {
                            uint32_t lane;
                            for (lane = 0; lane < 4u; ++lane) {
                                uint32_t output_position = m_offset + row_tile * 4u + lane;
                                int32_t input_position = (int32_t)output_position
                                    + (int32_t)tap - (int32_t)padding;
#if ENABLE_LOCAL_Q_REUSE
                                uint32_t value = 0u;
                                if (output_position < m_total && input_position >= 0
                                    && (uint32_t)input_position < input_length) {
                                    uint32_t byte_address =
                                        input_q_base + input_channel * input_length
                                        + (uint32_t)input_position;
                                    uint32_t word_index = byte_address >> 2;
                                    uint32_t source_word;
                                    if (word_index == q_tag_0) {
                                        source_word = q_word_0;
                                    } else if (word_index == q_tag_1) {
                                        source_word = q_word_1;
                                    } else {
                                        source_word = ACCEL_Q[word_index];
                                        if (q_replace == 0u) {
                                            q_tag_0 = word_index;
                                            q_word_0 = source_word;
                                        } else {
                                            q_tag_1 = word_index;
                                            q_word_1 = source_word;
                                        }
                                        q_replace ^= 1u;
                                    }
                                    value = (source_word >> ((byte_address & 3u) * 8u)) & 0xffu;
                                }
                                word |= value << (lane * 8u);
#else
                                int32_t value = 0;
                                if (output_position < m_total && input_position >= 0
                                    && (uint32_t)input_position < input_length) {
                                    value = q_read_i8(
                                        input_q_base + input_channel * input_length
                                        + (uint32_t)input_position
                                    );
                                }
                                word |= ((uint32_t)value & 0xffu) << (lane * 8u);
#endif
                            }
                        }
                        ACCEL_A[row_tile * MAX_K + local_k] = word;
#if ENABLE_INCREMENTAL_K
                        ++tap;
                        if (tap == kernel) {
                            tap = 0u;
                            ++input_channel;
                        }
#endif
                    }
                }
#endif
#if ENABLE_SPLIT_PROFILE
                input_pack_cycles += read_cycles() - split_start;
                split_start = read_cycles();
#endif

#if ENABLE_HW_WEIGHT_LOADER
                ACCEL_WLOAD_START_WORD = (weight_byte_base
                    + k_offset * n_total + n_offset) >> 2;
#if ENABLE_DESCRIPTOR_REUSE
                if (!whole_tiles) {
#endif
                ACCEL_WLOAD_STRIDE = n_total >> 2;
                ACCEL_WLOAD_CONTROL = ACCEL_WLOAD_CONTROL_CLEAR_STATUS;
#if ENABLE_DESCRIPTOR_REUSE
                }
#endif
#if ENABLE_LOADER_OVERLAP && ENABLE_HW_WINDOW_LOADER
                /* Configure both engines while idle; neither rewrites live cfg. */
                if (load_input) ACCEL_LOAD_CONTROL = ACCEL_LOAD_CONTROL_START;
#endif
#if !ENABLE_DIRECT_WEIGHTS
                ACCEL_WLOAD_CONTROL = ACCEL_WLOAD_CONTROL_START;
                wait_weight_loader(diagnostic + 6u);
#endif
#if ENABLE_LOADER_OVERLAP && ENABLE_HW_WINDOW_LOADER
                if (load_input) wait_loader(diagnostic + 4u);
#endif
#else
                for (column_tile = 0; column_tile < (tile_n + 3u) / 4u; ++column_tile) {
                    for (local_k = 0; local_k < tile_k; ++local_k) {
                        uint32_t byte_address = weight_byte_base
                            + (k_offset + local_k) * n_total
                            + n_offset + column_tile * 4u;
                        ACCEL_B[column_tile * MAX_K + local_k] =
                            ACCEL_WEIGHT[byte_address >> 2];
                    }
                }
#endif

#if ENABLE_SPLIT_PROFILE
                weight_load_cycles += read_cycles() - split_start;
#endif
#if ENABLE_CHAINED_POST
                if (k_offset + tile_k == k_total) {
#if ENABLE_DESCRIPTOR_REUSE
                    if (!whole_tiles) {
#endif
                    ACCEL_POST_CONTROL = ACCEL_POST_CONTROL_CLEAR_STATUS;
                    ACCEL_POST_POSITIONS = tile_m;
                    ACCEL_POST_CHANNELS = tile_n;
                    ACCEL_POST_OPTIONS = pool ? ACCEL_POST_OPTION_POOL : 0u;
#if ENABLE_DESCRIPTOR_REUSE
                    ACCEL_POST_Q_STRIDE = output_length;
                    }
#endif
                    ACCEL_POST_PARAM_BASE = n_offset;
                    ACCEL_POST_Q_BASE = output_q_base + n_offset * output_length
                        + (pool ? m_offset / 2u : m_offset);
#if !ENABLE_DESCRIPTOR_REUSE
                    ACCEL_POST_Q_STRIDE = output_length;
#endif
                }
#endif
                pack_and_load_cycles += read_cycles() - cycle_start;

                cycle_start = read_cycles();
#if ENABLE_CHAINED_POST
                if (k_offset + tile_k == k_total) {
                    ACCEL_CHAIN_CONTROL = ACCEL_CHAIN_START | ACCEL_CHAIN_CLEAR;
                    wait_chain(diagnostic + 8u);
                    // This nested wait includes POST; do not add it to totals twice.
                    gemm_wait_cycles += read_cycles() - cycle_start;
                    hardware_gemm_cycles += ACCEL_TOTAL;
                    hardware_compute_cycles += ACCEL_COMPUTE;
                    hardware_post_cycles += ACCEL_POST_TOTAL;
                    continue;
                }
#endif
                ACCEL_CONTROL = ACCEL_CONTROL_START;
                wait_gemm(diagnostic);
                gemm_wait_cycles += read_cycles() - cycle_start;
                hardware_gemm_cycles += ACCEL_TOTAL;
                hardware_compute_cycles += ACCEL_COMPUTE;

                if (k_offset + tile_k == k_total) {
                    cycle_start = read_cycles();
#if ENABLE_DESCRIPTOR_REUSE
                    if (!whole_tiles) {
#endif
                    ACCEL_POST_CONTROL = ACCEL_POST_CONTROL_CLEAR_STATUS;
                    ACCEL_POST_POSITIONS = tile_m;
                    ACCEL_POST_CHANNELS = tile_n;
                    ACCEL_POST_OPTIONS = pool ? ACCEL_POST_OPTION_POOL : 0u;
#if ENABLE_DESCRIPTOR_REUSE
                    ACCEL_POST_Q_STRIDE = output_length;
                    }
#endif
                    ACCEL_POST_PARAM_BASE = n_offset;
                    ACCEL_POST_Q_BASE = output_q_base + n_offset * output_length
                        + (pool ? m_offset / 2u : m_offset);
#if !ENABLE_DESCRIPTOR_REUSE
                    ACCEL_POST_Q_STRIDE = output_length;
#endif
                    ACCEL_POST_CONTROL = ACCEL_POST_CONTROL_START;
                    wait_post(diagnostic + 2u);
                    postprocess_cycles += read_cycles() - cycle_start;
                    hardware_post_cycles += ACCEL_POST_TOTAL;
                }
            }
        }
    }
}

#if !ENABLE_FUSED_GAP
static void run_global_average(void)
{
    uint32_t channel;
    for (channel = 0; channel < 64u; ++channel) {
        uint32_t sum = 0u;
        uint32_t position;
        for (position = 0; position < 32u; ++position)
            sum += (uint32_t)q_read_i8(Q_PONG_BASE + channel * 32u + position);
        ACCEL_Q[channel >> 2] = (ACCEL_Q[channel >> 2]
            & ~(0xffu << ((channel & 3u) * 8u)))
            | (((sum + 16u) >> 5) & 0xffu) << ((channel & 3u) * 8u);
    }
}
#endif

static void run_classifier(void)
{
    uint32_t channel;
    uint32_t cycle_start = read_cycles();
    ACCEL_CONTROL = ACCEL_CONTROL_CLEAR_STATUS;
    ACCEL_M = 1u;
    ACCEL_N = 4u;
    ACCEL_K = 64u;
    ACCEL_MODE = ACCEL_MODE_OVERWRITE;
#if ENABLE_HW_CLASSIFIER_INPUT
    // Interpret the contiguous GAP vector as 64 channels of length one.
    // The same loader gathers lane zero and zero-fills the other three lanes.
    ACCEL_LOAD_OUTPUT_BASE = 0u;
    ACCEL_LOAD_INPUT_LENGTH = 1u;
    ACCEL_LOAD_KERNEL = 1u; ACCEL_LOAD_PADDING = 0u;
    ACCEL_LOAD_CHANNEL_BASE = Q_PING_BASE; ACCEL_LOAD_START_TAP = 0u;
    ACCEL_LOAD_CONTROL = ACCEL_LOAD_CONTROL_CLEAR_STATUS;
    ACCEL_LOAD_CONTROL = ACCEL_LOAD_CONTROL_START;
    wait_loader(0xdead3004u);
#if !ENABLE_DIRECT_WEIGHTS
    for (channel = 0; channel < 64u; ++channel)
        ACCEL_B[channel] = ACCEL_WEIGHT[(WEIGHT_CLASSIFIER_BASE + channel * 4u) >> 2];
#endif
#else
    for (channel = 0; channel < 64u; ++channel) {
        ACCEL_A[channel] = (uint32_t)q_read_i8(Q_PING_BASE + channel) & 0xffu;
#if !ENABLE_DIRECT_WEIGHTS
        ACCEL_B[channel] = ACCEL_WEIGHT[(WEIGHT_CLASSIFIER_BASE + channel * 4u) >> 2];
#endif
    }
#endif
#if ENABLE_DIRECT_WEIGHTS
    ACCEL_WLOAD_START_WORD = WEIGHT_CLASSIFIER_BASE >> 2;
    ACCEL_WLOAD_STRIDE = 1u;
#endif
    pack_and_load_cycles += read_cycles() - cycle_start;
    cycle_start = read_cycles();
    ACCEL_CONTROL = ACCEL_CONTROL_START;
    wait_gemm(0xdead3100u);
    gemm_wait_cycles += read_cycles() - cycle_start;
    hardware_gemm_cycles += ACCEL_TOTAL;
    hardware_compute_cycles += ACCEL_COMPUTE;
#if ENABLE_BENCHMARK_OUTPUT
    for (channel = 0; channel < 4u; ++channel)
        benchmark_logits[channel] = ACCEL_C[channel] + classifier_bias[channel];
#endif
}

static void verify_logits(void)
{
    uint32_t output;
    for (output = 0; output < 4u; ++output) {
        int32_t logit =
#if ENABLE_BENCHMARK_OUTPUT
            benchmark_logits[output];
#else
            ACCEL_C[output] + classifier_bias[output];
#endif
        if (logit != expected_logits[output])
            report_and_halt(0xdead3200u + output);
    }
}

static __attribute__((noinline)) uint32_t run_inference(void)
{
    uint32_t index;
    uint32_t cycle_start;
    uint32_t measurement_start;
    uint32_t input_cycles;
    uint32_t parameter_cycles = 0u;
    uint32_t conv1_cycles;
    uint32_t conv2_cycles;
    uint32_t conv3_cycles;
    uint32_t average_cycles;
    uint32_t classifier_cycles;
    uint32_t inference_cycles;
    pack_and_load_cycles = 0u;
    gemm_wait_cycles = 0u;
    postprocess_cycles = 0u;
    hardware_gemm_cycles = 0u;
    hardware_compute_cycles = 0u;
    hardware_post_cycles = 0u;
#if ENABLE_SPLIT_PROFILE
    setup_cycles = 0u;
    input_pack_cycles = 0u;
    weight_load_cycles = 0u;
#endif
    if (ACCEL_VERSION != ACCEL_VERSION_RAI4)
        report_and_halt(0xdead0001u);
#if ENABLE_DIRECT_WEIGHTS
    if ((ACCEL_DIRECT_WEIGHT & ACCEL_DIRECT_WEIGHT_SUPPORTED) == 0u)
        report_and_halt(0xdead0002u);
#endif
#if ENABLE_CHAINED_POST
    if ((ACCEL_CHAIN_CONTROL & ACCEL_CHAIN_SUPPORTED) == 0u)
        report_and_halt(0xdead0003u);
#endif
    measurement_start = read_cycles();
    cycle_start = read_cycles();
    for (index = 0; index < 64u; ++index)
        ACCEL_Q[index] = network_input_words[index];
    input_cycles = read_cycles() - cycle_start;

    cycle_start = read_cycles();
    load_parameters(conv1_bias, conv1_shift, 32u);
#if ENABLE_DIRECT_WEIGHTS
    ACCEL_DIRECT_WEIGHT = ACCEL_DIRECT_WEIGHT_ENABLE;
#endif
    parameter_cycles += read_cycles() - cycle_start;
    cycle_start = read_cycles();
    run_conv_layer(128u, 32u, 14u, 7u, 3u, 128u, 64u,
                   Q_PING_BASE, Q_PONG_BASE, WEIGHT_CONV1_BASE, 1u, 0xdead1000u);
    conv1_cycles = read_cycles() - cycle_start;
    if (trace_checks && fnv_q(Q_PONG_BASE, 2048u) != EXPECTED_POOL1_FNV)
        report_and_halt(0xdead1100u);

    cycle_start = read_cycles();
    load_parameters(conv2_bias, conv2_shift, 64u);
    parameter_cycles += read_cycles() - cycle_start;
    cycle_start = read_cycles();
    run_conv_layer(64u, 64u, 160u, 5u, 2u, 64u, 32u,
                   Q_PONG_BASE, Q_PING_BASE, WEIGHT_CONV2_BASE, 1u, 0xdead2000u);
    conv2_cycles = read_cycles() - cycle_start;
    if (trace_checks && fnv_q(Q_PING_BASE, 2048u) != EXPECTED_POOL2_FNV)
        report_and_halt(0xdead2100u);

    cycle_start = read_cycles();
    load_parameters(conv3_bias, conv3_shift, 64u);
    parameter_cycles += read_cycles() - cycle_start;
#if ENABLE_FUSED_GAP
#if ENABLE_BENCHMARK_OUTPUT
    cycle_start = read_cycles();
#endif
    ACCEL_GAP_SOURCE_BASE = Q_PONG_BASE;
    ACCEL_GAP_DEST_BASE = Q_PING_BASE;
    ACCEL_GAP_LENGTH_LOG2 = 5u;
    ACCEL_GAP_CHANNELS = 64u;
    ACCEL_GAP_CONTROL = ACCEL_GAP_CONTROL_ENABLE | ACCEL_GAP_CONTROL_CLEAR
#if FUSED_GAP_SKIP_Q_WRITE
        | ACCEL_GAP_CONTROL_SKIP_SOURCE
#endif
        ;
    if ((ACCEL_GAP_STATUS & ACCEL_GAP_STATUS_ERROR) != 0u)
        report_and_halt(0xdead2700u);
#if ENABLE_BENCHMARK_OUTPUT
    parameter_cycles += read_cycles() - cycle_start;
#endif
#endif
    cycle_start = read_cycles();
    run_conv_layer(32u, 64u, 192u, 3u, 1u, 32u, 32u,
                   Q_PING_BASE, Q_PONG_BASE, WEIGHT_CONV3_BASE, 0u, 0xdead2800u);
    conv3_cycles = read_cycles() - cycle_start;
#if !(ENABLE_FUSED_GAP && FUSED_GAP_SKIP_Q_WRITE)
    if (trace_checks && fnv_q(Q_PONG_BASE, 2048u) != EXPECTED_CONV3_FNV)
        report_and_halt(0xdead2900u);
#endif

    cycle_start = read_cycles();
#if ENABLE_FUSED_GAP
    ACCEL_GAP_CONTROL = ACCEL_GAP_CONTROL_ENABLE | ACCEL_GAP_CONTROL_FINALIZE
#if FUSED_GAP_SKIP_Q_WRITE
        | ACCEL_GAP_CONTROL_SKIP_SOURCE
#endif
        ;
    wait_gap(0xdead3002u);
#else
    run_global_average();
#endif
    average_cycles = read_cycles() - cycle_start;
    if (trace_checks && fnv_q(Q_PING_BASE, 64u) != EXPECTED_AVERAGE_FNV)
        report_and_halt(0xdead3001u);

    cycle_start = read_cycles();
    run_classifier();
    classifier_cycles = read_cycles() - cycle_start;
    inference_cycles = read_cycles() - measurement_start;
    verify_logits();


    emit_metric(1u, input_cycles);
    emit_metric(2u, parameter_cycles);
    emit_metric(3u, conv1_cycles);
    emit_metric(4u, conv2_cycles);
    emit_metric(5u, conv3_cycles);
    emit_metric(6u, average_cycles);
    emit_metric(7u, classifier_cycles);
    emit_metric(8u, pack_and_load_cycles);
    emit_metric(9u, gemm_wait_cycles);
    emit_metric(10u, postprocess_cycles);
    emit_metric(11u, hardware_gemm_cycles);
    emit_metric(12u, hardware_compute_cycles);
    emit_metric(13u, hardware_post_cycles);
    emit_metric(14u, inference_cycles);
#if ENABLE_SPLIT_PROFILE
    emit_metric(15u, setup_cycles);
    emit_metric(16u, input_pack_cycles);
    emit_metric(17u, weight_load_cycles);
#endif
    return inference_cycles;
}

static void select_input(uint32_t c) {
 uint32_t i;
 for(i=0;i<64;i++) network_input_words[i]=frame_network_input_words[c][i];
 for(i=0;i<4;i++) expected_logits[i]=frame_expected_logits[c][i];
 live_fnv_0=frame_fnvs[c][0];live_fnv_1=frame_fnvs[c][1];
 live_fnv_2=frame_fnvs[c][2];live_fnv_3=frame_fnvs[c][3];
}

#include "m30_host_extension.h"
#include "r14_host_service.h"
