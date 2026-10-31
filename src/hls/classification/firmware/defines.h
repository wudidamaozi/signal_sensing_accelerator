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
typedef nnet::array<ap_int<8>, 2*1> layer12_t;
typedef ap_int<32> conv1_accum_t;
typedef nnet::array<ap_int<32>, 32*1> layer2_t;
typedef ap_int<8> conv1_weight_t;
typedef ap_int<32> conv1_bias_t;
typedef nnet::array<ap_int<8>, 32*1> layer3_t;
typedef ap_int<32> model_default_t;
typedef nnet::array<ap_int<8>, 32*1> layer4_t;
typedef nnet::array<ap_int<8>, 32*1> layer13_t;
typedef ap_int<32> conv2_accum_t;
typedef nnet::array<ap_int<32>, 64*1> layer5_t;
typedef ap_int<8> conv2_weight_t;
typedef ap_int<32> conv2_bias_t;
typedef nnet::array<ap_int<8>, 64*1> layer6_t;
typedef nnet::array<ap_int<8>, 64*1> layer7_t;
typedef nnet::array<ap_int<8>, 64*1> layer14_t;
typedef ap_int<32> conv3_accum_t;
typedef nnet::array<ap_int<32>, 64*1> layer8_t;
typedef ap_int<8> conv3_weight_t;
typedef ap_int<32> conv3_bias_t;
typedef nnet::array<ap_int<8>, 64*1> layer9_t;
typedef nnet::array<ap_int<8>, 64*1> layer10_t;
typedef ap_int<32> classifier_accum_t;
typedef nnet::array<ap_int<32>, 4*1> result_t;
typedef ap_int<8> classifier_weight_t;
typedef ap_int<32> classifier_bias_t;
typedef ap_uint<1> layer11_index;

// hls-fpga-machine-learning insert emulator-defines


#endif
