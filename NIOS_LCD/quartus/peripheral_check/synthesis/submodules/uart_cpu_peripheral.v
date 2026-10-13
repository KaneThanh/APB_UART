module uart_cpu_peripheral #(
  parameter integer CLK_HZ=50000000
) (
  input wire clk, reset_n,
  input wire [12:0] address,
  input wire read, write,
  input wire [31:0] writedata,
  input wire [3:0] byteenable,
  output wire [31:0] readdata,
  output wire waitrequest,
  input wire rx, cts_n,
  output wire tx, rts_n,
  input wire [7:0] switches,
  input wire [2:0] keys_n,
  output reg [1:0] leds,
  output wire [7:0] lcd_data,
  output wire lcd_rs, lcd_rw, lcd_en, lcd_on, lcd_blon
);
  reg [10:0] io_meta, io_sync;
  reg [31:0] divider, milliseconds, apb_errors;
  wire psel, penable, pwrite, pready, pslverr, bridge_wait, error_pulse;
  wire [11:0] paddr;
  wire [31:0] pwdata, prdata, bridge_data;
  wire [3:0] pstrb;
  reg [31:0] local_data;
  wire uart_select=!address[12];
  wire local_write=write && address[12];
  assign waitrequest=uart_select ? bridge_wait : 1'b0;
  assign readdata=uart_select ? bridge_data : local_data;
  always @* begin
    local_data=0;
    case (address)
      13'h1100: local_data={21'b0,io_sync};
      13'h1104: local_data=milliseconds;
      13'h1108: local_data={30'b0,leds};
      13'h110c: local_data=apb_errors;
      13'h1110: local_data=32'h4e494f31;
      default: local_data=0;
    endcase
  end
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      io_meta<=11'h700; io_sync<=11'h700;
      divider<=0; milliseconds<=0; leds<=0; apb_errors<=0;
    end else begin
      io_meta<={keys_n,switches}; io_sync<=io_meta;
      if (divider==CLK_HZ/1000-1) begin
        divider<=0; milliseconds<=milliseconds+1;
      end else divider<=divider+1;
      if (local_write && address==13'h1108 && byteenable[0]) leds<=writedata[1:0];
      if (error_pulse) apb_errors<=apb_errors+1;
    end
  avalon_apb_bridge bridge (
    .clk(clk),.reset_n(reset_n),.address(address[11:0]),
    .read(read && uart_select),.write(write && uart_select),
    .writedata(writedata),.byteenable(byteenable),
    .readdata(bridge_data),.waitrequest(bridge_wait),.error_pulse(error_pulse),
    .psel(psel),.penable(penable),.pwrite(pwrite),.paddr(paddr),
    .pwdata(pwdata),.pstrb(pstrb),.prdata(prdata),.pready(pready),.pslverr(pslverr)
  );
  uart_apb_top #(.CLK_FREQ(CLK_HZ),.BAUDRATE(115200),.RUNTIME_BAUD_EN(1)) uart (
    .clk(clk),.reset_n(reset_n),.psel(psel),.penable(penable),.pwrite(pwrite),
    .paddr(paddr),.pwdata(pwdata),.pstrb(pstrb),.prdata(prdata),
    .pready(pready),.pslverr(pslverr),.rx(rx),.cts_n(cts_n),.tx(tx),.rts_n(rts_n)
  );
  lcd_text #(.CLK_HZ(CLK_HZ)) lcd (
    .clk(clk),.reset_n(reset_n),
    .wr(local_write && address>=13'h1000 && address<13'h1080 && address[1:0]==0 && byteenable[0]),
    .index(address[6:2]),.data(writedata[7:0]),
    .lcd_data(lcd_data),.lcd_rs(lcd_rs),.lcd_rw(lcd_rw),
    .lcd_en(lcd_en),.lcd_on(lcd_on),.lcd_blon(lcd_blon)
  );
endmodule
