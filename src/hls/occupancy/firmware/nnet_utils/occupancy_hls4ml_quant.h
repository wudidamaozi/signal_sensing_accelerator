#ifndef OCCUPANCY_HLS4ML_QUANT_H
#define OCCUPANCY_HLS4ML_QUANT_H
#include "ap_int.h"
#include "hls_stream.h"
namespace nnet {
// Arithmetic adapter only. Conv/Dense/Reshape remain upstream hls4ml operators.
template<class data_T, class res_T, class CONFIG_T>
void occupancy_quant(hls::stream<data_T>& input, hls::stream<res_T>& output) {
    for (unsigned p=0; p<CONFIG_T::length; ++p) {
        #pragma HLS PIPELINE II=1
        data_T x=input.read(); res_T y;
        for (unsigned c=0; c<CONFIG_T::channels; ++c) {
            #pragma HLS UNROLL
            ap_int<33> v=x[c], m=v;
            if (v<0) m=-v;
            if (CONFIG_T::shift) m=(m+(ap_int<33>(1)<<(CONFIG_T::shift-1)))>>CONFIG_T::shift;
            ap_int<33> q=m;
            if (v<0) q=-m;
            const int low=CONFIG_T::relu?0:-128;
            y[c]=q<low?low:q>127?127:q.to_int();
        }
        output.write(y);
    }
}
}
#endif
