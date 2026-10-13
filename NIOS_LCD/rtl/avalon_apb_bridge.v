module avalon_apb_bridge (
  input wire clk, reset_n,
  input wire [11:0] address,
  input wire read, write,
  input wire [31:0] writedata,
  input wire [3:0] byteenable,
  output wire waitrequest,
  output reg [31:0] readdata,
  output reg error_pulse,
  output wire psel, penable,
  output reg pwrite,
  output reg [11:0] paddr,
  output reg [31:0] pwdata,
  output reg [3:0] pstrb,
  input wire [31:0] prdata,
  input wire pready, pslverr
);
  localparam IDLE=0, SETUP=1, ACCESS=2, DONE=3;
  reg [1:0] state;
  assign waitrequest=(state!=DONE);
  assign psel=(state==SETUP || state==ACCESS);
  assign penable=(state==ACCESS);
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      state<=IDLE; readdata<=0; error_pulse<=0;
      paddr<=0; pwrite<=0; pwdata<=0; pstrb<=0;
    end else begin
      error_pulse<=0;
      case (state)
        IDLE: if (read || write) begin
          paddr<=address; pwrite<=write; pwdata<=writedata;
          pstrb<=byteenable; state<=SETUP;
        end
        SETUP: state<=ACCESS;
        ACCESS: if (pready) begin
          readdata<=prdata; error_pulse<=pslverr; state<=DONE;
        end
        DONE: state<=IDLE;
      endcase
    end
endmodule
