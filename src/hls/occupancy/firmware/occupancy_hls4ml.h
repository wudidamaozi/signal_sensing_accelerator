#ifndef OCCUPANCY_HLS4ML_H_
#define OCCUPANCY_HLS4ML_H_

#include "ap_fixed.h"
#include "ap_int.h"
#include "hls_stream.h"

#include "defines.h"


// Prototype of top level function for C-synthesis
void occupancy_hls4ml(
    hls::stream<input_t> &iq,
    hls::stream<result_t> &layer9_out
);

// hls-fpga-machine-learning insert emulator-defines


#endif
