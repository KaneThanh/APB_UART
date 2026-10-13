module tb_peripheral;
  reg clk=0; always #10 clk=~clk;
  reg reset_n=0, read=0, write=0, rx=1, cts_n=0;
  reg [12:0] address=0;
  reg [31:0] writedata=0;
  reg [3:0] byteenable=15;
  reg [7:0] switches=0;
  reg [2:0] keys_n=7;
  wire [31:0] readdata;
  wire waitrequest,tx,rts_n,lcd_rs,lcd_rw,lcd_en,lcd_on,lcd_blon;
  wire [1:0] leds;
  wire [7:0] lcd_data;
  reg [31:0] got;
  uart_cpu_peripheral dut(.*);
  task bus(input bit wr,input [12:0] a,input [31:0] d);
    begin
      @(negedge clk); address=a; read=!wr; write=wr; writedata=d;
      @(posedge clk);
      while(waitrequest) @(posedge clk);
      got=readdata;
      @(negedge clk); read=0;write=0;
    end
  endtask
  initial begin
    repeat(4) @(negedge clk); reset_n=1;
    repeat(8) @(negedge clk);
    bus(0,13'h1110,0); if(got!=32'h4e494f31) $fatal(1,"ID");
    bus(1,8,3); bus(0,8,0); if(got!=3) $fatal(1,"CFG bridge");
    bus(1,13'h018,0); bus(0,13'h110c,0); if(got!=1) $fatal(1,"APB error counter");
    bus(1,13'h1000,8'h41); if(dut.lcd.text_mem[0]!=8'h41) $fatal(1,"LCD offset");
    bus(1,13'h107c,8'h5a); if(dut.lcd.text_mem[31]!=8'h5a) $fatal(1,"LCD last char");
    switches=8'ha5; repeat(4) @(negedge clk);
    bus(0,13'h1100,0); if(got!=32'h7a5) $fatal(1,"switch sync");
    bus(1,13'h1108,3); if(leds!=3) $fatal(1,"LED");
    bus(1,0,8'h55); bus(1,12,1);
    bus(0,16,0); if(got[0]) $fatal(1,"TX not started");
    repeat(5000) @(negedge clk);
    bus(0,16,0); if(!got[0]) $fatal(1,"TX not finished");
    $display("PASS peripheral: real UART APB configuration, bus error, LCD register addressing, IO sync and TX completion"); $finish;
  end
  initial begin #2000000; $fatal(1,"timeout"); end
endmodule
