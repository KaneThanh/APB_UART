#include "app.h"
#define PERIPHERAL_BASE 0x00020000u
uint32_t hw_read(uint32_t offset) {
    uint32_t value;
    uintptr_t address=PERIPHERAL_BASE+offset;
    __asm__ volatile ("ldwio %0, 0(%1)" : "=r"(value) : "r"(address) : "memory");
    return value;
}
void hw_write(uint32_t offset,uint32_t value) {
    uintptr_t address=PERIPHERAL_BASE+offset;
    __asm__ volatile ("stwio %0, 0(%1)" :: "r"(value), "r"(address) : "memory");
}
int main(void) {
    app_init();
    for (;;) app_step();
}
