`timescale 1ns/1ps
module tb_uart_apb;
  logic clk=0; always #10 clk=~clk;
  logic reset_n=0, psel=0, penable=0, pwrite=0;
  logic [3:0] pstrb=0;
  logic [11:0] paddr=0;
  logic [31:0] pwdata=0, prdata;
  logic rx=1, cts_n=0, tx, rts_n, pready, pslverr;
  integer cases=0, checks=0;
  logic [31:0] value;
  uart_apb_top #(.RUNTIME_BAUD_EN(1)) dut (.*);
  task automatic check(input bit ok, input string message);
    checks++;
    if (!ok) $fatal(1,"%s t=%0t",message,$time);
  endtask
  task automatic bus(input bit wr, input logic [11:0] addr, input logic [31:0] data,
                     input logic [3:0] strb, input bit expect_error, output logic [31:0] result);
    @(negedge clk); psel=1; penable=0; pwrite=wr; paddr=addr; pwdata=data; pstrb=strb;
    @(posedge clk); #1; check(!pready,"No completion in SETUP");
    @(negedge clk); penable=1;
    @(posedge clk);
    check(pready===1'b1,"Zero-wait ACCESS ready");
    check(pslverr===expect_error,"APB error response"); result=prdata;
    @(negedge clk); psel=0; penable=0; pwrite=0; pstrb=0;
  endtask
  task automatic wr(input logic [11:0] addr,input logic [31:0] data);
    logic [31:0] ignored; bus(1,addr,data,1,0,ignored);
  endtask
  task automatic rd(input logic [11:0] addr,output logic [31:0] data);
    bus(0,addr,0,0,0,data);
  endtask
  function automatic integer baud(input integer b);
    case(b)
      0:baud=2400;1:baud=4800;2:baud=9600;3:baud=19200;4:baud=38400;
      5:baud=57600;6:baud=76800;7:baud=115200;8:baud=230400;
    endcase
  endfunction
  // Independent peer uses real bit periods, not the DUT fractional accumulator.
  task automatic send_word(input logic [7:0] data,input integer n,par,stops,rate,
                           input bit bad_parity,bad_stop,input real scale);
    real period; bit parity;
    period=1.0e9/rate*scale; parity=0;
    #137; rx=0; #(period);
    for(int i=0;i<n;i++) begin rx=data[i]; parity^=data[i]; #(period); end
    if(par!=0) begin rx=(par==1 ? parity : !parity)^bad_parity; #(period); end
    for(int i=0;i<stops;i++) begin rx=!(bad_stop && i==stops-1); #(period); end
    rx=1; #(period/4);
  endtask
  task automatic expect_tx(input logic [7:0] data,input integer n,par,stops,rate);
    real period, started, elapsed; bit parity;
    period=1.0e9/rate; parity=0;
    @(negedge tx); started=$realtime; #(period/2);
    check(tx===0,"TX start bit");
    for(int i=0;i<n;i++) begin #(period); check(tx===data[i],"TX data LSB first"); parity^=data[i]; end
    if(par!=0) begin #(period); check(tx===(par==1 ? parity : !parity),"TX parity"); end
    for(int i=0;i<stops;i++) begin #(period); check(tx===1,"TX stop bit"); end
    #(period*0.4); check(dut.tx_busy===1,"TX busy through full final stop");
    wait(!dut.tx_busy); elapsed=$realtime-started;
    check(elapsed>=(1+n+(par!=0)+stops)*period-0.1,"TX never ends stop early");
    check(elapsed<=(1+n+(par!=0)+stops)*period+20.1,"TX accumulated baud error <= one clock");
  endtask
  task automatic expect_rx(input logic [7:0] data,input bit pe,fe);
    logic [31:0] s,e,d;
    rd('h010,s); rd('h014,e);
    check(s[1] && s[2]==pe && e[2]==fe,"RX valid and byte-associated metadata");
    check(rts_n===1,"RTS high when holding slot full");
    rd('h004,d); check(d=={24'b0,data},"RX data/zero extension");
    rd('h010,s); check(!s[1] && !s[2],"RX pop clears valid and parity");
    rd('h014,e); check(!e[2],"RX pop clears framing");
    check(!rts_n,"RTS low after pop");
  endtask
  task automatic reset_dut;
    @(negedge clk); reset_n=0; rx=1; cts_n=0;
    #100; check(tx===1 && rts_n===1 && pready===0,"Reset outputs");
    @(negedge clk); reset_n=1;
    repeat(10) @(negedge clk);
  endtask

  initial begin
    reset_dut();
    rd('h008,value); check(value==0,"Reset CFG is 5N1");
    rd('h01c,value); check(value==7,"Reset baud index");
    rd('h010,value); check(value==1,"Reset STATUS");
    rd('h004,value); check(value==0,"Empty read is zero");
    bus(0,'h018,0,0,1,value); check(value==0,"Unmapped read zero");
    bus(1,'h018,1,1,1,value);
    bus(0,'h001,0,0,1,value); bus(1,'h004,1,0,1,value);
    bus(1,'h010,1,1,1,value); bus(1,'h014,1,1,1,value);
    bus(1,'h01c,9,1,1,value); rd('h01c,value); check(value==7,"Invalid baud unchanged");
    bus(1,'h01c,15,2,0,value); bus(1,'h008,31,0,0,value);
    rd('h008,value); check(value==0,"Zero-strobe no-op");
    wr('h020,1); check(rts_n,"Pause forces RTS"); wr('h020,0); check(!rts_n,"Resume RTS");
    // All 9 rates x 4 data lengths x 3 parity modes x 2 stop counts, duplex.
    for(int b=0;b<9;b++) begin
      for(int n=5;n<=8;n++) for(int par=0;par<3;par++) for(int stops=1;stops<=2;stops++) begin
        wr('h008,(n-5)|((stops-1)<<2)|((par!=0)<<3)|((par==1)<<4)); wr('h01c,b);
        wr('h000,'ha6);
        fork
          expect_tx(8'ha6,n,par,stops,baud(b));
          send_word(8'h59,n,par,stops,baud(b),0,0,1.0);
          wr('h00c,1);
        join
        expect_rx(8'h59 & ((1<<n)-1),0,0); cases++;
      end
      $display("PASS baud=%0d all 24 formats full duplex",baud(b));
    end
    // Ignored parity type when parity disabled.
    wr('h008,'h13); wr('h01c,8); wr('h000,'h5a);
    fork expect_tx('h5a,8,0,1,230400); wr('h00c,1); join
    // CTS gates start, staging writes do not alter a pending frame.
    cts_n=1; repeat(5) @(negedge clk); wr('h000,'hc3); wr('h00c,1);
    repeat(100) @(negedge clk); check(tx && dut.tx_busy,"CTS blocks pending start");
    bus(1,'h00c,1,1,1,value); bus(1,'h008,0,1,1,value); bus(1,'h01c,0,1,1,value);
    bus(1,'h008,0,2,0,value); bus(1,'h00c,0,1,0,value); wr('h000,'h3c);
    fork
      expect_tx('hc3,8,0,1,230400);
      begin cts_n=0; @(negedge tx); #1000; cts_n=1; end
    join
    cts_n=0;
    // Error metadata; full/drop policy retains the first word and its flags.
    wr('h008,'h1b);
    send_word('ha5,8,1,1,230400,1,0,1.0);
    bus(1,'h008,3,1,1,value);
    send_word('h33,8,1,1,230400,0,1,1.0);
    expect_rx('ha5,1,0);
    send_word('h87,8,1,1,230400,0,1,1.0); expect_rx('h87,0,1);
    // Final stop error in a two-stop frame must be committed on the same edge.
    wr('h008,'h1f); send_word('h96,8,1,2,230400,0,1,1.0); expect_rx('h96,0,1);
    // False start and sustained break.
    wr('h008,3); rx=0; #500; rx=1; #10000;
    rd('h010,value); check(!value[1],"False start is discarded");
    rx=0; #60000; expect_rx(0,0,1); #60000;
    rd('h010,value); check(!value[1],"Break commits only once until line high"); rx=1; #1000;
    // Peer bit-period offsets +/-2 percent.
    for(int n=5;n<=8;n++) begin
      wr('h008,(n-5)|'h1c);
      send_word('ha5,n,1,2,230400,0,0,0.98); expect_rx(8'ha5 & ((1<<n)-1),0,0);
      send_word('h5a,n,1,2,230400,0,0,1.02); expect_rx(8'h5a & ((1<<n)-1),0,0);
    end
    // RX busy and falling-edge guard reject effective configuration writes.
    fork
      send_word('h5a,8,1,2,230400,0,0,1.0);
      begin #5000; bus(1,'h008,0,1,1,value); bus(1,'h01c,0,1,1,value); end
    join
    expect_rx('h5a,0,0);
    // External reset flushes engines/slot; CTS high cannot survive reset as a request.
    cts_n=1; repeat(5) @(negedge clk); wr('h000,55); wr('h00c,1);
    @(negedge clk); reset_n=0; #100;
    check(tx && rts_n && !pready,"reset_n resets whole core");
    reset_n=1; repeat(10) @(negedge clk);
    rd('h010,value); check(value==1,"Reset cancels pending TX");
    $display("PASS tb_uart_apb: %0d duplex format cases, %0d checks",cases,checks); $finish;
  end
  initial begin #500000000; $fatal(1,"Global timeout"); end
endmodule
