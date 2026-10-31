/* Public Caffe im2col lowering + unchanged 4x8 GEMM. O06: reuse channel bias and output pointers; exact ReLU zero shortcut. */
#include "accelerator_regs.h"
#include "../occupancy/occupancy_data.h"
#ifndef USE_ACCEL
#define USE_ACCEL 1
#endif
#define HOST (*(volatile uint32_t *)0x20000000u)
#define MAXK 192u
static uint32_t job_error;
static signed char input[256] __attribute__((aligned(4)));
static signed char conv1[5445] __attribute__((aligned(4)));
static signed char conv2[1044] __attribute__((aligned(4)));
static signed char fc1[32] __attribute__((aligned(4)));
static int32_t logits[2];
#if USE_ACCEL

static uint32_t in_qbase,out_qbase,weight_base,weight_stride;
// Explicit columns replace Q/window storage; do not charge unused Q uploads.
static void q_upload(const signed char *p,uint32_t n,uint32_t b){(void)p;(void)n;(void)b;}
extern void edge_caffe_im2col_tile(const signed char *,int,int,int,signed char *);
static signed char columns[31320] __attribute__((aligned(4)));
static void preload(const signed char *w,uint32_t k_total,uint32_t outputs,uint32_t stride,uint32_t base){
    for(uint32_t k=0;k<k_total;++k)for(uint32_t g=0;g<stride;++g){uint32_t word=0;for(uint32_t lane=0;lane<4u;++lane){uint32_t o=g*4u+lane;if(o<outputs)word|=((uint32_t)w[o*k_total+k]&255u)<<(lane*8u);}ACCEL_WEIGHT[base+k*stride+g]=word;}
}
static void wait_load(volatile uint32_t *status,uint32_t fail){
    uint32_t timeout=1000000u,s;do{s=*status;if(!timeout--){job_error=fail;return;}}while(!(s&2u));if(s&4u){job_error=fail;return;}
}

#endif
static uint32_t cycles(void){uint32_t c;__asm__ volatile("rdcycle %0":"=r"(c));return c;}
static void emit(uint32_t tag,uint32_t v){HOST=tag;HOST=v;}
static uint32_t hash(const signed char *x,uint32_t n){uint32_t h=0x811c9dc5u;for(uint32_t i=0;i<n;++i){h^=(uint32_t)x[i]&255u;h*=0x01000193u;}return h;}
static int32_t quant(int32_t v,uint32_t shift,int relu){
    if(relu && v<=0)return 0;
    int32_t q=v;
    if(shift){uint32_t m=v<0?(0u-(uint32_t)v):(uint32_t)v;m=(m+(1u<<(shift-1)))>>shift;q=v<0?-(int32_t)m:(int32_t)m;}
    if(q>127)q=127;
    if(q<(relu?0:-128))q=relu?0:-128;
    return q;
}
static void layer(const signed char *x,uint32_t length,uint32_t channels,uint32_t kernel,
                  const signed char *w,const int32_t *bias,uint32_t outputs,
                  uint32_t shift,int relu,signed char *out,int32_t *final){
    uint32_t positions=length-kernel+1u,k_total=channels*kernel;
#if USE_ACCEL
    (void)w;
#endif
    edge_caffe_im2col_tile(x,(int)channels,(int)length,(int)kernel,columns);
    for(uint32_t pos=0;pos<positions;pos+=4u)for(uint32_t oc=0;oc<outputs;oc+=8u){
        uint32_t mm=positions-pos<4u?positions-pos:4u,nn=outputs-oc<8u?outputs-oc:8u;
#if USE_ACCEL
        for(uint32_t k0=0;k0<k_total;k0+=MAXK){
            uint32_t kkmax=k_total-k0<MAXK?k_total-k0:MAXK,ch=0,tap=k0;
            while(tap>=kernel){tap-=kernel;++ch;}
            ACCEL_CONTROL=ACCEL_CONTROL_CLEAR_STATUS;
            ACCEL_M=mm;ACCEL_N=nn;ACCEL_K=kkmax;ACCEL_MODE=k0?ACCEL_MODE_ACCUMULATE:ACCEL_MODE_OVERWRITE;
            for(uint32_t k=0;k<kkmax;++k){
                uint32_t packed=0;
                for(uint32_t m=0;m<mm;++m)
                    packed|=((uint32_t)columns[(k0+k)*positions+pos+m]&255u)<<(m*8u);
                ACCEL_A[k]=packed;
            }
            ACCEL_WLOAD_START_WORD=weight_base+(oc>>2)+k0*weight_stride;
            ACCEL_WLOAD_STRIDE=weight_stride;
            ACCEL_WLOAD_CONTROL=ACCEL_WLOAD_CONTROL_CLEAR_STATUS;
            ACCEL_WLOAD_CONTROL=ACCEL_WLOAD_CONTROL_START;
            wait_load(&ACCEL_WLOAD_STATUS,0xdead9400u);if(job_error)return;
            ACCEL_CONTROL=ACCEL_CONTROL_START;
            uint32_t timeout=1000000u,status;
            do{status=ACCEL_STATUS;if(!timeout--){job_error=0xdead9001u;return;}}while(!(status&ACCEL_STATUS_DONE));
            if(status&ACCEL_STATUS_ERROR){job_error=0xdead9002u;return;}
        }
#endif
        // Four rows share a channel bias; output positions are contiguous.
        for(uint32_t n=0;n<nn;++n){
            const int32_t channel_bias=bias[oc+n];
            signed char *dest=final ? 0 : out+(oc+n)*positions+pos;
#if USE_ACCEL
            volatile int32_t *c=ACCEL_C+n;
#endif
            for(uint32_t m=0;m<mm;++m){
                int32_t sum=channel_bias;
#if USE_ACCEL
                sum+=*c;c+=nn;
#else
                for(uint32_t channel=0;channel<channels;++channel)for(uint32_t tap=0;tap<kernel;++tap)
                    sum+=(int32_t)x[channel*length+pos+m+tap]*(int32_t)w[(oc+n)*k_total+channel*kernel+tap];
#endif
                if(final)final[oc+n]=sum;else *dest++=(signed char)quant(sum,shift,relu);
            }
        }
    }
#if USE_ACCEL
    if(out)q_upload(out,outputs*positions,out_qbase);
#endif
}
// Mailbox ABI2, input is channel-major INT8 I[128],Q[128].
#define MB(offset) (*(volatile uint32_t *)(0x30000000u+(offset)))
int main(void){
    preload(w_conv1,16,45,16,0);preload(w_conv2,270,9,4,256);
    preload(w_fc1,1044,32,8,1336);preload(w_fc2,32,2,1,9688);
    MB(0x80)=1;
    for(;;){
        while(!(MB(8)&2u)){}
        uint32_t id=MB(0x18);MB(0x84)=1;job_error=0;
        uint32_t t[6];t[0]=cycles();
        for(uint32_t i=0;i<64;++i){uint32_t v=MB(0x100+i*4);for(uint32_t b=0;b<4;++b)input[i*4+b]=(signed char)(v>>(b*8));}
        q_upload(input,256,0);in_qbase=0;out_qbase=2048;weight_base=0;weight_stride=16;
        t[1]=cycles();
        layer(input,128,2,8,w_conv1,b_conv1,45,SHIFT_CONV1,1,conv1,0);t[2]=cycles();
        in_qbase=2048;out_qbase=0;weight_base=256;weight_stride=4;
        if(!job_error)layer(conv1,121,45,6,w_conv2,b_conv2,9,SHIFT_CONV2,0,conv2,0);t[3]=cycles();
        in_qbase=0;out_qbase=4096;weight_base=1336;weight_stride=8;
        if(!job_error)layer(conv2,1044,1,1044,w_fc1,b_fc1,32,SHIFT_FC1,1,fc1,0);t[4]=cycles();
        in_qbase=4096;weight_base=9688;weight_stride=1;
        if(!job_error)layer(fc1,32,1,32,w_fc2,b_fc2,2,0,0,0,logits);t[5]=cycles();
        MB(0x90)=id;
        if(job_error){MB(0x8c)=job_error;MB(0x88)=2;while(1){} /* host resets after device failure */}
        MB(0x40)=(uint32_t)logits[0];MB(0x44)=(uint32_t)logits[1];MB(0x50)=t[5]-t[0];
        for(uint32_t i=0;i<5;++i)MB(0xc0+i*4)=t[i+1]-t[i];
        MB(0x88)=1;
        while(MB(8)&8u){} // wait until host ACK before polling the next request
    }
}
__asm__(".section .text.start\n.global _start\n_start:\nli sp,131072\ncall main\n1:j 1b\n");
