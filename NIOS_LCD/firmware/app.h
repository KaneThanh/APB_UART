#ifndef UART_APP_H
#define UART_APP_H
#include <stdint.h>
uint32_t hw_read(uint32_t offset);
void hw_write(uint32_t offset, uint32_t value);
void app_init(void);
void app_step(void);
#endif
