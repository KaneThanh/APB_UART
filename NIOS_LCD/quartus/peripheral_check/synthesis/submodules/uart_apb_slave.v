`default_nettype none
module uart_apb_slave (
  input wire rst_n_int,
  input wire psel,
  input wire penable,
  input wire pwrite,
  input wire access_error,
  output wire pready,
  output wire pslverr,
  output wire wr_fire,
  output wire rd_fire
);
  assign pready=rst_n_int && psel && penable;
  assign pslverr=pready && access_error;
  assign wr_fire=pready && pwrite && !access_error;
  assign rd_fire=pready && !pwrite && !access_error;
endmodule

`default_nettype wire
