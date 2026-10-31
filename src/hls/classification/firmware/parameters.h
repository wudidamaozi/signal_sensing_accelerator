#ifndef PARAMETERS_H_
#define PARAMETERS_H_

#include "ap_fixed.h"
#include "ap_int.h"

#include "nnet_utils/nnet_code_gen.h"
#include "nnet_utils/nnet_helpers.h"
// hls-fpga-machine-learning insert includes
#include "nnet_utils/hls4ml_integer_post.h"
#include "nnet_utils/nnet_conv1d.h"
#include "nnet_utils/nnet_conv1d_stream.h"
#include "nnet_utils/nnet_dense.h"
#include "nnet_utils/nnet_dense_compressed.h"
#include "nnet_utils/nnet_dense_stream.h"
#include "nnet_utils/nnet_padding.h"
#include "nnet_utils/nnet_padding_stream.h"
#include "nnet_utils/nnet_pooling.h"
#include "nnet_utils/nnet_pooling_stream.h"

// hls-fpga-machine-learning insert weights
#include "weights/w2.h"
#include "weights/b2.h"
#include "weights/w5.h"
#include "weights/b5.h"
#include "weights/w8.h"
#include "weights/b8.h"
#include "weights/w11.h"
#include "weights/b11.h"


// hls-fpga-machine-learning insert layer-config
// zp1d_conv1
struct config12 : nnet::padding1d_config {
    static const unsigned in_width = 128;
    static const unsigned n_chan = 2;
    static const unsigned out_width = 134;
    static const unsigned pad_left = 3;
    static const unsigned pad_right = 3;
};

// conv1
struct config2_mult : nnet::dense_config {
    static const unsigned n_in = 14;
    static const unsigned n_out = 32;
    static const unsigned reuse_factor = 28;
    static const unsigned strategy = nnet::resource;
    static const unsigned n_zeros = 2;
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
    static const unsigned in_width = 134;
    static const unsigned n_chan = 2;
    static const unsigned filt_width = 7;
    static const unsigned kernel_size = filt_width;
    static const unsigned n_filt = 32;
    static const unsigned stride_width = 1;
    static const unsigned dilation = 1;
    static const unsigned out_width = 128;
    static const unsigned reuse_factor = 28;
    static const unsigned n_zeros = 2;
    static const unsigned multiplier_limit =
        DIV_ROUNDUP(kernel_size * n_chan * n_filt, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    static const unsigned strategy = nnet::resource;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned min_width = 134;
    static const ap_uint<filt_width> pixels[min_width];
    static const unsigned n_partitions = 128;
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

// conv1_rq
struct config3 { static const unsigned channels=32; static const unsigned length=128; static const unsigned shifts[32]; };
const unsigned config3::shifts[]={7,7,8,8,8,8,8,8,8,7,7,8,8,8,8,8,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8};

// conv1_pool
struct config4 : nnet::pooling1d_config {
    static const unsigned n_in = 128;
    static const unsigned n_out = 64;
    static const unsigned n_filt = 32;
    static const unsigned pool_width = 2;

    static const unsigned filt_width = pool_width;
    static const unsigned n_chan = n_filt;

    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const bool count_pad = false;
    static const unsigned stride_width = 2;
    static const nnet::Pool_Op pool_op = nnet::Max;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned reuse_factor = 1;
    typedef model_default_t accum_t;
};

// zp1d_conv2
struct config13 : nnet::padding1d_config {
    static const unsigned in_width = 64;
    static const unsigned n_chan = 32;
    static const unsigned out_width = 68;
    static const unsigned pad_left = 2;
    static const unsigned pad_right = 2;
};

// conv2
struct config5_mult : nnet::dense_config {
    static const unsigned n_in = 160;
    static const unsigned n_out = 64;
    static const unsigned reuse_factor = 640;
    static const unsigned strategy = nnet::resource;
    static const unsigned n_zeros = 162;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    typedef conv2_accum_t accum_t;
    typedef conv2_bias_t bias_t;
    typedef conv2_weight_t weight_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_gt_nin_rem0<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};

struct config5 : nnet::conv1d_config {
    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const unsigned in_width = 68;
    static const unsigned n_chan = 32;
    static const unsigned filt_width = 5;
    static const unsigned kernel_size = filt_width;
    static const unsigned n_filt = 64;
    static const unsigned stride_width = 1;
    static const unsigned dilation = 1;
    static const unsigned out_width = 64;
    static const unsigned reuse_factor = 640;
    static const unsigned n_zeros = 162;
    static const unsigned multiplier_limit =
        DIV_ROUNDUP(kernel_size * n_chan * n_filt, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    static const unsigned strategy = nnet::resource;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned min_width = 68;
    static const ap_uint<filt_width> pixels[min_width];
    static const unsigned n_partitions = 64;
    static const unsigned n_pixels = out_width / n_partitions;
    template<class data_T, class CONFIG_T>
    using fill_buffer = nnet::FillConv1DBuffer<data_T, CONFIG_T>;
    typedef conv2_accum_t accum_t;
    typedef conv2_bias_t bias_t;
    typedef conv2_weight_t weight_t;
    typedef config5_mult mult_config;
    template<unsigned K, unsigned S, unsigned W>
    using scale_index = nnet::scale_index_regular<K, S, W>;
    template<class data_T, class res_T, class CONFIG_T>
    using conv_kernel = nnet::Conv1DResource<data_T, res_T, CONFIG_T>;
};
const ap_uint<config5::filt_width> config5::pixels[] = {0};

// conv2_rq
struct config6 { static const unsigned channels=64; static const unsigned length=64; static const unsigned shifts[64]; };
const unsigned config6::shifts[]={11,10,10,10,10,10,11,10,10,11,10,10,11,10,11,9,10,10,11,10,10,10,11,10,11,10,9,11,11,9,10,10,11,11,9,11,10,10,9,10,10,10,10,10,11,10,10,10,10,10,10,10,9,10,10,10,10,10,11,10,10,9,10,11};

// conv2_pool
struct config7 : nnet::pooling1d_config {
    static const unsigned n_in = 64;
    static const unsigned n_out = 32;
    static const unsigned n_filt = 64;
    static const unsigned pool_width = 2;

    static const unsigned filt_width = pool_width;
    static const unsigned n_chan = n_filt;

    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const bool count_pad = false;
    static const unsigned stride_width = 2;
    static const nnet::Pool_Op pool_op = nnet::Max;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned reuse_factor = 1;
    typedef model_default_t accum_t;
};

// zp1d_conv3
struct config14 : nnet::padding1d_config {
    static const unsigned in_width = 32;
    static const unsigned n_chan = 64;
    static const unsigned out_width = 34;
    static const unsigned pad_left = 1;
    static const unsigned pad_right = 1;
};

// conv3
struct config8_mult : nnet::dense_config {
    static const unsigned n_in = 192;
    static const unsigned n_out = 64;
    static const unsigned reuse_factor = 768;
    static const unsigned strategy = nnet::resource;
    static const unsigned n_zeros = 172;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    typedef conv3_accum_t accum_t;
    typedef conv3_bias_t bias_t;
    typedef conv3_weight_t weight_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_gt_nin_rem0<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};

struct config8 : nnet::conv1d_config {
    static const unsigned pad_left = 0;
    static const unsigned pad_right = 0;
    static const unsigned in_width = 34;
    static const unsigned n_chan = 64;
    static const unsigned filt_width = 3;
    static const unsigned kernel_size = filt_width;
    static const unsigned n_filt = 64;
    static const unsigned stride_width = 1;
    static const unsigned dilation = 1;
    static const unsigned out_width = 32;
    static const unsigned reuse_factor = 768;
    static const unsigned n_zeros = 172;
    static const unsigned multiplier_limit =
        DIV_ROUNDUP(kernel_size * n_chan * n_filt, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    static const unsigned strategy = nnet::resource;
    static const nnet::conv_implementation implementation = nnet::conv_implementation::linebuffer;
    static const unsigned min_width = 34;
    static const ap_uint<filt_width> pixels[min_width];
    static const unsigned n_partitions = 32;
    static const unsigned n_pixels = out_width / n_partitions;
    template<class data_T, class CONFIG_T>
    using fill_buffer = nnet::FillConv1DBuffer<data_T, CONFIG_T>;
    typedef conv3_accum_t accum_t;
    typedef conv3_bias_t bias_t;
    typedef conv3_weight_t weight_t;
    typedef config8_mult mult_config;
    template<unsigned K, unsigned S, unsigned W>
    using scale_index = nnet::scale_index_regular<K, S, W>;
    template<class data_T, class res_T, class CONFIG_T>
    using conv_kernel = nnet::Conv1DResource<data_T, res_T, CONFIG_T>;
};
const ap_uint<config8::filt_width> config8::pixels[] = {0};

// conv3_rq
struct config9 { static const unsigned channels=64; static const unsigned length=32; static const unsigned shifts[64]; };
const unsigned config9::shifts[]={7,8,7,7,7,7,7,7,7,7,7,6,7,7,8,7,7,7,7,8,7,7,7,7,7,7,7,7,7,7,8,7,7,8,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,7,7,7,7,7,7,8,7,7,7,7,7,7,7};

// gap
struct config10 { static const unsigned channels=64; static const unsigned length=32; };

// classifier
struct config11 : nnet::dense_config {
    static const unsigned n_in = 64;
    static const unsigned n_out = 4;
    static const unsigned io_type = nnet::io_stream;
    static const unsigned strategy = nnet::resource;
    static const unsigned reuse_factor = 16;
    static const unsigned n_zeros = 3;
    static const unsigned n_nonzeros = 253;
    static const unsigned multiplier_limit = DIV_ROUNDUP(n_in * n_out, reuse_factor) - n_zeros / reuse_factor;
    static const bool store_weights_in_bram = false;
    typedef classifier_accum_t accum_t;
    typedef classifier_bias_t bias_t;
    typedef classifier_weight_t weight_t;
    typedef layer11_index index_t;
    template<class data_T, class res_T, class CONFIG_T>
    using kernel = nnet::DenseResource_rf_leq_nin<data_T, res_T, CONFIG_T>;
    template<class x_T, class y_T>
    using product = nnet::product::mult<x_T, y_T>;
};



#endif
