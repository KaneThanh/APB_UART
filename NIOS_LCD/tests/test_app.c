#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../firmware/app.h"
static unsigned ms, input, cfg, baud, flow, errors, valid, parity_bad, frame_bad;
static unsigned busy, cts, data, stage, starts, pops, led;
static unsigned char sent[4096], screen[32];
uint32_t hw_read(uint32_t a) {
    switch(a) {
    case 4: valid=0; ++pops; return data;
    case 8: return cfg;
    case 16: return (!busy) | (valid<<1) | (parity_bad<<2);
    case 20: return busy | (frame_bad<<2) | (cts<<3) | ((flow||valid)<<4)
                   | (valid<<5) | ((!busy&&!valid)<<6) | 128;
    case 28: return baud;
    case 0x1100: return input;
    case 0x1104: return ms;
    case 0x110c: return errors;
    default: return 0;
    }
}
void hw_write(uint32_t a,uint32_t v) {
    switch(a) {
    case 0: stage=v; break;
    case 8: assert(!valid&&!busy); cfg=v; break;
    case 12: assert(!busy); assert(starts<sizeof(sent)); sent[starts++]=(unsigned char)stage; busy=1; break;
    case 28: assert(!valid&&!busy); baud=v; break;
    case 32: flow=v; break;
    case 0x1108: led=v; break;
    default: if(a>=0x1000 && a<0x1080) screen[(a-0x1000)/4]=(unsigned char)v;
    }
}
static void step(void) { app_step(); }
static void tick(unsigned n) { unsigned i; for(i=0;i<n;++i) { ++ms; step(); } }
static void switches(unsigned v) { input=(input&0x700)|v; tick(21); }
static void key(unsigned k) { input&=~(1u<<k); tick(21); input|=1u<<k; tick(21); }
static void send_byte(unsigned b,unsigned p,unsigned f) {
    assert(!valid); data=b; parity_bad=p; frame_bad=f; valid=1; step();
}
static void finish_tx(void) { busy=0; step(); }
static void reset_app(void) {
    ms=cfg=baud=flow=errors=valid=parity_bad=frame_bad=busy=cts=starts=pops=led=0;
    input=0x700; memset(screen,0,sizeof(screen)); app_init(); step();
    assert(cfg==3&&baud==7&&flow==0);
}
int main(void) {
    unsigned i, before;
    reset_app();
    send_byte('A',0,0); assert(starts==1&&sent[0]=='A'&&pops==1); finish_tx();
    send_byte('B',1,0); send_byte('C',0,1); assert(starts==1&&pops==3);
    reset_app();
    for(i=0;i<20;++i) { send_byte('a'+i,0,0); finish_tx(); }
    tick(100); assert(memcmp(screen,"abcdefghijklmnop",16)==0); assert(starts==20);
    send_byte('\r',0,0); finish_tx(); send_byte('\n',0,0); finish_tx();
    send_byte('Z',0,0); finish_tx(); tick(100); assert(screen[0]=='Z'&&screen[1]==' ');
    tick(500); send_byte('Q',0,0); finish_tx(); tick(100); assert(screen[0]=='Q');
    switches(32); tick(100); assert(screen[16]=='E');
    before=starts; switches(32|64);
    while(busy) finish_tx();
    assert(starts==before+16); assert(sent[before+2]=='E');
    tick(100); assert(starts==before+16);
    switches(128); tick(100); assert(screen[0]==' ');
    reset_app(); busy=1; cts=1;
    for(i=0;i<384;++i) send_byte('x',0,0);
    assert(flow==1); cts=0;
    for(i=0;i<260;++i) finish_tx();
    assert(flow==0);
    reset_app(); switches(7); key(9); assert(cfg==11&&flow==1);
    key(10); assert(flow==0);
    reset_app(); busy=1; cts=1; switches(7); key(9); key(10);
    assert(cfg==3&&flow==1); busy=0; cts=0; step(); assert(cfg==11&&flow==0);
    reset_app(); busy=1; cts=1; switches(7); key(9); tick(2100);
    assert(cfg==3&&flow==0); assert(led&2);
    puts("PASS firmware: boot, echo, bad metadata drop, LCD truncation/CRLF/gap, register selection, single report per edge, clear, backpressure, apply/resume and timeout");
    return 0;
}
