/* Included after the selected network firmware and the resident CNN functions. */
#define MAILBOX(offset) (*(volatile uint32_t *)(0x30000000u+(offset)))
__attribute__((noreturn,section(".text.start"))) void _start(void) {
    uint32_t i;
    (void)m30_initialize();
    trace_checks=1u;select_input(0u);(void)run_inference();trace_checks=0u;
    MAILBOX(0x80u)=1u;
    for(;;) {
        if((MAILBOX(0x08u)&2u)==0u)continue;
        MAILBOX(0x84u)=1u;
        uint32_t frame=MAILBOX(0x18u);
        for(i=0;i<64u;i++)network_input_words[i]=MAILBOX(0x100u+i*4u);
        uint32_t elapsed=m30_inference();
        for(i=0;i<4u;i++)MAILBOX(0x40u+i*4u)=(uint32_t)benchmark_logits[i];
        MAILBOX(0x50u)=elapsed;MAILBOX(0x90u)=frame;MAILBOX(0x88u)=1u;
    }
}
