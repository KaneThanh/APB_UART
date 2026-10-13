`timescale 1ns/1ps
module tb_board_recovery;
  logic CLOCK_50=0; always #10 CLOCK_50=~CLOCK_50;
  logic [3:0] KEY=15;
  logic [4:0] SW=3;
  logic UART_RXD=1, UART_RTS=0;
  wire UART_TXD, UART_CTS;
  wire [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
  wire [1:0] LED;
  integer cycles;
  de2_115_uart_top #(.DEBOUNCE_CYCLES(4)) dut (.*);
  task automatic keypress(input integer k);
    @(negedge CLOCK_50); KEY[k]=0;
    repeat(12) @(negedge CLOCK_50); KEY[k]=1;
    repeat(12) @(negedge CLOCK_50);
  endtask
  task automatic boot;
    keypress(0);
    cycles=0;
    while(dut.active_baud_index!=7 && cycles<1000) begin
      @(negedge CLOCK_50); cycles++;
    end
    if(dut.active_baud_index!=7) $fatal(1,"boot timeout");
  endtask
  initial begin
    boot();
    if (!$test$plusargs("BOOT_ONLY")) begin
      UART_RTS=1;
      repeat(10) @(negedge CLOCK_50);
      UART_RXD=0; #8681;
      for(int i=0;i<8;i++) begin UART_RXD=(8'h41>>i)&1; #8681; end
      UART_RXD=1; #8681;
      wait(dut.u_uart.tx_busy);
      keypress(2);
      wait(dut.u_master.state==12);
      keypress(3);
      UART_RTS=0;
      repeat(10000) @(negedge CLOCK_50);
      if(LED[0] || LED[1] || dut.u_uart.u_regs.rx_pause)
        $fatal(1,"Resume during Apply was lost; state=%0d",dut.u_master.state);
    end
    keypress(0);
    // Emulate a completed RX word before boot's first status poll.
    // Release forced valid on APB pop, as the real slot would do.
    // Hold RX low first to stop the master advancing through boot.
    UART_RXD=0;
    keypress(0);
    force dut.u_uart.slot_valid=1'b1;
    UART_RXD=1;
    cycles=0;
    while(!(dut.psel && dut.penable && dut.pready && !dut.pwrite && dut.paddr==12'h004) && cycles<1000) begin
      @(negedge CLOCK_50); cycles++;
    end
    if(cycles==1000) $fatal(1,"boot deadlock: RX slot full is never popped");
    @(posedge CLOCK_50); #1; release dut.u_uart.slot_valid;
    cycles=0;
    while(dut.active_baud_index!=7 && cycles<2000) begin
      @(negedge CLOCK_50); cycles++;
    end
    if(dut.active_baud_index!=7 || LED[1]) $fatal(1,"boot did not recover after draining RX");
    $display("PASS tb_board_recovery: queued Resume and boot RX drain");
    $finish;
  end
  initial begin #5000000; $fatal(1,"recovery timeout"); end
endmodule
