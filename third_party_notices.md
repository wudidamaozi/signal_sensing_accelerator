# Third-party notices

The root MIT license covers original team contributions, not the third-party materials below.

- PicoRV32: retain the full ISC permission/copyright text already present in the distributed Verilog sources.
- hls4ml v1.3.0: upstream https://github.com/fastmachinelearning/hls4ml , Apache-2.0. License and copyright notices are retained in `src/third_party/`.
- Public arbitrary-precision headers in the frozen HLS project: Xilinx copyright and Apache-2.0 notices remain in each header. Proprietary Vivado/Vitis binaries and private installation files are not distributed.
- Caffe im2col: upstream https://github.com/BVLC/caffe , original notices in `src/third_party/caffe_license.txt`. The baseline is a project port plus the 4×8 GEMM engine, not a complete Caffe deployment.
- RadioML 2016.10A sample subset and derived class test vectors: DeepSig Inc., https://www.deepsig.ai/datasets/ , CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/ . Selection/packaging and quantization are project transformations. The original data terms, attribution, noncommercial condition and share-alike terms are not replaced by MIT. The full dataset is not bundled.

Tool dependencies must be obtained from their respective publishers. No credentials, activation files or installed vendor toolchain are included. Required third-party attribution is not the participating team's school affiliation.
