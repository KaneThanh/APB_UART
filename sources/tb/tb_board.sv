`timescale 1ns/1ps
module tb_board;
  logic CLOCK_50=0; always #10 CLOCK_50=~CLOCK_50;
  logic [3:0] KEY=4'hf;
  logic [4:0] SW=3;
  logic UART_RXD=1, UART_RTS=0, UART_TXD, UART_CTS;
  logic [6:0] HEX0,HEX1,HEX2,HEX3,HEX4,HEX5;
  logic [1:0] LED;
  integer checks=0, starts=0, apb_pops=0, baseline;
  de2_115_uart_top #(.DEBOUNCE_CYCLES(4)) dut (.*);
  always @(posedge CLOCK_50) if(dut.reset_n && dut.psel && dut.penable && dut.pready && !dut.pslverr) begin
    if(dut.pwrite && dut.paddr=='h00c && dut.pwdata[0]) starts++;
    if(!dut.pwrite && dut.paddr=='h004) apb_pops++;
  end
  task automatic check(input bit ok,input string message);
    checks++; if(!ok) $fatal(1,"%s t=%0t",message,$time);
  endtask
  task automatic keypress(input integer k);
    @(negedge CLOCK_50); KEY[k]=0; repeat(12) @(negedge CLOCK_50);
    KEY[k]=1; repeat(12) @(negedge CLOCK_50);
  endtask
  task automatic send_word(input logic[7:0] data,input integer n,par,stops,rate,input bit bad,input bit bad_stop=0);
    real period; bit parity;
    period=1.0e9/rate; parity=0;
    wait(!UART_CTS); #123; UART_RXD=0; #(period);
    for(int i=0;i<n;i++) begin UART_RXD=data[i]; parity^=data[i]; #(period); end
    if(par!=0) begin UART_RXD=(par==1 ? parity : !parity)^bad; #(period); end
    for(int i=0;i<stops;i++) begin UART_RXD=!(bad_stop && i==stops-1); #(period); end
    UART_RXD=1;
  endtask
  task automatic receive_word(input logic[7:0] data,input integer n,par,stops,rate);
    real period; bit parity;
    period=1.0e9/rate; parity=0;
    @(negedge UART_TXD); #(period/2); check(!UART_TXD,"Echo start");
    for(int i=0;i<n;i++) begin #(period); check(UART_TXD===data[i],"Echo data"); parity^=data[i]; end
    if(par!=0) begin #(period); check(UART_TXD===(par==1 ? parity : !parity),"Echo parity"); end
    for(int i=0;i<stops;i++) begin #(period); check(UART_TXD,"Echo stops"); end
    #(period); check(!LED[1],"No host error");
  endtask
  task automatic reset_board;
    @(negedge CLOCK_50); KEY=4'he; UART_RXD=1; UART_RTS=0;
    repeat(8) @(negedge CLOCK_50); check(HEX0==127,"Display blank during reset");
    KEY=15; wait(dut.active_baud_index==7); repeat(5) @(negedge CLOCK_50);
    check(dut.u_uart.cfg_active==3,"Master boots 8N1 via APB");
    check(!LED[0] && !LED[1],"Boot LEDs clear");
  endtask
  initial begin
    reset_board();
    check({HEX5,HEX4,HEX3,HEX2,HEX1,HEX0}=={7'h79,7'h79,7'h12,7'h24,7'h40,7'h40},"115200 six-digit display");
    for(int i=0;i<16;i++) begin
      baseline=starts;
      fork send_word(8'(i*17),8,0,1,115200,0); receive_word(8'(i*17),8,0,1,115200); join
      check(starts==baseline+1,"Exactly one START per echoed word");
    end
    // Hold CTS high after receive, then Apply while a TX request is pending.
    UART_RTS=1; repeat(5) @(negedge CLOCK_50);
    baseline=starts; send_word('h81,8,0,1,115200,0);
    wait(starts==baseline+1); check(UART_TXD,"Echo waits for CTS");
    keypress(1); check(dut.pending_baud_index==8 && dut.active_baud_index==7,"Baud selection remains pending");
    SW=5'b11110; repeat(15) @(negedge CLOCK_50); check(dut.pending_cfg=='h1e,"SW maps to 7E2");
    keypress(2); wait(LED[0]); repeat(100) @(negedge CLOCK_50);
    SW=3; repeat(15) @(negedge CLOCK_50); // Changes after Apply must not change its snapshot.
    check(dut.active_baud_index==7,"Apply waits for pending old frame");
    fork
      receive_word('h81,8,0,1,115200);
      begin #100; UART_RTS=0; end
    join
    wait(dut.active_baud_index==8); repeat(10) @(negedge CLOCK_50);
    check(LED[0] && UART_CTS && !LED[1],"Apply stays paused until Resume");
    check(dut.u_uart.cfg_active=='h1e,"Apply config readback committed");
    keypress(3); wait(!LED[0]); check(!UART_CTS,"Resume releases RTS");
    fork send_word('h65,7,1,2,230400,0); receive_word('h65,7,1,2,230400); join
    baseline=starts; send_word('h23,7,1,2,230400,1); #100000;
    check(starts==baseline && !LED[1],"Bad parity is popped/discarded without host fault");
    send_word('h31,7,1,2,230400,0,1); #100000;
    check(starts==baseline && !LED[1],"Bad final stop is discarded without host fault");
    // Reapply from PAUSED_READY; request settings must remain a snapshot.
    keypress(2); wait(LED[0]); wait(dut.u_master.state==18);
    keypress(1); check(dut.pending_baud_index==0,"Baud index wraps 8 to 0");
    SW=3; repeat(15) @(negedge CLOCK_50); keypress(2);
    wait(dut.active_baud_index==0); check(UART_CTS && LED[0],"Reapply preserves pause");
    keypress(3); wait(!LED[0]);
    fork send_word('h5a,8,0,1,2400,0); receive_word('h5a,8,0,1,2400); join
    // Inject one bus error; host must stop issuing requests until reset.
    @(negedge CLOCK_50); force dut.pslverr=1'b1;
    wait(LED[1]); release dut.pslverr; repeat(20) @(negedge CLOCK_50);
    check(!dut.psel && !dut.penable,"HOST_FAULT stops APB requests");
    reset_board();
    // Readback mismatch is a host fault even when the bus reports success.
    @(negedge CLOCK_50); KEY[0]=0; repeat(8) @(negedge CLOCK_50); KEY[0]=1;
    wait(dut.u_master.state==3); force dut.prdata=32'h0;
    wait(LED[1]); release dut.prdata; repeat(20) @(negedge CLOCK_50);
    check(!dut.psel && dut.active_baud_index==15,"Wrong boot readback never publishes active baud");
    reset_board();
    $display("PASS tb_board: %0d checks, %0d START writes, %0d RX pops",checks,starts,apb_pops); $finish;
  end
  initial begin #30000000; $fatal(1,"Board timeout"); end
endmodule
