#ifndef DEFINES_H_
#define DEFINES_H_

#include "ap_fixed.h"
#include "ap_int.h"
#include "nnet_utils/nnet_types.h"
#include <array>
#include <cstddef>
#include <cstdio>
#include <tuple>
#include <tuple>


// hls-fpga-machine-learning insert numbers

// hls-fpga-machine-learning insert layer-precision
typedef nnet::array<ap_int<8>, 2*1> input_t;
typedef ap_int<32> conv1_accum_t;
typedef nnet::array<ap_int<32>, 45*1> layer2_t;
typedef ap_int<8> conv1_weight_t;
typedef ap_int<32> conv1_bias_t;
typedef nnet::array<ap_int<8>, 45*1> layer3_t;
typedef ap_int<32> conv2_accum_t;
typedef nnet::array<ap_int<32>, 9*1> layer4_t;
typedef ap_int<8> conv2_weight_t;
typedef ap_int<32> conv2_bias_t;
typedef nnet::array<ap_int<8>, 9*1> layer5_t;
typedef ap_int<32> fc1_accum_t;
typedef nnet::array<ap_int<32>, 32*1> layer7_t;
typedef ap_int<8> fc1_weight_t;
typedef ap_int<32> fc1_bias_t;
typedef ap_uint<1> layer7_index;
typedef nnet::array<ap_int<8>, 32*1> layer8_t;
typedef ap_int<32> fc2_accum_t;
typedef nnet::array<ap_int<32>, 2*1> result_t;
typedef ap_int<8> fc2_weight_t;
typedef ap_int<32> fc2_bias_t;
typedef ap_uint<1> layer9_index;

// hls-fpga-machine-learning insert emulator-defines


#endif
