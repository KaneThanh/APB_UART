`timescale 1ns/1ps
module parameter_case #(parameter integer INDEX=0, RATE=2400) (output logic finished=0);
  logic clk=0; always #10 clk=~clk;
  logic reset_n=0,psel=0,penable=0,pwrite=0,rx=1,cts_n=0;
  logic [3:0] pstrb=0;
  logic [11:0] paddr=0;
  logic [31:0] pwdata=0,prdata,value;
  logic pready,pslverr,tx,rts_n;
  real period;
  uart_apb_top #(.BAUDRATE(RATE)) dut (.*);
  task automatic bus(input bit wr,input logic[11:0] addr,input logic[31:0] data,input logic[3:0] strb,input bit err);
    @(negedge clk); psel=1; penable=0; pwrite=wr; paddr=addr; pwdata=data; pstrb=strb;
    @(negedge clk); penable=1; @(posedge clk);
    if(pready!==1 || pslverr!==err) $fatal(1,"Parameter APB response index=%0d",INDEX);
    value=prdata; @(negedge clk); psel=0;penable=0;
  endtask
  task automatic receive_tx;
    logic [7:0] got;
    @(negedge tx); #(period*1.5);
    for(int k=0;k<8;k++) begin got[k]=tx; #(period); end
    if(got!='h96 || tx!==1) $fatal(1,"Parameter TX baud=%0d",RATE);
    #(period);
  endtask
  task automatic send_rx;
    logic [7:0] data; data='h69;
    #127; rx=0; #(period);
    for(int k=0;k<8;k++) begin rx=data[k]; #(period); end
    rx=1; #(period);
  endtask
  initial begin
    period=1.0e9/RATE;
    #100; reset_n=1; repeat(10) @(negedge clk);
    bus(0,'h01c,0,0,0); if(value!=INDEX) $fatal(1,"Parameter baud index");
    bus(0,'h014,0,0,0); if(value[7]) $fatal(1,"Runtime capability must be zero");
    bus(1,'h01c,(INDEX+1)%9,1,1); // Disabled runtime writes reject even when idle.
    bus(1,'h01c,15,2,0); // High-byte strobes remain legal no-ops.
    bus(0,'h01c,0,0,0); if(value!=INDEX) $fatal(1,"Parameter baud changed");
    bus(1,'h008,3,1,0); bus(1,'h000,'h96,1,0);
    fork receive_tx(); send_rx(); bus(1,'h00c,1,1,0); join
    bus(0,'h010,0,0,0); if(value!=3) $fatal(1,"Parameter RX status");
    bus(0,'h004,0,0,0); if(value!='h69) $fatal(1,"Parameter RX data");
    $display("PASS BAUDRATE parameter=%0d runtime disabled",RATE); finished=1;
  end
endmodule
module tb_parameters;
  `include "uart_functions.vh"
  wire [8:0] finished;
  for(genvar i=0;i<9;i++) begin: builds
    parameter_case #(.INDEX(i),.RATE(baud_value(i))) test_case (.finished(finished[i]));
  end
  initial begin wait(&finished); $display("PASS tb_parameters: 9 parameter builds TX/RX"); $finish; end
  initial begin #10000000; $fatal(1,"Parameter timeout"); end
endmodule
