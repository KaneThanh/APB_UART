`default_nettype none
module reset_sync (
  input wire clk,
  input wire async_reset_n,
  output wire rst_n_int,
  output wire sync_ready
);
  (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
  reg [1:0] release_ff;
  reg [2:0] startup;
  always @(posedge clk or negedge async_reset_n)
    if (!async_reset_n) release_ff <= 0;
    else release_ff <= {release_ff[0],1'b1};
  assign rst_n_int=release_ff[1];
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) startup <= 0;
    else startup <= {startup[1:0],1'b1};
  assign sync_ready=startup[2];
endmodule

`default_nettype wire
