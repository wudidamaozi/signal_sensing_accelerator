#include <stdint.h>
#include <stddef.h>
#include "model_data.h"
static int8_t ping[2048],pong[2048],scratch[4096],average[64];
static int32_t logits[4];
void *memcpy(void *d,const void *s,size_t n){unsigned char *a=d;const unsigned char *b=s;for(size_t i=0;i<n;i++)a[i]=b[i];return d;}
static uint32_t now_ns(void){uint32_t c;__asm__ volatile("rdcycle %0":"=r"(c));return c;}
static int8_t rq_relu(int32_t value, uint32_t shift) {
    if (value <= 0) return 0;
    uint64_t magnitude = (uint32_t)value;
    if (shift) magnitude = (magnitude + (1ull << (shift - 1))) >> shift;
    return magnitude > 127 ? 127 : (int8_t)magnitude;
}

/* Scalar control and blocked implementation share the same exact arithmetic.
 * Four adjacent output channels reuse an input and contiguous K-major weights.
 * This portable C loop permits the target compiler's normal auto-vectorization. */
static void convolution(const int8_t *input, int8_t *output, int length,
                        int channels, int outputs, int kernel, int padding,
                        int pool, int base, const int32_t *bias,
                        const uint32_t *shift, int blocked) {
    int block = blocked ? 4 : 1;
    for (int oc = 0; oc < outputs; oc += block) {
        for (int pos = 0; pos < length; ++pos) {
            int32_t acc[4] = {0, 0, 0, 0};
            for (int lane = 0; lane < block; ++lane) acc[lane] = bias[oc + lane];
            for (int ic = 0; ic < channels; ++ic) {
                for (int tap = 0; tap < kernel; ++tap) {
                    int ip = pos + tap - padding;
                    if (ip < 0 || ip >= length) continue;
                    int32_t sample = input[ic * length + ip];
                    const int8_t *w = network_weights + base + (ic * kernel + tap) * outputs + oc;
                    for (int lane = 0; lane < block; ++lane) acc[lane] += sample * w[lane];
                }
            }
            for (int lane = 0; lane < block; ++lane)
                scratch[(oc + lane) * length + pos] = rq_relu(acc[lane], shift[oc + lane]);
        }
    }
    if (pool) {
        for (int oc = 0; oc < outputs; ++oc)
            for (int p = 0; p < length / 2; ++p) {
                int8_t a = scratch[oc * length + 2 * p];
                int8_t b = scratch[oc * length + 2 * p + 1];
                output[oc * (length / 2) + p] = a > b ? a : b;
            }
    } else memcpy(output, scratch, (size_t)length * outputs);
}

static uint32_t fnv(const int8_t *, size_t);
static uint32_t hashes[4];
static void infer(const int8_t *input, int blocked, uint32_t stage[5]) {
    uint32_t start = now_ns();
    memcpy(ping, input, 256);
    stage[0] = now_ns() - start;
    start = now_ns();
    convolution(ping, pong, 128, 2, 32, 7, 3, 1, WEIGHT_CONV1_BASE, conv1_bias, conv1_shift, blocked);
    stage[1] = now_ns() - start; hashes[0]=fnv(pong,2048);
    start = now_ns();
    convolution(pong, ping, 64, 32, 64, 5, 2, 1, WEIGHT_CONV2_BASE, conv2_bias, conv2_shift, blocked);
    stage[2] = now_ns() - start; hashes[1]=fnv(ping,2048);
    start = now_ns();
    convolution(ping, pong, 32, 64, 64, 3, 1, 0, WEIGHT_CONV3_BASE, conv3_bias, conv3_shift, blocked);
    stage[3] = now_ns() - start; hashes[2]=fnv(pong,2048);
    start = now_ns();
    for (int c = 0; c < 64; ++c) {
        int32_t sum = 0;
        for (int p = 0; p < 32; ++p) sum += pong[c * 32 + p];
        average[c] = (int8_t)((sum + 16) >> 5);
    }
    for (int o = 0; o < 4; ++o) {
        int32_t acc = classifier_bias[o];
        for (int c = 0; c < 64; ++c) acc += average[c] * network_weights[WEIGHT_CLASSIFIER_BASE + c * 4 + o];
        logits[o] = acc;
    }
    stage[4] = now_ns() - start; hashes[3]=fnv(average,64);
}

static uint32_t fnv(const int8_t *data, size_t count) {
    uint32_t h = 0x811c9dc5u;
    for (size_t i = 0; i < count; ++i) { h ^= (uint8_t)data[i]; h *= 0x01000193u; }
    return h;
}


#define HOST (*(volatile uint32_t*)0x20000000u)
static void emit(uint32_t n,uint32_t v){HOST=0xa5000000u|n;HOST=v;}
int main(void){
 for(uint32_t rep=0;rep<2;rep++){
  uint32_t stage[5];infer(fixture_inputs[0],1,stage);
  for(uint32_t k=0;k<3;k++)if(hashes[k]!=fixture_fnvs[0][k]){HOST=0xdead1000u+k;while(1){}}
  if(hashes[3]!=0x52ff479au){HOST=0xdead1003u;while(1){}}
  for(uint32_t k=0;k<4;k++)if(logits[k]!=fixture_logits[0][k]){HOST=0xdead2000u+k;while(1){}}
  uint32_t total=0;for(uint32_t k=0;k<5;k++){total+=stage[k];emit(rep*16+k+1,stage[k]);}
  for(uint32_t k=0;k<4;k++)emit(40+rep*8+k,hashes[k]);
  for(uint32_t k=0;k<4;k++)emit(44+rep*8+k,(uint32_t)logits[k]);
  emit(14+rep*16,total);
 }
 HOST=1;while(1){}
}
__asm__(".section .text.start\n.global _start\n_start:\nli sp,131072\ncall main\n1:j 1b\n");
