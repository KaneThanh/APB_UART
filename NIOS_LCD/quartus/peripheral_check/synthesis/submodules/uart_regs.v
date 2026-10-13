`default_nettype none
module uart_regs #(
  parameter integer BAUDRATE=115200,
  parameter [0:0] RUNTIME_BAUD_EN=0
) (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire pwrite,
  input wire [11:0] paddr,
  input wire [31:0] pwdata,
  input wire [3:0] pstrb,
  input wire wr_fire,
  input wire rd_fire,
  input wire tx_busy,
  input wire rx_busy,
  input wire rx_sync,
  input wire cts_n_sync,
  input wire rts_n,
  input wire [7:0] slot_data,
  input wire slot_valid,
  input wire slot_parity_bad,
  input wire slot_frame_bad,
  output reg access_error,
  output reg [31:0] prdata,
  output reg [7:0] tx_data_stage,
  output reg [4:0] cfg_active,
  output wire [17:0] baud_active,
  output wire tx_accept,
  output wire rx_pop,
  output wire rx_pause_next
);
  `include "uart_functions.vh"
  reg [3:0] baud_sel;
  reg rx_pause;
  wire cfg_safe;
  reg mapped;
  reg read_only;
  reg [7:0] reg_sel;
  assign cfg_safe=sync_ready && !tx_busy && !rx_busy && !slot_valid && rx_sync;
  always @* begin
    reg_sel=0;
    case (paddr)
      12'h000: reg_sel[0]=1; 12'h004: reg_sel[1]=1;
      12'h008: reg_sel[2]=1; 12'h00c: reg_sel[3]=1;
      12'h010: reg_sel[4]=1; 12'h014: reg_sel[5]=1;
      12'h01c: reg_sel[6]=1; 12'h020: reg_sel[7]=1;
      default: reg_sel=0;
    endcase
    mapped=|reg_sel;
    read_only=reg_sel[1] || reg_sel[4] || reg_sel[5];
    access_error=!mapped || (pwrite && read_only);
    if (pwrite && pstrb[0]) begin
      if (reg_sel[2] && !cfg_safe) access_error=1;
      if (reg_sel[6] && (!cfg_safe || !RUNTIME_BAUD_EN || pwdata[3:0]>8)) access_error=1;
      if (reg_sel[3] && pwdata[0] && tx_busy) access_error=1;
    end
  end
  assign baud_active=baud_value(baud_sel);
  assign tx_accept=wr_fire && pstrb[0] && reg_sel[3] && pwdata[0];
  assign rx_pop=rd_fire && reg_sel[1] && slot_valid;
  assign rx_pause_next=(wr_fire && pstrb[0] && reg_sel[7]) ? pwdata[0] : rx_pause;
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin tx_data_stage<=0; cfg_active<=0; baud_sel<=baud_index(BAUDRATE); rx_pause<=0; end
    else begin
      rx_pause<=rx_pause_next;
      if (wr_fire && pstrb[0]) begin
        if (reg_sel[0]) tx_data_stage<=pwdata[7:0];
        if (reg_sel[2]) cfg_active<=pwdata[4:0];
        if (reg_sel[6]) baud_sel<=pwdata[3:0];
      end
    end
  always @* begin
    prdata=0;
    if (!access_error) begin
      if (reg_sel[0]) prdata={24'b0,tx_data_stage};
      if (reg_sel[1] && slot_valid) prdata={24'b0,slot_data};
      if (reg_sel[2]) prdata={27'b0,cfg_active};
      if (reg_sel[4]) prdata={29'b0,slot_parity_bad,slot_valid,!tx_busy};
      if (reg_sel[5]) prdata={24'b0,RUNTIME_BAUD_EN,cfg_safe,slot_valid,rts_n,cts_n_sync,slot_frame_bad,rx_busy,tx_busy};
      if (reg_sel[6]) prdata={28'b0,baud_sel};
      if (reg_sel[7]) prdata={31'b0,rx_pause};
    end
  end
endmodule

`default_nettype wire
