`default_nettype none
module uart_sync (
  input wire clk,
  input wire rst_n_int,
  input wire rx,
  input wire cts_n,
  output wire rx_sync,
  output wire cts_n_sync,
  output wire rx_fall
);
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
  reg [1:0] rx_ff, cts_ff;
  reg rx_prev;
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin rx_ff<=2'b11; cts_ff<=2'b11; rx_prev<=1; end
    else begin rx_ff<={rx_ff[0],rx}; cts_ff<={cts_ff[0],cts_n}; rx_prev<=rx_sync; end
  assign rx_sync=rx_ff[1];
  assign cts_n_sync=cts_ff[1];
  assign rx_fall=rx_prev && !rx_sync;
endmodule

`default_nettype wire
