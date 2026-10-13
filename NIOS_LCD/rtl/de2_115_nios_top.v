module de2_115_nios_top (
  input wire CLOCK_50,
  input wire [3:0] KEY,
  input wire [7:0] SW,
  input wire UART_RXD, UART_RTS,
  output wire UART_TXD, UART_CTS,
  output wire [1:0] LED,
  output wire [7:0] LCD_DATA,
  output wire LCD_EN, LCD_RS, LCD_RW, LCD_ON, LCD_BLON
);
  nios_uart_system system_cpu (
    .clk_clk(CLOCK_50),.reset_reset_n(KEY[0]),
    .board_rx(UART_RXD),.board_cts_n(UART_RTS),
    .board_tx(UART_TXD),.board_rts_n(UART_CTS),
    .board_switches(SW),.board_keys_n(KEY[3:1]),.board_leds(LED),
    .board_lcd_data(LCD_DATA),.board_lcd_en(LCD_EN),
    .board_lcd_rs(LCD_RS),.board_lcd_rw(LCD_RW),
    .board_lcd_on(LCD_ON),.board_lcd_blon(LCD_BLON)
  );
endmodule
