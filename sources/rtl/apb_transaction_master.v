`default_nettype none
module apb_transaction_master (
  input wire clk,
  input wire reset_n,
  input wire req_valid,
  input wire req_write,
  input wire [11:0] req_addr,
  input wire [31:0] req_wdata,
  input wire [3:0] req_strb,
  output wire req_ready,
  output wire done,
  output reg response_error,
  output reg [31:0] response_data,
  output wire psel,
  output wire penable,
  output reg pwrite,
  output reg [11:0] paddr,
  output reg [31:0] pwdata,
  output reg [3:0] pstrb,
  input wire [31:0] prdata,
  input wire pready,
  input wire pslverr
);
  localparam [1:0] IDLE=2'd0,
    SETUP=2'd1,
    ACCESS=2'd2,
    DONE=2'd3;
  reg [1:0] state;
  assign req_ready=reset_n && state==IDLE;
  assign done=reset_n && state==DONE;
  assign psel=reset_n && (state==SETUP || state==ACCESS);
  assign penable=reset_n && state==ACCESS;
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      state<=IDLE; pwrite<=0; paddr<=0; pwdata<=0; pstrb<=0;
      response_error<=0; response_data<=0;
    end else case (state)
      IDLE: if (req_valid) begin
        pwrite<=req_write; paddr<=req_addr; pwdata<=req_wdata;
        pstrb<=req_write ? req_strb : 4'b0; state<=SETUP;
      end
      SETUP: state<=ACCESS;
      ACCESS: if (pready) begin response_data<=prdata; response_error<=pslverr; state<=DONE; end
      DONE: state<=IDLE;
      default: state<=IDLE;
    endcase
endmodule

`default_nettype wire
