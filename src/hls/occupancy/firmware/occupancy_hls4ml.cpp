#include <iostream>

#include "occupancy_hls4ml.h"
#include "parameters.h"


void occupancy_hls4ml(
    hls::stream<input_t> &iq,
    hls::stream<result_t> &layer9_out
) {

    // hls-fpga-machine-learning insert IO
    #pragma HLS INTERFACE axis port=iq,layer9_out 
    #pragma HLS DATAFLOW

    // hls-fpga-machine-learning insert load weights
#ifndef __SYNTHESIS__
    static bool loaded_weights = false;
    if (!loaded_weights) {
        nnet::load_weights_from_txt<conv1_weight_t, 720>(w2, "w2.txt");
        nnet::load_weights_from_txt<conv1_bias_t, 45>(b2, "b2.txt");
        nnet::load_weights_from_txt<conv2_weight_t, 2430>(w4, "w4.txt");
        nnet::load_weights_from_txt<conv2_bias_t, 9>(b4, "b4.txt");
        nnet::load_weights_from_txt<fc1_weight_t, 33408>(w7, "w7.txt");
        nnet::load_weights_from_txt<fc1_bias_t, 32>(b7, "b7.txt");
        nnet::load_weights_from_txt<fc2_weight_t, 64>(w9, "w9.txt");
        nnet::load_weights_from_txt<fc2_bias_t, 2>(b9, "b9.txt");
        loaded_weights = true;    }
#endif
    // ****************************************
    // NETWORK INSTANTIATION
    // ****************************************

    // hls-fpga-machine-learning insert layers

    hls::stream<layer2_t> layer2_out("layer2_out");
    #pragma HLS STREAM variable=layer2_out depth=2

    hls::stream<layer3_t> layer3_out("layer3_out");
    #pragma HLS STREAM variable=layer3_out depth=2

    hls::stream<layer4_t> layer4_out("layer4_out");
    #pragma HLS STREAM variable=layer4_out depth=2

    hls::stream<layer5_t> layer5_out("layer5_out");
    #pragma HLS STREAM variable=layer5_out depth=2

    auto& layer6_out = layer5_out;
    hls::stream<layer7_t> layer7_out("layer7_out");
    #pragma HLS STREAM variable=layer7_out depth=1

    hls::stream<layer8_t> layer8_out("layer8_out");
    #pragma HLS STREAM variable=layer8_out depth=1

    nnet::conv_1d_cl<input_t, layer2_t, config2>(iq, layer2_out, w2, b2); // conv1

    nnet::occupancy_quant<layer2_t, layer3_t, config3>(layer2_out, layer3_out); // conv1_q

    nnet::conv_1d_cl<layer3_t, layer4_t, config4>(layer3_out, layer4_out, w4, b4); // conv2

    nnet::occupancy_quant<layer4_t, layer5_t, config5>(layer4_out, layer5_out); // conv2_q

    nnet::dense<layer5_t, layer7_t, config7>(layer6_out, layer7_out, w7, b7); // fc1

    nnet::occupancy_quant<layer7_t, layer8_t, config8>(layer7_out, layer8_out); // fc1_q

    nnet::dense<layer8_t, result_t, config9>(layer8_out, layer9_out, w9, b9); // fc2

}

