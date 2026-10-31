// Included after the original, independently retained run_inference function.
#define M30_REG(offset) (*(volatile uint32_t *)(ACCEL_BASE+(offset)))
#define M30_CONTROL M30_REG(0x0100u)
#define M30_STATUS M30_REG(0x0104u)
#define M30_BANK M30_REG(0x00c4u)
#define M30_PROGRAM ((volatile uint32_t *)(ACCEL_BASE+0x0800u))
static uint32_t m30_count;
static void m30_append(uint32_t address, uint32_t value)
{
    if (m30_count>=128u) report_and_halt(0xdead4000u);
    M30_PROGRAM[m30_count*2u]=address;
    M30_PROGRAM[m30_count*2u+1u]=value;
    ++m30_count;
}
static void m30_conv(uint32_t bank, uint32_t m, uint32_t n, uint32_t k,
    uint32_t kernel, uint32_t padding, uint32_t length, uint32_t output_length,
    uint32_t input, uint32_t output, uint32_t weights, uint32_t pool)
{
    m30_append(0x0000u,2u); m30_append(0x00c4u,bank);
    m30_append(0x0008u,16u); m30_append(0x000cu,16u); m30_append(0x0010u,k);
    m30_append(0x0020u,0u); m30_append(0x0058u,0u);
    m30_append(0x005cu,length); m30_append(0x0060u,kernel);
    m30_append(0x0064u,padding); m30_append(0x0068u,input); m30_append(0x006cu,0u);
    m30_append(0x0078u,weights>>2); m30_append(0x007cu,n>>2);
    m30_append(0x0024u,2u); m30_append(0x002cu,16u); m30_append(0x0030u,16u);
    m30_append(0x0034u,pool); m30_append(0x0040u,output_length);
    m30_append(0x0038u,0u); m30_append(0x003cu,output);
    m30_append(0x00acu,m); m30_append(0x00b0u,n);
    m30_append(0x00a4u,3u); m30_append(0x100a8u,2u);
}
static uint32_t m30_initialize(void)
{
    uint32_t start=read_cycles();
    M30_BANK=0; load_parameters_raw(conv1_bias,conv1_shift,32u);
    M30_BANK=1; load_parameters_raw(conv2_bias,conv2_shift,64u);
    M30_BANK=2; load_parameters_raw(conv3_bias,conv3_shift,64u);
    m30_count=0;
    m30_append(0x0098u,1u);
    m30_conv(0,128,32,14,7,3,128,64,0,4096,WEIGHT_CONV1_BASE,1);
    m30_conv(1,64,64,160,5,2,64,32,4096,0,WEIGHT_CONV2_BASE,1);
    m30_append(0x0088u,4096u); m30_append(0x008cu,0u);
    m30_append(0x0090u,5u); m30_append(0x0094u,64u); m30_append(0x0080u,3u);
    m30_conv(2,32,64,192,3,1,32,32,0,4096,WEIGHT_CONV3_BASE,0);
    m30_append(0x0080u,5u); m30_append(0x10084u,2u);
    m30_append(0x0000u,2u); m30_append(0x0008u,1u); m30_append(0x000cu,4u);
    m30_append(0x0010u,64u); m30_append(0x0020u,0u);
    m30_append(0x0058u,0u); m30_append(0x005cu,1u); m30_append(0x0060u,1u);
    m30_append(0x0064u,0u); m30_append(0x0068u,0u); m30_append(0x006cu,0u);
    m30_append(0x0050u,2u); m30_append(0x0050u,1u); m30_append(0x10054u,2u);
    m30_append(0x0078u,WEIGHT_CLASSIFIER_BASE>>2); m30_append(0x007cu,1u);
    m30_append(0x0000u,1u); m30_append(0x10004u,2u);
    M30_REG(0x0108u)=m30_count;
    if (m30_count!=101u) report_and_halt(0xdead4001u);
    return read_cycles()-start;
}
static __attribute__((noinline)) uint32_t m30_inference(void)
{
    uint32_t i,status,timeout=100000u;
    uint32_t start=read_cycles();
    for(i=0;i<64u;++i) ACCEL_Q[i]=network_input_words[i];
    M30_CONTROL=3u;
    do {
        status=M30_STATUS;
        if(timeout--==0) report_and_halt(0xdead4100u);
    } while(!(status&2u));
    if(status&5u) report_and_halt(0xdead4101u);
    for(i=0;i<4u;++i) benchmark_logits[i]=ACCEL_C[i]+classifier_bias[i];
    uint32_t inference_cycles=read_cycles()-start;

    return inference_cycles;
}
