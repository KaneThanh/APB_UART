`default_nettype none
module de2_115_uart_top #(
  parameter integer CLK_FREQ=50000000,
  parameter integer BAUDRATE=115200,
  parameter integer DEBOUNCE_CYCLES=CLK_FREQ/100
) (
  input wire CLOCK_50,
  input wire [3:0] KEY,
  input wire [4:0] SW,
  input wire UART_RXD,
  input wire UART_RTS,
  output wire UART_TXD,
  output wire UART_CTS,
  output wire [6:0] HEX0,
  output wire [6:0] HEX1,
  output wire [6:0] HEX2,
  output wire [6:0] HEX3,
  output wire [6:0] HEX4,
  output wire [6:0] HEX5,
  output wire [1:0] LED
);
  wire clk;
  wire reset_n;
  wire board_ready;
  wire [4:0] pending_cfg;
  wire [3:0] pending_baud_index;
  wire [3:0] active_baud_index;
  wire apply_req;
  wire resume_req;
  wire error;
  wire pending;
  wire psel;
  wire penable;
  wire pwrite;
  wire pready;
  wire pslverr;
  wire [11:0] paddr;
  wire [31:0] pwdata;
  wire [31:0] prdata;
  wire [3:0] pstrb;
  assign clk=CLOCK_50;
  reset_sync u_board_reset (
    .clk(clk),
    .async_reset_n(KEY[0]),
    .rst_n_int(reset_n),
    .sync_ready(board_ready)
  );
  board_controls #(.CLK_FREQ(CLK_FREQ),.BAUDRATE(BAUDRATE),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_controls (
    .clk(clk),
    .reset_n(reset_n),
    .KEY(KEY),
    .SW(SW),
    .pending_baud_index(pending_baud_index),
    .pending_cfg(pending_cfg),
    .apply_req(apply_req),
    .resume_req(resume_req)
  );
  apb_echo_master u_master (
    .clk(clk),
    .reset_n(reset_n),
    .pending_cfg(pending_cfg),
    .pending_baud_index(pending_baud_index),
    .apply_req(apply_req),
    .resume_req(resume_req),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .pstrb(pstrb),
    .active_baud_index(active_baud_index),
    .error(error),
    .pending(pending)
  );
  uart_apb_top #(.CLK_FREQ(CLK_FREQ),.BAUDRATE(BAUDRATE),.RUNTIME_BAUD_EN(1)) u_uart (
    .clk(clk),
    .reset_n(reset_n),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .pstrb(pstrb),
    .paddr(paddr),
    .pwdata(pwdata),
    .rx(UART_RXD),
    .cts_n(UART_RTS),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    .tx(UART_TXD),
    .rts_n(UART_CTS)
  );
  hex_display u_display (
    .clk(clk),
    .reset_n(reset_n),
    .active_baud_index(active_baud_index),
    .error(error),
    .pending(pending),
    .HEX0(HEX0),
    .HEX1(HEX1),
    .HEX2(HEX2),
    .HEX3(HEX3),
    .HEX4(HEX4),
    .HEX5(HEX5),
    .LED(LED)
  );
endmodule

`default_nettype wire
