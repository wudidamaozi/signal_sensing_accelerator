#ifndef PARAMETERS_H_
#define PARAMETERS_H_

#include "ap_fixed.h"
#include "ap_int.h"

#include "nnet_utils/nnet_code_gen.h"
#include "nnet_utils/nnet_helpers.h"
// hls-fpga-machine-learning insert includes
#include "nnet_utils/nnet_conv1d.h"
#include "nnet_utils/nnet_conv1d_stream.h"
#include "nnet_utils/nnet_dense.h"
#include "nnet_utils/nnet_dense_compressed.h"
#include "nnet_utils/nnet_dense_stream.h"
#include "nnet_utils/occupancy_hls4ml_quant.h"

// hls-fpga-machine-learning insert weights
#include "weights/w2.h"
#include "weights/b2.h"
#include "weights/w4.h"
#include "weights/b4.h"
#include "weights/w7.h"
#include "weights/b7.h"
#include "weights/w9.h"
#include "weights/b9.h"


// hls-fpga-machine-learning insert layer-config
// conv1
struct config2_mult : nnet::dense_config {
    static const unsigned n_in = 16;
    static const unsigned n_out = 45;
    static const unsigned reuse_factor = 48;
    static const unsigned strategy = nnet::resource;
    static const unsigned n_zeros = 8;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    typedef conv1_accum_t accum_t;
    typedef conv1_bias_t bias_t;
    typedef conv1_weight_t weight_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_gt_nin_rem0<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};

struct config2 : nnet::conv1d_config {
    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const unsigned in_width = 128;
    static const unsigned n_chan = 2;
    static const unsigned filt_width = 8;
    static const unsigned kernel_size = filt_width;
    static const unsigned n_filt = 45;
    static const unsigned stride_width = 1;
    static const unsigned dilation = 1;
    static const unsigned out_width = 121;
    static const unsigned reuse_factor = 48;
    static const unsigned n_zeros = 8;
    static const unsigned multiplier_limit =
        DIV_ROUNDUP(kernel_size * n_chan * n_filt, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    static const unsigned strategy = nnet::resource;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned min_width = 128;
    static const ap_uint<filt_width> pixels[min_width];
    static const unsigned n_partitions = 121;
    static const unsigned n_pixels = out_width / n_partitions;
    template<class data_T, class CONFIG_T>
    using fill_buffer = nnet::FillConv1DBuffer<data_T, CONFIG_T>;
    typedef conv1_accum_t accum_t;
    typedef conv1_bias_t bias_t;
    typedef conv1_weight_t weight_t;
    typedef config2_mult mult_config;
    template<unsigned K, unsigned S, unsigned W>
    using scale_index = nnet::scale_index_regular<K, S, W>;
    template<class data_T, class res_T, class CONFIG_T>
    using conv_kernel = nnet::Conv1DResource<data_T, res_T, CONFIG_T>;
};
const ap_uint<config2::filt_width> config2::pixels[] = {0};

// conv1_q
struct config3 { static const unsigned length=121, channels=45, shift=8; static const bool relu=true; };
// conv2
struct config4_mult : nnet::dense_config {
    static const unsigned n_in = 270;
    static const unsigned n_out = 9;
    static const unsigned reuse_factor = 270;
    static const unsigned strategy = nnet::resource;
    static const unsigned n_zeros = 36;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    typedef conv2_accum_t accum_t;
    typedef conv2_bias_t bias_t;
    typedef conv2_weight_t weight_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_leq_nin<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};

struct config4 : nnet::conv1d_config {
    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const unsigned in_width = 121;
    static const unsigned n_chan = 45;
    static const unsigned filt_width = 6;
    static const unsigned kernel_size = filt_width;
    static const unsigned n_filt = 9;
    static const unsigned stride_width = 1;
    static const unsigned dilation = 1;
    static const unsigned out_width = 116;
    static const unsigned reuse_factor = 270;
    static const unsigned n_zeros = 36;
    static const unsigned multiplier_limit =
        DIV_ROUNDUP(kernel_size * n_chan * n_filt, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    static const unsigned strategy = nnet::resource;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned min_width = 121;
    static const ap_uint<filt_width> pixels[min_width];
    static const unsigned n_partitions = 116;
    static const unsigned n_pixels = out_width / n_partitions;
    template<class data_T, class CONFIG_T>
    using fill_buffer = nnet::FillConv1DBuffer<data_T, CONFIG_T>;
    typedef conv2_accum_t accum_t;
    typedef conv2_bias_t bias_t;
    typedef conv2_weight_t weight_t;
    typedef config4_mult mult_config;
    template<unsigned K, unsigned S, unsigned W>
    using scale_index = nnet::scale_index_regular<K, S, W>;
    template<class data_T, class res_T, class CONFIG_T>
    using conv_kernel = nnet::Conv1DResource<data_T, res_T, CONFIG_T>;
};
const ap_uint<config4::filt_width> config4::pixels[] = {0};

// conv2_q
struct config5 { static const unsigned length=116, channels=9, shift=8; static const bool relu=false; };
// fc1
struct config7 : nnet::dense_config {
    static const unsigned n_in = 1044;
    static const unsigned n_out = 32;
    static const unsigned io_type = nnet::io_stream;
    static const unsigned strategy = nnet::resource;
    static const unsigned reuse_factor = 2088;
    static const unsigned n_zeros = 1497;
    static const unsigned n_nonzeros = 31911;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    typedef fc1_accum_t accum_t;
    typedef fc1_bias_t bias_t;
    typedef fc1_weight_t weight_t;
    typedef layer7_index index_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_gt_nin_rem0<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};

// fc1_q
struct config8 { static const unsigned length=1, channels=32, shift=12; static const bool relu=true; };
// fc2
struct config9 : nnet::dense_config {
    static const unsigned n_in = 32;
    static const unsigned n_out = 2;
    static const unsigned io_type = nnet::io_stream;
    static const unsigned strategy = nnet::resource;
    static const unsigned reuse_factor = 32;
    static const unsigned n_zeros = 0;
    static const unsigned n_nonzeros = 64;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    typedef fc2_accum_t accum_t;
    typedef fc2_bias_t bias_t;
    typedef fc2_weight_t weight_t;
    typedef layer9_index index_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_leq_nin<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};



#endif
