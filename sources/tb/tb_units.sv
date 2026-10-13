`timescale 1ns/1ps
module tb_units;
  logic clk=0; always #10 clk=~clk;
  logic reset_n=0, rst_n_int=0, sync_ready=1, rx_pause_next=0;
  logic rx_push=0,rx_pop=0,rx_parity_bad_next=0,rx_frame_bad_next=0;
  logic [7:0] rx_word=0,slot_data;
  logic slot_valid,slot_parity_bad,slot_frame_bad,rts_n;
  uart_rx_slot slot (.*);
  logic req_valid=0,req_write=0,req_ready,done,response_error;
  logic [11:0] req_addr=0,paddr;
  logic [31:0] req_wdata=0,response_data,pwdata,prdata=0;
  logic [3:0] req_strb=0,pstrb;
  logic psel,penable,pwrite,pready=0,pslverr=0;
  apb_transaction_master bus (.*);
  logic [3:0] KEY=15,pending_baud_index;
  logic [4:0] SW=0,pending_cfg;
  logic apply_req,resume_req;
  board_controls #(.DEBOUNCE_CYCLES(4)) ui (.*);
  integer checks=0,apply_count=0,resume_count=0;
  always @(posedge clk) begin if(apply_req) apply_count++; if(resume_req) resume_count++; end
  task automatic check(input bit ok,input string message);
    checks++; if(!ok) $fatal(1,"%s",message);
  endtask
  task automatic cycle;
    @(posedge clk); #1; @(negedge clk);
  endtask
  initial begin
    #1; reset_n=0; rst_n_int=0; #40; reset_n=1; rst_n_int=1; cycle();
    check(!slot_valid && !rts_n,"Empty ready");
    rx_word='ha5; rx_push=1; rx_parity_bad_next=1; cycle(); rx_push=0;
    check(slot_valid && slot_data=='ha5 && rts_n && slot_parity_bad,"Push first");
    rx_word='h5a; rx_push=1; rx_parity_bad_next=0; cycle();
    check(slot_data=='ha5 && slot_parity_bad,"Full drop preserves old metadata");
    rx_pop=1; rx_frame_bad_next=1; cycle(); rx_pop=0; rx_push=0;
    check(slot_valid && slot_data=='h5a && !slot_parity_bad && slot_frame_bad && rts_n,"Pop+push replaces full slot");
    rx_pop=1; cycle(); rx_pop=0;
    check(!slot_valid && !slot_parity_bad && !slot_frame_bad && !rts_n,"Pop clears slot");
    rx_pause_next=1; cycle(); check(rts_n,"Pause next applied on same edge");
    rx_pause_next=0; cycle();
    // Bus payload latches once and remains stable through arbitrary wait cycles.
    req_addr='h024; req_wdata='hdeadbeef; req_write=1; req_strb=5; req_valid=1;
    cycle(); req_valid=0; check(psel && !penable && !req_ready,"SETUP phase");
    req_addr='hfff; req_wdata=0; req_strb=0;
    cycle(); check(psel && penable,"ACCESS phase");
    repeat(7) begin cycle(); check(psel && penable && paddr=='h024 && pwdata=='hdeadbeef && pstrb==5 && !done,"Wait-state payload stable"); end
    prdata='habcd1234; pslverr=1; pready=1; cycle(); pready=0; pslverr=0; prdata=0;
    check(done && response_error && response_data=='habcd1234 && !psel,"Capture error response once");
    cycle(); check(!done && req_ready,"DONE is one cycle");
    req_valid=1; req_write=0; req_addr=4; req_strb=15; cycle(); req_valid=0;
    check(pstrb==0,"Read PSTRB zero"); cycle(); prdata=77; pready=1; cycle(); pready=0;
    check(done && !response_error && response_data==77,"Successful read response"); cycle();
    // A short key bounce cannot change selection; held key produces one event.
    KEY[1]=0; cycle(); KEY[1]=1; repeat(10) cycle();
    check(pending_baud_index==7,"Key bounce ignored");
    KEY[1]=0; repeat(30) cycle(); check(pending_baud_index==8,"Held key increments once");
    KEY[1]=1; repeat(10) cycle(); KEY[1]=0; repeat(10) cycle(); check(pending_baud_index==0,"Index wrap");
    KEY=15; repeat(10) cycle(); SW=5'b10101; repeat(15) cycle();
    check(pending_cfg==5'h0d,"Nontrivial switch remapping 6O2");
    KEY[3:1]=0; repeat(20) cycle();
    check(apply_count==1 && resume_count==0 && pending_baud_index==0,"Simultaneous buttons prioritize Apply");
    KEY=15; repeat(10) cycle(); KEY[3]=0; repeat(15) cycle();
    check(resume_count==1,"Resume pulse exactly once");
    $display("PASS tb_units: %0d checks",checks); $finish;
  end
  initial begin #100000; $fatal(1,"Unit timeout"); end
endmodule
