#ifndef EDGE_HLS4ML_INTEGER_POST_H
#define EDGE_HLS4ML_INTEGER_POST_H
#include "hls_stream.h"
#include "ap_int.h"
namespace nnet {
// Arithmetic adapters only: preserve the frozen INT8 model's rounding contract.
template<class data_T, class res_T, class CONFIG_T>
void edge_requant(hls::stream<data_T>& input, hls::stream<res_T>& output) {
    for (unsigned p = 0; p < CONFIG_T::length; ++p) {
        #pragma HLS PIPELINE II=1
        data_T data = input.read();
        res_T result;
        for (unsigned c = 0; c < CONFIG_T::channels; ++c) {
            #pragma HLS UNROLL
            ap_int<33> value = data[c];
            unsigned shift = CONFIG_T::shifts[c];
            ap_int<33> magnitude = value;
            if (value < 0) magnitude = -value;
            ap_int<33> scaled = magnitude;
            if (shift) scaled = (magnitude + (ap_int<33>(1) << (shift - 1))) >> shift;
            if (value < 0) scaled = -scaled;
            result[c] = scaled < 0 ? 0 : scaled > 127 ? 127 : scaled.to_int();
        }
        output.write(result);
    }
}
template<class data_T, class res_T, class CONFIG_T>
void edge_gap(hls::stream<data_T>& input, hls::stream<res_T>& output) {
    ap_int<32> sums[CONFIG_T::channels];
    #pragma HLS ARRAY_PARTITION variable=sums complete
    for (unsigned c = 0; c < CONFIG_T::channels; ++c) {
        #pragma HLS UNROLL
        sums[c] = 0;
    }
    for (unsigned p = 0; p < CONFIG_T::length; ++p) {
        #pragma HLS PIPELINE II=1
        data_T data = input.read();
        for (unsigned c = 0; c < CONFIG_T::channels; ++c) {
            #pragma HLS UNROLL
            sums[c] += data[c];
        }
    }
    res_T result;
    for (unsigned c = 0; c < CONFIG_T::channels; ++c) {
        #pragma HLS UNROLL
        // Inputs are nonnegative after ReLU; length is the frozen power-of-two 32.
        result[c] = (sums[c] + CONFIG_T::length / 2) / CONFIG_T::length;
    }
    output.write(result);
}
}
#endif
