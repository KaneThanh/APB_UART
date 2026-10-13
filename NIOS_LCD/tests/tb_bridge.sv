module tb_bridge;
  reg clk=0; always #5 clk=~clk;
  reg reset_n=0, read=0, write=0, pready=0, pslverr=0;
  reg [11:0] address=0;
  reg [31:0] writedata=0,prdata=0;
  reg [3:0] byteenable=0;
  wire waitrequest,psel,penable,pwrite,error_pulse;
  wire [31:0] readdata,pwdata;
  wire [11:0] paddr;
  wire [3:0] pstrb;
  integer completions=0;
  avalon_apb_bridge dut(.*);
  always @(posedge clk) if (reset_n && psel && penable && pready) completions<=completions+1;
  task xfer(input bit wr,input [11:0] a,input bit err);
    integer k;
    begin
      @(negedge clk); address=a; write=wr; read=!wr; byteenable=4'b0101; writedata=32'h12345678;
      @(negedge clk);
      if(!psel||penable) $fatal(1,"Missing APB SETUP");
      @(negedge clk);
      for(k=0;k<3;k=k+1) begin
        if(!psel||!penable||!waitrequest||paddr!=a||pwrite!=wr||pwdata!=32'h12345678||pstrb!=5) $fatal(1,"ACCESS stability");
        @(negedge clk);
      end
      prdata=32'h89abcdef; pslverr=err; pready=1;
      @(negedge clk);
      if(waitrequest||readdata!=32'h89abcdef||error_pulse!=err||psel) $fatal(1,"Response mismatch");
      @(negedge clk); read=0;write=0;pready=0;pslverr=0;
    end
  endtask
  initial begin
    repeat(3) @(negedge clk); reset_n=1;
    xfer(1,12'h008,0); xfer(0,12'h004,0); xfer(1,12'h018,1);
    if(completions!=3) $fatal(1,"Duplicate side effect");
    @(negedge clk); read=1;
    repeat(2) @(negedge clk); reset_n=0; read=0;
    @(negedge clk); if(psel||penable) $fatal(1,"reset failed");
    $display("PASS bridge: setup/access, wait states, read/write strobes, PSLVERR and reset"); $finish;
  end
  initial begin #10000; $fatal(1,"timeout"); end
endmodule
