module board_controls #(
  parameter integer CLK_FREQ=50000000,
  parameter integer BAUDRATE=115200,
  parameter integer DEBOUNCE_CYCLES=CLK_FREQ/100
) (
  input wire clk,
  input wire reset_n,
  input wire [3:0] KEY,
  input wire [4:0] SW,
  output reg [3:0] pending_baud_index,
  output reg [4:0] pending_cfg,
  output reg cfg_req,
  output reg baud_req,
  output reg report_req
);
  `include "uart_functions.vh"
  localparam integer CW=(DEBOUNCE_CYCLES<2) ? 1 : uart_clog2(DEBOUNCE_CYCLES);
  (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
  reg [2:0] key_meta, key_sync;
  (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
  reg [4:0] sw_meta, sw_sync;
  reg [2:0] key_stable;
  reg [2:0] press;
  reg [4:0] sw_candidate;
  reg sw_initialized;
  reg [CW-1:0] key_count [0:2];
  reg [CW-1:0] sw_count;
  localparam integer DEBOUNCE_LAST_INT=DEBOUNCE_CYCLES-1;
  localparam [CW-1:0] DEBOUNCE_LAST=DEBOUNCE_LAST_INT[CW-1:0];
  integer i, k;
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin key_meta<=7; key_sync<=7; sw_meta<=0; sw_sync<=0; end
    else begin key_meta<=KEY[3:1]; key_sync<=key_meta; sw_meta<=SW; sw_sync<=sw_meta; end
  always @* begin
    press=0;
    for (k=0;k<3;k=k+1)
      press[k]=key_stable[k] && !key_sync[k] && (key_count[k]==DEBOUNCE_LAST);
  end
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      key_stable<=7; sw_candidate<=0; sw_count<=0; pending_cfg<=0; sw_initialized<=0;
      pending_baud_index<=baud_index(BAUDRATE); cfg_req<=0; baud_req<=0; report_req<=0;
      for (i=0;i<3;i=i+1) key_count[i]<=0;
    end else begin
      cfg_req<=0; baud_req<=0; report_req<=0;
      for (i=0;i<3;i=i+1) begin
        if (key_sync[i]==key_stable[i]) key_count[i]<=0;
        else if (key_count[i]==DEBOUNCE_LAST) begin key_stable[i]<=key_sync[i]; key_count[i]<=0; end
        else key_count[i]<=key_count[i]+1'b1;
      end
      if (sw_sync!=sw_candidate) begin sw_candidate<=sw_sync; sw_count<=0; end
      else if (sw_count==DEBOUNCE_LAST) begin
        if (!sw_initialized || pending_cfg!={sw_candidate[3],sw_candidate[2],sw_candidate[4],sw_candidate[1:0]}) begin
          pending_cfg<={sw_candidate[3],sw_candidate[2],sw_candidate[4],sw_candidate[1:0]};
          cfg_req<=1; sw_initialized<=1;
        end
      end
      else sw_count<=sw_count+1'b1;
      if (press[2]) report_req<=1;
      if (press[0]) begin
        pending_baud_index<=(pending_baud_index==8) ? 4'd0 : pending_baud_index+1'b1;
        baud_req<=1;
      end
    end
endmodule


