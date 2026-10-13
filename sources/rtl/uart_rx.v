`default_nettype none
module uart_rx_fsm (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire rx_sync,
  input wire rx_fall,
  input wire rx_half_tick,
  input wire rx_bit_tick,
  input wire rx_last_data,
  input wire rx_last_stop,
  input wire rx_parity_en,
  output reg rx_load,
  output reg rx_run,
  output reg rx_os_clr,
  output reg rx_data_sample,
  output reg rx_parity_sample,
  output reg rx_stop_sample,
  output reg rx_push,
  output reg rx_busy
);
  localparam [2:0] IDLE=3'd0,
    START_CHECK=3'd1,
    DATA=3'd2,
    PARITY=3'd3,
    STOP=3'd4,
    WAIT_HIGH=3'd5;
  reg [2:0] state, next_state;
  always @* begin
    next_state=state;
    rx_load=0; rx_run=0; rx_os_clr=0; rx_data_sample=0;
    rx_parity_sample=0; rx_stop_sample=0; rx_push=0;
    case (state)
      IDLE: if (sync_ready && rx_fall) begin rx_load=1; next_state=START_CHECK; end
      START_CHECK: begin
        rx_run=1;
        if (rx_half_tick)
          if (!rx_sync) begin rx_os_clr=1; next_state=DATA; end
          else next_state=IDLE;
      end
      DATA: begin
        rx_run=1;
        if (rx_bit_tick) begin
          rx_data_sample=1;
          if (rx_last_data) begin
            if (rx_parity_en) next_state=PARITY; else next_state=STOP;
          end
        end
      end
      PARITY: begin
        rx_run=1;
        if (rx_bit_tick) begin rx_parity_sample=1; next_state=STOP; end
      end
      STOP: begin
        rx_run=1;
        if (rx_bit_tick) begin
          rx_stop_sample=1;
          if (rx_last_stop) begin
            rx_push=1;
            if (rx_sync) next_state=IDLE; else next_state=WAIT_HIGH;
          end
        end
      end
      WAIT_HIGH: if (rx_sync) next_state=IDLE;
      default: next_state=IDLE;
    endcase
    rx_busy=rx_run;
  end
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) state<=IDLE; else state<=next_state;
endmodule

module uart_rx_timing #(parameter integer CLK_FREQ=50000000) (
  input wire clk,
  input wire rst_n_int,
  input wire [17:0] baud_active,
  input wire rx_load,
  input wire rx_run,
  input wire rx_os_clr,
  output wire rx_half_tick,
  output wire rx_bit_tick
);
  `include "uart_functions.vh"
  localparam integer W=uart_clog2(CLK_FREQ)+1;
  reg [W-1:0] phase;
  wire [W-1:0] sum;
  localparam [W-1:0] CLK_LIMIT=CLK_FREQ[W-1:0];
  wire [W-1:0] baud_extended;
  reg [17:0] baud_snapshot;
  reg [3:0] os_count;
  wire raw_tick;
  assign baud_extended=baud_snapshot;
  assign sum=phase+(baud_extended<<4);
  assign raw_tick=rx_run && (sum>=CLK_LIMIT);
  assign rx_half_tick=raw_tick && (os_count==7);
  assign rx_bit_tick=raw_tick && (os_count==15);
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin phase<=0; baud_snapshot<=0; os_count<=0; end
    else begin
      if (rx_load) baud_snapshot<=baud_active;
      if (rx_load || !rx_run) phase<=0;
      else if (raw_tick) phase<=sum-CLK_LIMIT;
      else phase<=sum;
      if (rx_load || !rx_run || rx_os_clr) os_count<=0;
      else if (raw_tick) os_count<=os_count+1'b1;
    end
endmodule

module uart_rx_frame_datapath (
  input wire clk,
  input wire rst_n_int,
  input wire rx_sync,
  input wire [4:0] cfg_active,
  input wire rx_load,
  input wire rx_data_sample,
  input wire rx_parity_sample,
  input wire rx_stop_sample,
  output reg [7:0] rx_word,
  output wire rx_last_data,
  output wire rx_last_stop,
  output wire rx_parity_en,
  output wire rx_parity_bad_next,
  output wire rx_frame_bad_next
);
  reg [4:0] cfg_snapshot;
  reg [2:0] data_index;
  reg stop_index;
  reg parity_xor;
  reg parity_bad;
  reg frame_bad;
  wire expected_parity;
  assign rx_last_data=(data_index==(3'd4+{1'b0,cfg_snapshot[1:0]}));
  assign rx_last_stop=!cfg_snapshot[2] || stop_index;
  assign rx_parity_en=cfg_snapshot[3];
  assign expected_parity=cfg_snapshot[4] ? parity_xor : !parity_xor;
  assign rx_parity_bad_next=parity_bad || (rx_parity_sample && (rx_sync!=expected_parity));
  assign rx_frame_bad_next=frame_bad || (rx_stop_sample && !rx_sync);
  always @(posedge clk or negedge rst_n_int)
    if (!rst_n_int) begin
      cfg_snapshot<=0; data_index<=0; stop_index<=0; rx_word<=0;
      parity_xor<=0; parity_bad<=0; frame_bad<=0;
    end else if (rx_load) begin
      cfg_snapshot<=cfg_active; data_index<=0; stop_index<=0; rx_word<=0;
      parity_xor<=0; parity_bad<=0; frame_bad<=0;
    end else begin
      if (rx_data_sample) begin
        rx_word[data_index]<=rx_sync; parity_xor<=parity_xor^rx_sync;
        if (!rx_last_data) data_index<=data_index+1'b1;
      end
      if (rx_parity_sample) parity_bad<=rx_parity_bad_next;
      if (rx_stop_sample) begin
        frame_bad<=rx_frame_bad_next;
        if (!rx_last_stop) stop_index<=1;
      end
    end
endmodule

module uart_rx #(parameter integer CLK_FREQ=50000000) (
  input wire clk,
  input wire rst_n_int,
  input wire sync_ready,
  input wire rx_sync,
  input wire rx_fall,
  input wire [4:0] cfg_active,
  input wire [17:0] baud_active,
  output wire [7:0] rx_word,
  output wire rx_push,
  output wire rx_busy,
  output wire rx_parity_bad_next,
  output wire rx_frame_bad_next
);
  wire rx_half_tick;
  wire rx_bit_tick;
  wire rx_last_data;
  wire rx_last_stop;
  wire rx_parity_en;
  wire rx_load;
  wire rx_run;
  wire rx_os_clr;
  wire rx_data_sample;
  wire rx_parity_sample;
  wire rx_stop_sample;
  uart_rx_fsm u_fsm (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .sync_ready(sync_ready),
    .rx_sync(rx_sync),
    .rx_fall(rx_fall),
    .rx_half_tick(rx_half_tick),
    .rx_bit_tick(rx_bit_tick),
    .rx_last_data(rx_last_data),
    .rx_last_stop(rx_last_stop),
    .rx_parity_en(rx_parity_en),
    .rx_load(rx_load),
    .rx_run(rx_run),
    .rx_os_clr(rx_os_clr),
    .rx_data_sample(rx_data_sample),
    .rx_parity_sample(rx_parity_sample),
    .rx_stop_sample(rx_stop_sample),
    .rx_push(rx_push),
    .rx_busy(rx_busy)
  );
  uart_rx_timing #(.CLK_FREQ(CLK_FREQ)) u_timer (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .baud_active(baud_active),
    .rx_load(rx_load),
    .rx_run(rx_run),
    .rx_os_clr(rx_os_clr),
    .rx_half_tick(rx_half_tick),
    .rx_bit_tick(rx_bit_tick)
  );
  uart_rx_frame_datapath u_frame (
    .clk(clk),
    .rst_n_int(rst_n_int),
    .rx_sync(rx_sync),
    .cfg_active(cfg_active),
    .rx_load(rx_load),
    .rx_data_sample(rx_data_sample),
    .rx_parity_sample(rx_parity_sample),
    .rx_stop_sample(rx_stop_sample),
    .rx_word(rx_word),
    .rx_last_data(rx_last_data),
    .rx_last_stop(rx_last_stop),
    .rx_parity_en(rx_parity_en),
    .rx_parity_bad_next(rx_parity_bad_next),
    .rx_frame_bad_next(rx_frame_bad_next)
  );
endmodule

`default_nettype wire
