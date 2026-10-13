`default_nettype none
module uart_rx_slot (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire rx_pause_next,
  input wire rx_push,
  input wire rx_pop,
  input wire [7:0] rx_word,
  input wire rx_parity_bad_next,
  input wire rx_frame_bad_next,
  output reg [7:0] slot_data,
  output reg slot_valid,
  output reg slot_parity_bad,
  output reg slot_frame_bad,
  output reg rts_n
);
  wire slot_valid_next;
  wire store_word;
  assign store_word=rx_push && (!slot_valid || rx_pop);
  assign slot_valid_next=store_word || (slot_valid && !rx_pop);
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin
      slot_data<=0; slot_valid<=0; slot_parity_bad<=0; slot_frame_bad<=0; rts_n<=1;
    end else begin
      slot_valid<=slot_valid_next;
      rts_n<=!sync_ready || rx_pause_next || slot_valid_next;
      if (store_word) begin
        slot_data<=rx_word; slot_parity_bad<=rx_parity_bad_next; slot_frame_bad<=rx_frame_bad_next;
      end else if (rx_pop) begin slot_data<=0; slot_parity_bad<=0; slot_frame_bad<=0; end
    end
endmodule

`default_nettype wire
