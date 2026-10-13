`timescale 1ns/1ps
module tb_lcd;
  reg clk=0; always #500 clk=~clk;
  reg reset_n=0, wr=0;
  reg [4:0] index=0;
  reg [7:0] data=8'h41;
  wire [7:0] lcd_data;
  wire lcd_rs,lcd_rw,lcd_en,lcd_on,lcd_blon;
  integer n=0;
  time rise_time;
  reg [7:0] expected[0:7];
  lcd_text #(.CLK_HZ(1000000)) dut(.*);
  always @(posedge lcd_en) rise_time=$time;
  always @(negedge lcd_en) if(reset_n) begin
    if($time-rise_time<1000) $fatal(1,"LCD pulse too short");
    if(n<8) begin
      if(lcd_rs || lcd_data!=expected[n]) $fatal(1,"LCD init sequence %d",n);
    end else if(n==8 && (lcd_rs||lcd_data!=8'h80)) $fatal(1,"row1 address");
    else if(n==9 && (!lcd_rs||lcd_data!=8'h41)) $fatal(1,"row1 data");
    else if(n==25 && (lcd_rs||lcd_data!=8'hc0)) $fatal(1,"row2 address");
    else if(n==26 && (!lcd_rs||lcd_data!=8'h20)) $fatal(1,"row2 blank");
    if(lcd_rw || !lcd_on || lcd_blon) $fatal(1,"LCD control");
    n=n+1;
    if(n==42) begin $display("PASS LCD: power-up init, EN width, both row addresses and character data"); $finish; end
  end
  initial begin
    expected[0]=8'h30;expected[1]=8'h30;expected[2]=8'h30;expected[3]=8'h38;
    expected[4]=8'h08;expected[5]=8'h01;expected[6]=8'h06;expected[7]=8'h0c;
    repeat(3) @(negedge clk); reset_n=1; wr=1;
    @(negedge clk); wr=0;
  end
  initial begin #400000000; $fatal(1,"LCD timeout"); end
endmodule
