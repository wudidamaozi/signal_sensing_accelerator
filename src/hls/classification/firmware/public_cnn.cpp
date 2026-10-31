#include <iostream>

#include "public_cnn.h"
#include "parameters.h"


void public_cnn(
    hls::stream<input_t> &iq_input,
    hls::stream<result_t> &layer11_out
) {

    // hls-fpga-machine-learning insert IO
    #pragma HLS INTERFACE axis port=iq_input,layer11_out 
    #pragma HLS DATAFLOW

    // hls-fpga-machine-learning insert load weights
#ifndef __SYNTHESIS__
    static bool loaded_weights = false;
    if (!loaded_weights) {
        nnet::load_weights_from_txt<conv1_weight_t, 448>(w2, "w2.txt");
        nnet::load_weights_from_txt<conv1_bias_t, 32>(b2, "b2.txt");
        nnet::load_weights_from_txt<conv2_weight_t, 10240>(w5, "w5.txt");
        nnet::load_weights_from_txt<conv2_bias_t, 64>(b5, "b5.txt");
        nnet::load_weights_from_txt<conv3_weight_t, 12288>(w8, "w8.txt");
        nnet::load_weights_from_txt<conv3_bias_t, 64>(b8, "b8.txt");
        nnet::load_weights_from_txt<classifier_weight_t, 256>(w11, "w11.txt");
        nnet::load_weights_from_txt<classifier_bias_t, 4>(b11, "b11.txt");
        loaded_weights = true;    }
#endif
    // ****************************************
    // NETWORK INSTANTIATION
    // ****************************************

    // hls-fpga-machine-learning insert layers

    hls::stream<layer12_t> layer12_out("layer12_out");
    #pragma HLS STREAM variable=layer12_out depth=2

    hls::stream<layer2_t> layer2_out("layer2_out");
    #pragma HLS STREAM variable=layer2_out depth=2

    hls::stream<layer3_t> layer3_out("layer3_out");
    #pragma HLS STREAM variable=layer3_out depth=2

    hls::stream<layer4_t> layer4_out("layer4_out");
    #pragma HLS STREAM variable=layer4_out depth=2

    hls::stream<layer13_t> layer13_out("layer13_out");
    #pragma HLS STREAM variable=layer13_out depth=2

    hls::stream<layer5_t> layer5_out("layer5_out");
    #pragma HLS STREAM variable=layer5_out depth=2

    hls::stream<layer6_t> layer6_out("layer6_out");
    #pragma HLS STREAM variable=layer6_out depth=2

    hls::stream<layer7_t> layer7_out("layer7_out");
    #pragma HLS STREAM variable=layer7_out depth=2

    hls::stream<layer14_t> layer14_out("layer14_out");
    #pragma HLS STREAM variable=layer14_out depth=2

    hls::stream<layer8_t> layer8_out("layer8_out");
    #pragma HLS STREAM variable=layer8_out depth=2

    hls::stream<layer9_t> layer9_out("layer9_out");
    #pragma HLS STREAM variable=layer9_out depth=2

    hls::stream<layer10_t> layer10_out("layer10_out");
    #pragma HLS STREAM variable=layer10_out depth=1

    nnet::zeropad1d_cl<input_t, layer12_t, config12>(iq_input, layer12_out); // zp1d_conv1

    nnet::conv_1d_cl<layer12_t, layer2_t, config2>(layer12_out, layer2_out, w2, b2); // conv1

    nnet::edge_requant<layer2_t, layer3_t, config3>(layer2_out, layer3_out); // conv1_rq

    nnet::pooling1d_cl<layer3_t, layer4_t, config4>(layer3_out, layer4_out); // conv1_pool

    nnet::zeropad1d_cl<layer4_t, layer13_t, config13>(layer4_out, layer13_out); // zp1d_conv2

    nnet::conv_1d_cl<layer13_t, layer5_t, config5>(layer13_out, layer5_out, w5, b5); // conv2

    nnet::edge_requant<layer5_t, layer6_t, config6>(layer5_out, layer6_out); // conv2_rq

    nnet::pooling1d_cl<layer6_t, layer7_t, config7>(layer6_out, layer7_out); // conv2_pool

    nnet::zeropad1d_cl<layer7_t, layer14_t, config14>(layer7_out, layer14_out); // zp1d_conv3

    nnet::conv_1d_cl<layer14_t, layer8_t, config8>(layer14_out, layer8_out, w8, b8); // conv3

    nnet::edge_requant<layer8_t, layer9_t, config9>(layer8_out, layer9_out); // conv3_rq

    nnet::edge_gap<layer9_t, layer10_t, config10>(layer9_out, layer10_out); // gap

    nnet::dense<layer10_t, result_t, config11>(layer10_out, layer11_out, w11, b11); // classifier

}

