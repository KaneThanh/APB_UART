`default_nettype none
module uart_apb_top #(
  parameter integer CLK_FREQ=50000000,
  parameter integer BAUDRATE=115200,
  parameter integer OVERSAMPLE=16,
  parameter [0:0] RUNTIME_BAUD_EN=0
) (
  input wire clk,
  input wire reset_n,
  input wire psel,
  input wire penable,
  input wire pwrite,
  input wire [3:0] pstrb,
  input wire [11:0] paddr,
  input wire [31:0] pwdata,
  input wire rx,
  input wire cts_n,
  output wire [31:0] prdata,
  output wire pready,
  output wire pslverr,
  output wire tx,
  output wire rts_n
);
  `include "uart_functions.vh"
  wire rst_n_int;
  wire sync_ready;
  wire rx_sync;
  wire cts_n_sync;
  wire rx_fall;
  wire tx_busy;
  wire rx_busy;
  wire access_error;
  wire wr_fire;
  wire rd_fire;
  wire tx_accept;
  wire rx_pop;
  wire rx_pause_next;
  wire [7:0] tx_data_stage;
  wire [7:0] slot_data;
  wire [7:0] rx_word;
  wire [4:0] cfg_active;
  wire [17:0] baud_active;
  wire slot_valid;
  wire slot_parity_bad;
  wire slot_frame_bad;
  wire rx_push;
  wire rx_parity_bad_next;
  wire rx_frame_bad_next;
  reset_sync u_reset (
    .clk(clk),
    .async_reset_n(reset_n),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready)
  );
  uart_sync u_sync (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .rx(rx),
    .cts_n(cts_n),
    .rx_sync(rx_sync),
    .cts_n_sync(cts_n_sync),
    .rx_fall(rx_fall)
  );
  uart_apb_slave u_apb (
    .rst_n_int(rst_n_int),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .access_error(access_error),
    .pready(pready),
    .pslverr(pslverr),
    .wr_fire(wr_fire),
    .rd_fire(rd_fire)
  );
  uart_regs #(.BAUDRATE(BAUDRATE),.RUNTIME_BAUD_EN(RUNTIME_BAUD_EN)) u_regs (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .pstrb(pstrb),
    .wr_fire(wr_fire),
    .rd_fire(rd_fire),
    .tx_busy(tx_busy),
    .rx_busy(rx_busy),
    .rx_sync(rx_sync),
    .cts_n_sync(cts_n_sync),
    .rts_n(rts_n),
    .slot_data(slot_data),
    .slot_valid(slot_valid),
    .slot_parity_bad(slot_parity_bad),
    .slot_frame_bad(slot_frame_bad),
    .access_error(access_error),
    .prdata(prdata),
    .tx_data_stage(tx_data_stage),
    .cfg_active(cfg_active),
    .baud_active(baud_active),
    .tx_accept(tx_accept),
    .rx_pop(rx_pop),
    .rx_pause_next(rx_pause_next)
  );
  uart_tx #(.CLK_FREQ(CLK_FREQ)) u_tx (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .tx_accept(tx_accept),
    .cts_n_sync(cts_n_sync),
    .tx_data_stage(tx_data_stage),
    .cfg_active(cfg_active),
    .baud_active(baud_active),
    .tx(tx),
    .tx_busy(tx_busy)
  );
  uart_rx #(.CLK_FREQ(CLK_FREQ)) u_rx (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .rx_sync(rx_sync),
    .rx_fall(rx_fall),
    .cfg_active(cfg_active),
    .baud_active(baud_active),
    .rx_word(rx_word),
    .rx_push(rx_push),
    .rx_busy(rx_busy),
    .rx_parity_bad_next(rx_parity_bad_next),
    .rx_frame_bad_next(rx_frame_bad_next)
  );
  uart_rx_slot u_slot (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .rx_pause_next(rx_pause_next),
    .rx_push(rx_push),
    .rx_pop(rx_pop),
    .rx_word(rx_word),
    .rx_parity_bad_next(rx_parity_bad_next),
    .rx_frame_bad_next(rx_frame_bad_next),
    .slot_data(slot_data),
    .slot_valid(slot_valid),
    .slot_parity_bad(slot_parity_bad),
    .slot_frame_bad(slot_frame_bad),
    .rts_n(rts_n)
  );
endmodule

`default_nettype wire
