`timescale 1ns/1ps
module tb_races;
  logic clk=0; always #10 clk=~clk;
  logic reset_n=0,psel=0,penable=0,pwrite=0,rx=1,cts_n=0;
  logic [3:0] pstrb=0;
  logic [11:0] paddr=0;
  logic [31:0] pwdata=0,prdata,value;
  logic pready,pslverr,tx,rts_n;
  integer checks=0;
  localparam real PERIOD=1.0e9/230400;
  uart_apb_top #(.BAUDRATE(230400),.RUNTIME_BAUD_EN(1)) dut (.*);
  task automatic check(input bit ok,input string message);
    checks++; if(!ok) $fatal(1,"%s",message);
  endtask
  task automatic setup(input bit wr,input logic[11:0] addr,input logic[31:0] data);
    @(negedge clk); psel=1;penable=0;pwrite=wr;paddr=addr;pwdata=data;pstrb=wr ? 1 : 0;
  endtask
  task automatic complete(input bit err);
    @(posedge clk); check(pready && pslverr==err,"Race APB response"); value=prdata;
    @(negedge clk); psel=0;penable=0;
  endtask
  task automatic bus(input bit wr,input logic[11:0] addr,input logic[31:0] data);
    setup(wr,addr,data); @(negedge clk);penable=1;complete(0);
  endtask
  task automatic send_word(input logic[7:0] data,input bit bad);
    #127;rx=0;#(PERIOD);
    for(int i=0;i<8;i++) begin rx=data[i];#(PERIOD);end
    rx=!bad;#(PERIOD);rx=1;#(PERIOD/4);
  endtask
  task automatic pop_at_push(input logic[7:0] expected);
    wait(dut.rx_busy); setup(0,'h004,0);
    // Extend SETUP (legal); enter ACCESS exactly when commit enable is high.
    @(negedge clk); while(!dut.rx_push) @(negedge clk);
    penable=1; complete(0);
    check(value=={24'b0,expected},"APB returns pre-edge word on simultaneous push");
  endtask
  initial begin
    #100;reset_n=1;repeat(10) @(negedge clk);bus(1,'h008,3);
    send_word('h11,0);
    fork send_word('h22,1); pop_at_push('h11); join
    bus(0,'h014,0);check(value[2] && value[5],"Replacement captures final-stop error");
    bus(0,'h004,0);check(value=='h22,"Replacement word preserved");
    fork send_word('h33,0); pop_at_push(0); join
    bus(0,'h004,0);check(value=='h33,"Empty read plus push does not pop arriving word");
    // RX falling edge and CFG write at the same completion edge.
    setup(1,'h008,0);rx=0;
    @(negedge clk); while(!dut.rx_fall) @(negedge clk);
    penable=1; complete(1);rx=1;#(PERIOD);
    bus(0,'h008,0);check(value==3,"RX fall rejects CFG write and preserves config");
    // Repeated START on the edge TX finishes must still see pre-edge busy.
    bus(1,'h000,'ha5);bus(1,'h00c,1);setup(1,'h00c,1);
    @(negedge clk);while(!dut.u_tx.tx_finish) @(negedge clk);
    penable=1;complete(1);
    check(!dut.tx_busy,"Rejected START cannot restart completing frame");
    // Reset in active TX and RX flushes frame/metadata, not only pending CTS.
    bus(1,'h00c,1);wait(!tx);rx=0;#1000;
    reset_n=0;#1;check(tx && rts_n && !pready,"Asynchronous assertion in active frame");
    rx=1;#100;reset_n=1;repeat(10) @(negedge clk);
    bus(0,'h010,0);check(value==1,"Reset clears both engines and holding slot");
    $display("PASS tb_races: %0d checks",checks);$finish;
  end
  initial begin #2000000;$fatal(1,"Race timeout");end
endmodule
