module apb_echo_master (
  input wire clk,
  input wire reset_n,
  input wire [4:0] pending_cfg,
  input wire [3:0] pending_baud_index,
  input wire cfg_req,
  input wire baud_req,
  input wire report_req,
  input wire [31:0] prdata,
  input wire pready,
  input wire pslverr,
  output wire psel,
  output wire penable,
  output wire pwrite,
  output wire [11:0] paddr,
  output wire [31:0] pwdata,
  output wire [3:0] pstrb,
  output reg [3:0] active_baud_index,
  output reg [7:0] last_rx_byte,
  output reg [31:0] status_snapshot,
  output reg [31:0] ext_status_snapshot,
  output reg error,
  output wire pending
);
  localparam [4:0] WAIT_READY=0, BOOT_WAIT_SAFE=1, BOOT_CFG=2,
    BOOT_VERIFY=3, BOOT_BAUD=4, POLL_RX=5, READ_META=6, READ_RX=7,
    WAIT_TX=8, WRITE_TX=9, START_TX=10, PAUSE_REQ=11, DRAIN_STATUS=12,
    DRAIN_CHECK=13, APPLY_CFG=14, APPLY_BAUD=15, VERIFY_CFG=16,
    VERIFY_BAUD=17, POLL_EXT=18, RELEASE_RX=19, HOST_FAULT=20,
    BOOT_DRAIN_RX=21, REPORT_STATUS=22, REPORT_EXT=23,
    WAIT_TX_EXT=24, REPORT_FINISH=25;
  reg [4:0] state;
  reg req_valid, req_write, issued, transaction_state;
  wire req_ready, done, response_error;
  reg [11:0] req_addr;
  reg [31:0] req_wdata;
  wire [31:0] response_data;
  reg [3:0] req_strb;
  reg cfg_queued, baud_queued, report_queued;
  reg maintenance, config_operation, reporting;
  reg [4:0] desired_cfg, cfg_request, active_cfg;
  reg [3:0] desired_baud, baud_request_index;
  reg [7:0] temp_byte;
  reg parity_bad, frame_bad;
  reg [6:0] report_index;
  reg [31:0] report_status, report_ext;
  reg [7:0] report_byte;
  reg [31:0] report_word;
  reg [6:0] bit_position;
  assign pending=cfg_queued || baud_queued || maintenance;
  apb_transaction_master u_bus (
    .clk(clk),
    .reset_n(reset_n),
    .req_valid(req_valid),
    .req_write(req_write),
    .req_addr(req_addr),
    .req_wdata(req_wdata),
    .req_strb(req_strb),
    .req_ready(req_ready),
    .done(done),
    .response_error(response_error),
    .response_data(response_data),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .pstrb(pstrb),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr)
  );


  always @* begin
    report_word=(report_index>=34) ? report_ext : report_status;
    bit_position=(report_index>=34) ? report_index-7'd34 : report_index;
    if (report_index==32 || report_index==66) report_byte=8'h0d;
    else if (report_index==33 || report_index==67) report_byte=8'h0a;
    else report_byte=report_word[31-bit_position] ? 8'h31 : 8'h30;
  end
  always @* begin
    transaction_state=1; req_write=0; req_addr=0; req_wdata=0;
    case (state)
      BOOT_WAIT_SAFE, READ_META, DRAIN_STATUS, POLL_EXT, WAIT_TX_EXT, REPORT_EXT: req_addr=12'h014;
      BOOT_CFG: begin req_write=1; req_addr=12'h008; req_wdata=3; end
      BOOT_VERIFY, VERIFY_CFG: req_addr=12'h008;
      BOOT_BAUD, VERIFY_BAUD: req_addr=12'h01c;
      POLL_RX: begin
        req_addr=12'h010;
        if (cfg_queued || baud_queued || report_queued) transaction_state=0;
      end
      WAIT_TX, DRAIN_CHECK, REPORT_STATUS, REPORT_FINISH: req_addr=12'h010;
      READ_RX, BOOT_DRAIN_RX: req_addr=12'h004;
      WRITE_TX: begin req_write=1; req_addr=0; req_wdata={24'b0,reporting ? report_byte : temp_byte}; end
      START_TX: begin req_write=1; req_addr=12'h00c; req_wdata=1; end
      PAUSE_REQ: begin req_write=1; req_addr=12'h020; req_wdata=1; end
      APPLY_CFG: begin req_write=1; req_addr=12'h008; req_wdata={27'b0,cfg_request}; end
      APPLY_BAUD: begin req_write=1; req_addr=12'h01c; req_wdata={28'b0,baud_request_index}; end
      RELEASE_RX: begin req_write=1; req_addr=12'h020; end
      default: transaction_state=0;
    endcase
    req_strb=req_write ? 4'b0001 : 4'b0000;
    req_valid=reset_n && transaction_state && !issued;
  end
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      state<=WAIT_READY; issued<=0;
      cfg_queued<=0; baud_queued<=0; report_queued<=0;
      maintenance<=0; config_operation<=0; reporting<=0;
      desired_cfg<=3; desired_baud<=0; cfg_request<=3; active_cfg<=3;
      baud_request_index<=0; active_baud_index<=15;
      temp_byte<=0; parity_bad<=0; frame_bad<=0;
      report_index<=0; report_status<=0; report_ext<=0;
      last_rx_byte<=0; status_snapshot<=0; ext_status_snapshot<=0; error<=0;
    end else begin
      if (req_valid && req_ready) issued<=1;
      if (state==WAIT_READY && req_ready) state<=BOOT_WAIT_SAFE;
      if (state==POLL_RX && !issued && (cfg_queued || baud_queued || report_queued)) begin
        if (cfg_queued || baud_queued) begin
          cfg_request<=cfg_queued ? desired_cfg : active_cfg;
          baud_request_index<=baud_queued ? desired_baud : active_baud_index;
          cfg_queued<=0; baud_queued<=0;
          config_operation<=1; maintenance<=1; state<=PAUSE_REQ;
        end else begin
          report_queued<=0;
          if (active_cfg[1:0]==0) error<=1;
          else begin config_operation<=0; maintenance<=1; state<=PAUSE_REQ; end
        end
      end
      if (issued && done) begin
        issued<=0;
        if (response_error) begin error<=1; state<=HOST_FAULT; end
        else begin
          if (!req_write && req_addr==12'h004) last_rx_byte<=response_data[7:0];
          if (!req_write && req_addr==12'h010) status_snapshot<=response_data;
          if (!req_write && req_addr==12'h014) ext_status_snapshot<=response_data;
          case (state)
            BOOT_WAIT_SAFE: if (response_data[5]) state<=BOOT_DRAIN_RX;
              else if (response_data[6]) state<=BOOT_CFG;
            BOOT_DRAIN_RX: state<=BOOT_WAIT_SAFE;
            BOOT_CFG: state<=BOOT_VERIFY;
            BOOT_VERIFY: if (response_data!=3) begin error<=1; state<=HOST_FAULT; end
              else state<=BOOT_BAUD;
            BOOT_BAUD: if (response_data>8) begin error<=1; state<=HOST_FAULT; end
              else begin active_baud_index<=response_data[3:0]; state<=POLL_RX; end
            POLL_RX, DRAIN_CHECK: if (response_data[1]) begin parity_bad<=response_data[2]; state<=READ_META; end
              else state<=maintenance ? DRAIN_STATUS : POLL_EXT;
            POLL_EXT: state<=POLL_RX;
            READ_META: begin frame_bad<=response_data[2]; state<=READ_RX; end
            READ_RX: if (parity_bad || frame_bad) state<=maintenance ? DRAIN_STATUS : POLL_RX;
              else begin temp_byte<=response_data[7:0]; state<=WAIT_TX; end
            WAIT_TX: state<=response_data[0] ? WRITE_TX : WAIT_TX_EXT;
            WAIT_TX_EXT: state<=WAIT_TX;
            WRITE_TX: state<=START_TX;
            START_TX: if (reporting) begin
                if (report_index==67) state<=REPORT_FINISH;
                else begin report_index<=report_index+1'b1; state<=WAIT_TX; end
              end else state<=maintenance ? DRAIN_STATUS : POLL_RX;
            PAUSE_REQ: state<=DRAIN_STATUS;
            DRAIN_STATUS: if (response_data[5]) state<=DRAIN_CHECK;
              else if (response_data[6]) state<=config_operation ? APPLY_CFG : REPORT_STATUS;
            APPLY_CFG: state<=APPLY_BAUD;
            APPLY_BAUD: state<=VERIFY_CFG;
            VERIFY_CFG: if (response_data!={27'b0,cfg_request}) begin error<=1; state<=HOST_FAULT; end
              else state<=VERIFY_BAUD;
            VERIFY_BAUD: if (response_data!={28'b0,baud_request_index} || response_data>8) begin error<=1; state<=HOST_FAULT; end
              else begin active_cfg<=cfg_request; active_baud_index<=baud_request_index; state<=RELEASE_RX; end
            REPORT_STATUS: begin report_status<=response_data; state<=REPORT_EXT; end
            REPORT_EXT: begin report_ext<=response_data; report_index<=0; reporting<=1; state<=WAIT_TX; end
            REPORT_FINISH: if (response_data[0]) begin reporting<=0; state<=RELEASE_RX; end
            RELEASE_RX: begin maintenance<=0; state<=POLL_RX; end
            default: begin error<=1; state<=HOST_FAULT; end
          endcase
        end
      end
      if (state!=HOST_FAULT) begin
        if (cfg_req) begin desired_cfg<=pending_cfg; cfg_queued<=1; end
        if (baud_req) begin desired_baud<=pending_baud_index; baud_queued<=1; end
        if (report_req) report_queued<=1;
      end
    end
endmodule
