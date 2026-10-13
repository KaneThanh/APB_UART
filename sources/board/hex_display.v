`default_nettype none
module hex_display (
  input wire clk,
  input wire reset_n,
  input wire [3:0] active_baud_index,
  input wire error,
  input wire pending,
  output reg [6:0] HEX0,
  output reg [6:0] HEX1,
  output reg [6:0] HEX2,
  output reg [6:0] HEX3,
  output reg [6:0] HEX4,
  output reg [6:0] HEX5,
  output reg [1:0] LED
);
  function [6:0] seven;
    input [3:0] digit;
    begin
    case (digit)
      0: seven=7'b1000000; 1: seven=7'b1111001; 2: seven=7'b0100100;
      3: seven=7'b0110000; 4: seven=7'b0011001; 5: seven=7'b0010010;
      6: seven=7'b0000010; 7: seven=7'b1111000; 8: seven=7'b0000000;
      9: seven=7'b0010000; default: seven=7'b1111111;
    endcase
    end
  endfunction
  reg [23:0] bcd;
  always @* begin
    case (active_baud_index)
      0: bcd=24'h002400; 1: bcd=24'h004800; 2: bcd=24'h009600;
      3: bcd=24'h019200; 4: bcd=24'h038400; 5: bcd=24'h057600;
      6: bcd=24'h076800; 7: bcd=24'h115200; 8: bcd=24'h230400;
      default: bcd=24'hffffff;
    endcase
  end
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin HEX0<=127; HEX1<=127; HEX2<=127; HEX3<=127; HEX4<=127; HEX5<=127; LED<=0; end
    else begin
      HEX0<=seven(bcd[3:0]); HEX1<=seven(bcd[7:4]); HEX2<=seven(bcd[11:8]);
      HEX3<=seven(bcd[15:12]); HEX4<=seven(bcd[19:16]); HEX5<=seven(bcd[23:20]);
      LED<={error,pending};
    end
endmodule

`default_nettype wire
