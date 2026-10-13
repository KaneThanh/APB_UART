`default_nettype none
module uart_tx_fsm (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire tx_accept,
  input wire cts_n_sync,
  input wire tx_bit_tick,
  input wire tx_last_bit,
  output reg tx_load,
  output reg tx_begin,
  output reg tx_run,
  output reg tx_advance,
  output reg tx_finish,
  output reg tx_busy
);
  localparam [1:0] IDLE=2'd0,
    WAIT_CTS=2'd1,
    SEND=2'd2;
  reg [1:0] state, next_state;
  always @* begin
    next_state=state;
    tx_load=0; tx_begin=0; tx_run=0; tx_advance=0; tx_finish=0; tx_busy=0;
    case (state)
      IDLE: if (tx_accept) begin tx_load=1; next_state=WAIT_CTS; end
      WAIT_CTS: begin
        tx_busy=1;
        if (sync_ready && !cts_n_sync) begin tx_begin=1; next_state=SEND; end
      end
      SEND: begin
        tx_busy=1; tx_run=1;
        if (tx_bit_tick)
          if (tx_last_bit) begin tx_finish=1; next_state=IDLE; end
          else tx_advance=1;
      end
      default: begin tx_finish=1; next_state=IDLE; end
    endcase
  end
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) state<=IDLE; else state<=next_state;
endmodule

module uart_tx_frame_datapath (
  input wire clk,
  input wire rst_n_int,
  input wire [7:0] tx_data_stage,
  input wire [4:0] cfg_active,
  input wire tx_load,
  input wire tx_begin,
  input wire tx_advance,
  input wire tx_finish,
  output reg tx,
  output wire tx_last_bit
);
  reg [11:0] packed_frame;
  reg [11:0] frame_shift;
  reg [3:0] frame_length;
  reg [3:0] bits_left;
  reg parity;
  integer n, i;
  always @* begin
    n=5+cfg_active[1:0];
    packed_frame=12'hfff; packed_frame[0]=0; parity=0;
    for (i=0; i<8; i=i+1) if (i<n) begin
      packed_frame[i+1]=tx_data_stage[i]; parity=parity ^ tx_data_stage[i];
    end
    if (cfg_active[3]) packed_frame[n+1]=cfg_active[4] ? parity : !parity;
    frame_length=4'd7+{2'b0,cfg_active[1:0]}+{3'b0,cfg_active[3]}+{3'b0,cfg_active[2]};
  end
  assign tx_last_bit=(bits_left==1);
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin frame_shift<=12'hfff; bits_left<=0; tx<=1; end
    else if (tx_load) begin frame_shift<=packed_frame; bits_left<=frame_length; tx<=1; end
    else if (tx_begin) tx<=frame_shift[0];
    else if (tx_finish) begin tx<=1; bits_left<=0; end
    else if (tx_advance) begin
      tx<=frame_shift[1]; frame_shift<={1'b1,frame_shift[11:1]}; bits_left<=bits_left-1'b1;
    end
endmodule

module uart_tx_bit_timer #(parameter integer CLK_FREQ=50000000) (
  input wire clk,
  input wire rst_n_int,
  input wire [17:0] baud_active,
  input wire tx_load,
  input wire tx_begin,
  input wire tx_run,
  output wire tx_bit_tick
);
  `include "uart_functions.vh"
  localparam integer W=uart_clog2(CLK_FREQ)+1;
  reg [W-1:0] phase;
  wire [W-1:0] sum;
  localparam [W-1:0] CLK_LIMIT=CLK_FREQ[W-1:0];
  wire [W-1:0] baud_extended;
  reg [17:0] baud_snapshot;
  assign baud_extended=baud_snapshot;
  assign sum=phase+baud_extended;
  assign tx_bit_tick=tx_run && (sum>=CLK_LIMIT);
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin phase<=0; baud_snapshot<=0; end
    else begin
      if (tx_load) baud_snapshot<=baud_active;
      if (tx_load || tx_begin || !tx_run) phase<=0;
      else if (tx_bit_tick) phase<=sum-CLK_LIMIT;
      else phase<=sum;
    end
endmodule

module uart_tx #(parameter integer CLK_FREQ=50000000) (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire tx_accept,
  input wire cts_n_sync,
  input wire [7:0] tx_data_stage,
  input wire [4:0] cfg_active,
  input wire [17:0] baud_active,
  output wire tx,
  output wire tx_busy
);
  wire tx_load;
  wire tx_begin;
  wire tx_run;
  wire tx_advance;
  wire tx_finish;
  wire tx_bit_tick;
  wire tx_last_bit;
  uart_tx_fsm u_fsm (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .tx_accept(tx_accept),
    .cts_n_sync(cts_n_sync),
    .tx_bit_tick(tx_bit_tick),
    .tx_last_bit(tx_last_bit),
    .tx_load(tx_load),
    .tx_begin(tx_begin),
    .tx_run(tx_run),
    .tx_advance(tx_advance),
    .tx_finish(tx_finish),
    .tx_busy(tx_busy)
  );
  uart_tx_frame_datapath u_frame (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .tx_data_stage(tx_data_stage),
    .cfg_active(cfg_active),
    .tx_load(tx_load),
    .tx_begin(tx_begin),
    .tx_advance(tx_advance),
    .tx_finish(tx_finish),
    .tx(tx),
    .tx_last_bit(tx_last_bit)
  );
  uart_tx_bit_timer #(.CLK_FREQ(CLK_FREQ)) u_timer (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .baud_active(baud_active),
    .tx_load(tx_load),
    .tx_begin(tx_begin),
    .tx_run(tx_run),
    .tx_bit_tick(tx_bit_tick)
  );
endmodule

`default_nettype wire
