#include "app.h"

enum { TX=0, RX=4, CFG=8, START=12, STATUS=16, EXT=20,
       BAUD=28, FLOW=32, LCD=0x1000, INPUT=0x1100,
       MS=0x1104, LED=0x1108, BUS_ERRORS=0x110c };
enum { QSIZE=512, QMASK=511 };
static uint8_t queue[QSIZE];
static unsigned head, tail, count;
static char line[16];
static unsigned used;
static uint32_t last_rx, last_ui, candidate_since, stable_io, candidate_io;
static uint32_t apply_since, stalled_since;
static unsigned pending_baud, selected_cfg, selected_baud, cfg_state;
static unsigned resume_queued, fault, throttled, fresh_line, booting;
static unsigned stalled;

static uint32_t elapsed(uint32_t now, uint32_t then) { return now-then; }
static void enqueue(uint8_t b) {
    queue[head]=b; head=(head+1)&QMASK; ++count;
}
static void clear_line(void) {
    unsigned i;
    for (i=0;i<16;++i) line[i]=' ';
    used=0; fresh_line=0;
}
static void received(uint8_t b, uint32_t now) {
    if (b=='\r' || b=='\n') { fresh_line=1; last_rx=now; return; }
    if (fresh_line || elapsed(now,last_rx)>=500) clear_line();
    if (used<16) line[used++]=(b>=32 && b<=126) ? (char)b : '.';
    last_rx=now;
}
static char hex_digit(unsigned n) { return "0123456789ABCDEF"[n&15]; }
static void hex8(char *dst,uint32_t value) {
    unsigned i;
    for (i=0;i<8;++i) dst[i]=hex_digit(value>>(28-4*i));
}
static void show(uint32_t now) {
    char row[16]; unsigned i; int ext=(stable_io & (1u<<5))!=0;
    uint32_t value=hw_read(ext ? EXT : STATUS);
    for (i=0;i<16;++i) row[i]=' ';
    row[0]=ext?'E':'S'; row[1]=':'; hex8(row+2,value);
    row[11]='B'; row[12]=(char)('0'+pending_baud);
    row[14]=cfg_state?'P':'R'; row[15]=fault?'!':' ';
    for (i=0;i<16;++i) {
        hw_write(LCD+4*i,(uint8_t)line[i]);
        hw_write(LCD+4*(i+16),(uint8_t)row[i]);
    }
    hw_write(LED,(cfg_state || booting ? 1u:0u) | (fault ? 2u:0u));
    last_ui=now;
}
static void report(void) {
    char message[16]; unsigned i;
    unsigned ext=(stable_io>>5)&1;
    /* Text reports require eight data bits; binary echo works with 5..8. */
    if ((hw_read(CFG)&3)!=3 || count>QSIZE-16) { fault=1; return; }
    message[0]='\r'; message[1]='\n'; message[2]=ext?'E':'S';
    message[3]=':'; message[4]='0'; message[5]='x';
    hex8(message+6,hw_read(ext?EXT:STATUS));
    message[14]='\r'; message[15]='\n';
    for (i=0;i<16;++i) enqueue((uint8_t)message[i]);
}
static void controls(uint32_t now) {
    uint32_t raw=hw_read(INPUT)&0x7ff, previous, rise, pressed;
    if (raw!=candidate_io) { candidate_io=raw; candidate_since=now; }
    if (raw==stable_io || elapsed(now,candidate_since)<20) return;
    previous=stable_io; stable_io=raw;
    rise=raw & ~previous; pressed=previous & ~raw;
    if (rise & (1u<<7)) clear_line();
    if (rise & (1u<<6)) report();
    if ((pressed & (1u<<8)) && !cfg_state) pending_baud=(pending_baud+1)%9;
    if ((pressed & (1u<<9)) && !cfg_state) {
        selected_cfg=(raw&3) | ((raw&(1u<<4))>>2)
                     | ((raw&(1u<<2))<<1) | ((raw&(1u<<3))<<1);
        selected_baud=pending_baud;
        cfg_state=1; apply_since=now; resume_queued=0;
        hw_write(FLOW,1);
    }
    if (pressed & (1u<<10)) { if (cfg_state) resume_queued=1; }
}
void app_init(void) {
    head=tail=count=used=0;
    cfg_state=resume_queued=fault=throttled=stalled=0;
    booting=1; pending_baud=7; fresh_line=1;
    last_rx=last_ui=candidate_since=hw_read(MS);
    stable_io=candidate_io=hw_read(INPUT)&0x7ff;
    clear_line();
    hw_write(FLOW,1);
}
void app_step(void) {
    uint32_t now=hw_read(MS), status, ext, b;
    if (booting) {
        ext=hw_read(EXT);
        if (ext&(1u<<5)) (void)hw_read(RX);
        else if (ext&(1u<<6)) {
            hw_write(CFG,3); hw_write(BAUD,7);
            if (hw_read(CFG)!=3 || hw_read(BAUD)!=7) { fault=1; }
            else { booting=0; hw_write(FLOW,0); }
        }
        if (elapsed(now,last_ui)>=100) show(now);
        return;
    }
    controls(now);
    status=hw_read(STATUS);
    if ((status&2) && count<QSIZE) {
        ext=hw_read(EXT);
        b=hw_read(RX);
        if ((status&4) || (ext&4)) fault=1;
        else { enqueue((uint8_t)b); received((uint8_t)b,now); }
    }
    if (count && (hw_read(STATUS)&1)) {
        hw_write(TX,queue[tail]); hw_write(START,1);
        tail=(tail+1)&QMASK; --count;
    }
    if (count>=384) throttled=1;
    else if (count<=128) throttled=0;
    if (cfg_state==1) {
        ext=hw_read(EXT);
        if (!count && (ext&(1u<<6))) {
            hw_write(CFG,selected_cfg); hw_write(BAUD,selected_baud);
            if (hw_read(CFG)!=selected_cfg || hw_read(BAUD)!=selected_baud) fault=1;
            cfg_state=2;
        } else if (elapsed(now,apply_since)>=2000) {
            fault=1; cfg_state=0; resume_queued=0;
        }
    }
    if (cfg_state==2 && resume_queued) { cfg_state=0; resume_queued=0; }
    hw_write(FLOW,(cfg_state || throttled)?1:0);
    ext=hw_read(EXT);
    if ((ext&1) && (ext&8)) {
        if (!stalled) { stalled=1; stalled_since=now; }
        else if (elapsed(now,stalled_since)>=2000) fault=1;
    } else stalled=0;
    if (hw_read(BUS_ERRORS)) fault=1;
    if (elapsed(now,last_ui)>=100) show(now);
}
