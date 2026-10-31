#ifndef ACCELERATOR_REGS_H
#define ACCELERATOR_REGS_H

typedef unsigned int uint32_t;
typedef signed int int32_t;

#define ACCEL_BASE       0x10000000u
#define ACCEL_CONTROL    (*(volatile uint32_t *)(ACCEL_BASE + 0x0000u))
#define ACCEL_STATUS     (*(volatile uint32_t *)(ACCEL_BASE + 0x0004u))
#define ACCEL_M          (*(volatile uint32_t *)(ACCEL_BASE + 0x0008u))
#define ACCEL_N          (*(volatile uint32_t *)(ACCEL_BASE + 0x000cu))
#define ACCEL_K          (*(volatile uint32_t *)(ACCEL_BASE + 0x0010u))
#define ACCEL_TOTAL      (*(volatile uint32_t *)(ACCEL_BASE + 0x0014u))
#define ACCEL_COMPUTE    (*(volatile uint32_t *)(ACCEL_BASE + 0x0018u))
#define ACCEL_VERSION    (*(volatile uint32_t *)(ACCEL_BASE + 0x001cu))
#define ACCEL_MODE       (*(volatile uint32_t *)(ACCEL_BASE + 0x0020u))
#define ACCEL_POST_CONTROL     (*(volatile uint32_t *)(ACCEL_BASE + 0x0024u))
#define ACCEL_POST_STATUS      (*(volatile uint32_t *)(ACCEL_BASE + 0x0028u))
#define ACCEL_POST_POSITIONS   (*(volatile uint32_t *)(ACCEL_BASE + 0x002cu))
#define ACCEL_POST_CHANNELS    (*(volatile uint32_t *)(ACCEL_BASE + 0x0030u))
#define ACCEL_POST_OPTIONS     (*(volatile uint32_t *)(ACCEL_BASE + 0x0034u))
#define ACCEL_POST_PARAM_BASE  (*(volatile uint32_t *)(ACCEL_BASE + 0x0038u))
#define ACCEL_POST_Q_BASE      (*(volatile uint32_t *)(ACCEL_BASE + 0x003cu))
#define ACCEL_POST_Q_STRIDE    (*(volatile uint32_t *)(ACCEL_BASE + 0x0040u))
#define ACCEL_POST_TOTAL       (*(volatile uint32_t *)(ACCEL_BASE + 0x0044u))
#define ACCEL_POST_OUTPUTS     (*(volatile uint32_t *)(ACCEL_BASE + 0x0048u))
#define ACCEL_POST_SATURATIONS (*(volatile uint32_t *)(ACCEL_BASE + 0x004cu))
// Autonomous Q-to-A window loader (M17 trial).
#define ACCEL_LOAD_CONTROL     (*(volatile uint32_t *)(ACCEL_BASE + 0x0050u))
#define ACCEL_LOAD_STATUS      (*(volatile uint32_t *)(ACCEL_BASE + 0x0054u))
#define ACCEL_LOAD_OUTPUT_BASE (*(volatile uint32_t *)(ACCEL_BASE + 0x0058u))
#define ACCEL_LOAD_INPUT_LENGTH (*(volatile uint32_t *)(ACCEL_BASE + 0x005cu))
#define ACCEL_LOAD_KERNEL      (*(volatile uint32_t *)(ACCEL_BASE + 0x0060u))
#define ACCEL_LOAD_PADDING     (*(volatile uint32_t *)(ACCEL_BASE + 0x0064u))
#define ACCEL_LOAD_CHANNEL_BASE (*(volatile uint32_t *)(ACCEL_BASE + 0x0068u))
#define ACCEL_LOAD_START_TAP   (*(volatile uint32_t *)(ACCEL_BASE + 0x006cu))
// Configurable packed-weight gather into the existing B tile buffer (M18).
#define ACCEL_WLOAD_CONTROL    (*(volatile uint32_t *)(ACCEL_BASE + 0x0070u))
#define ACCEL_WLOAD_STATUS     (*(volatile uint32_t *)(ACCEL_BASE + 0x0074u))
#define ACCEL_WLOAD_START_WORD (*(volatile uint32_t *)(ACCEL_BASE + 0x0078u))
#define ACCEL_WLOAD_STRIDE     (*(volatile uint32_t *)(ACCEL_BASE + 0x007cu))
// Online post-process to global-average reduction (M19 trial).
#define ACCEL_GAP_CONTROL      (*(volatile uint32_t *)(ACCEL_BASE + 0x0080u))
#define ACCEL_GAP_STATUS       (*(volatile uint32_t *)(ACCEL_BASE + 0x0084u))
#define ACCEL_GAP_SOURCE_BASE  (*(volatile uint32_t *)(ACCEL_BASE + 0x0088u))
#define ACCEL_GAP_DEST_BASE    (*(volatile uint32_t *)(ACCEL_BASE + 0x008cu))
#define ACCEL_GAP_LENGTH_LOG2  (*(volatile uint32_t *)(ACCEL_BASE + 0x0090u))
#define ACCEL_GAP_CHANNELS     (*(volatile uint32_t *)(ACCEL_BASE + 0x0094u))
// M25 optional direct read from the resident K-major weight store.
#define ACCEL_DIRECT_WEIGHT    (*(volatile uint32_t *)(ACCEL_BASE + 0x0098u))
#define ACCEL_DIRECT_WEIGHT_ENABLE 0x00000001u
#define ACCEL_DIRECT_WEIGHT_SUPPORTED 0x80000000u
// Optional GEMM -> requant/ReLU/pool hardware command chain (M26).
#define ACCEL_CHAIN_CONTROL     (*(volatile uint32_t *)(ACCEL_BASE + 0x009cu))
#define ACCEL_CHAIN_STATUS      (*(volatile uint32_t *)(ACCEL_BASE + 0x00a0u))
#define ACCEL_CHAIN_SUPPORTED   0x80000000u
#define ACCEL_CHAIN_START       0x00000001u
#define ACCEL_CHAIN_CLEAR       0x00000002u

// M27 opt-in complete-K, full 16x16 layer scheduler.
#define ACCEL_LAYER_CONTROL     (*(volatile uint32_t *)(ACCEL_BASE + 0x00a4u))
#define ACCEL_LAYER_STATUS      (*(volatile uint32_t *)(ACCEL_BASE + 0x00a8u))
#define ACCEL_LAYER_M           (*(volatile uint32_t *)(ACCEL_BASE + 0x00acu))
#define ACCEL_LAYER_N           (*(volatile uint32_t *)(ACCEL_BASE + 0x00b0u))
#define ACCEL_LAYER_TOTAL       (*(volatile uint32_t *)(ACCEL_BASE + 0x00b4u))
#define ACCEL_LAYER_GEMM        (*(volatile uint32_t *)(ACCEL_BASE + 0x00b8u))
#define ACCEL_LAYER_COMPUTE     (*(volatile uint32_t *)(ACCEL_BASE + 0x00bcu))
#define ACCEL_LAYER_POST        (*(volatile uint32_t *)(ACCEL_BASE + 0x00c0u))
#define ACCEL_LAYER_SUPPORTED   0x80000000u

#define ACCEL_A          ((volatile uint32_t *)(ACCEL_BASE + 0x1000u))
#define ACCEL_B          ((volatile uint32_t *)(ACCEL_BASE + 0x2000u))
#define ACCEL_C          ((volatile int32_t  *)(ACCEL_BASE + 0x3000u))
#define ACCEL_Q          ((volatile uint32_t *)(ACCEL_BASE + 0x4000u))
#define ACCEL_WEIGHT     ((volatile uint32_t *)(ACCEL_BASE + 0x6000u))
#define ACCEL_BIAS       ((volatile int32_t  *)(ACCEL_BASE + 0xc000u))
#define ACCEL_SHIFT      ((volatile uint32_t *)(ACCEL_BASE + 0xc100u))

#define ACCEL_CONTROL_START        0x00000001u
#define ACCEL_CONTROL_CLEAR_STATUS 0x00000002u
#define ACCEL_STATUS_BUSY          0x00000001u
#define ACCEL_STATUS_DONE          0x00000002u
#define ACCEL_STATUS_ERROR         0x00000004u
#define ACCEL_MODE_OVERWRITE       0x00000000u
#define ACCEL_MODE_ACCUMULATE      0x00000001u
#define ACCEL_POST_CONTROL_START        0x00000001u
#define ACCEL_POST_CONTROL_CLEAR_STATUS 0x00000002u
#define ACCEL_POST_STATUS_BUSY          0x00000001u
#define ACCEL_POST_STATUS_DONE          0x00000002u
#define ACCEL_POST_STATUS_ERROR         0x00000004u
#define ACCEL_POST_OPTION_POOL          0x00000001u
#define ACCEL_LOAD_CONTROL_START        0x00000001u
#define ACCEL_LOAD_CONTROL_CLEAR_STATUS 0x00000002u
#define ACCEL_LOAD_STATUS_BUSY          0x00000001u
#define ACCEL_LOAD_STATUS_DONE          0x00000002u
#define ACCEL_LOAD_STATUS_ERROR         0x00000004u
#define ACCEL_WLOAD_CONTROL_START        0x00000001u
#define ACCEL_WLOAD_CONTROL_CLEAR_STATUS 0x00000002u
#define ACCEL_WLOAD_STATUS_BUSY          0x00000001u
#define ACCEL_WLOAD_STATUS_DONE          0x00000002u
#define ACCEL_WLOAD_STATUS_ERROR         0x00000004u
#define ACCEL_GAP_CONTROL_ENABLE         0x00000001u
#define ACCEL_GAP_CONTROL_CLEAR          0x00000002u
#define ACCEL_GAP_CONTROL_FINALIZE       0x00000004u
#define ACCEL_GAP_CONTROL_SKIP_SOURCE    0x00000008u
#define ACCEL_GAP_STATUS_BUSY            0x00000001u
#define ACCEL_GAP_STATUS_DONE            0x00000002u
#define ACCEL_GAP_STATUS_ERROR           0x00000004u
#define ACCEL_VERSION_RAI4         0x52414934u

#endif
