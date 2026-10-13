`default_nettype none
module apb_echo_master (
  input wire clk,
  input wire reset_n,
  input wire [4:0] pending_cfg,
  input wire [3:0] pending_baud_index,
  input wire apply_req,
  input wire resume_req,
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
  output reg error,
  output reg pending
);
  localparam [4:0] WAIT_READY=5'd0,
    BOOT_WAIT_SAFE=5'd1,
    BOOT_CFG=5'd2,
    BOOT_VERIFY=5'd3,
    BOOT_BAUD=5'd4,
    POLL_RX=5'd5,
    READ_META=5'd6,
    READ_RX=5'd7,
    WAIT_TX=5'd8,
    WRITE_TX=5'd9,
    START_TX=5'd10,
    PAUSE_REQ=5'd11,
    DRAIN_STATUS=5'd12,
    DRAIN_RX=5'd13,
    APPLY_CFG=5'd14,
    APPLY_BAUD=5'd15,
    VERIFY_CFG=5'd16,
    VERIFY_BAUD=5'd17,
    PAUSED_READY=5'd18,
    RESUME_REQ=5'd19,
    HOST_FAULT=5'd20,
    BOOT_DRAIN_RX=5'd21;
  reg [4:0] state;
  reg req_valid;
  wire req_ready;
  reg req_write;
  wire done;
  wire response_error;
  reg [11:0] req_addr;
  reg [31:0] req_wdata;
  wire [31:0] response_data;
  reg [3:0] req_strb;
  reg issued;
  reg transaction_state;
  reg apply_queued;
  reg resume_queued;
  reg temp_valid;
  reg [7:0] temp_byte;
  reg parity_bad;
  reg frame_bad;
  reg [4:0] cfg_request;
  reg [4:0] active_cfg;
  reg [3:0] baud_request_index;
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
    transaction_state=1; req_write=0; req_addr=0; req_wdata=0;
    case (state)
      BOOT_WAIT_SAFE, READ_META, DRAIN_STATUS: req_addr=12'h014;
      BOOT_CFG: begin req_write=1; req_addr=12'h008; req_wdata=3; end
      BOOT_VERIFY, VERIFY_CFG: req_addr=12'h008;
      BOOT_BAUD, VERIFY_BAUD: req_addr=12'h01c;
      POLL_RX: begin req_addr=12'h010; if (apply_queued && !temp_valid) transaction_state=0; end
      WAIT_TX: req_addr=12'h010;
      READ_RX, DRAIN_RX, BOOT_DRAIN_RX: req_addr=12'h004;
      WRITE_TX: begin req_write=1; req_addr=12'h000; req_wdata={24'b0,temp_byte}; end
      START_TX: begin req_write=1; req_addr=12'h00c; req_wdata=1; end
      PAUSE_REQ: begin req_write=1; req_addr=12'h020; req_wdata=1; end
      APPLY_CFG: begin req_write=1; req_addr=12'h008; req_wdata={27'b0,cfg_request}; end
      APPLY_BAUD: begin req_write=1; req_addr=12'h01c; req_wdata={28'b0,baud_request_index}; end
      RESUME_REQ: begin req_write=1; req_addr=12'h020; req_wdata=0; end
      default: transaction_state=0;
    endcase
    req_strb=req_write ? 4'b0001 : 4'b0000;
    req_valid=reset_n && transaction_state && !issued;
  end

  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      state<=WAIT_READY; issued<=0; apply_queued<=0; resume_queued<=0; temp_valid<=0;
      temp_byte<=0; parity_bad<=0; frame_bad<=0;
      cfg_request<=0; baud_request_index<=0; active_cfg<=0;
      active_baud_index<=4'hf; error<=0; pending<=0;
    end else begin
      if (apply_req && state!=HOST_FAULT && (!pending || state==PAUSED_READY)) begin
        cfg_request<=pending_cfg; baud_request_index<=pending_baud_index;
        apply_queued<=1; pending<=1;
        resume_queued<=resume_req;
      end
      else if (resume_req && pending && state!=HOST_FAULT) resume_queued<=1;
      if (req_valid && req_ready) issued<=1;
      if (state==WAIT_READY && req_ready) state<=BOOT_WAIT_SAFE;
      if (state==POLL_RX && apply_queued && !issued && !temp_valid) state<=PAUSE_REQ;
      if (state==PAUSED_READY) begin
        if (apply_req || apply_queued) state<=DRAIN_STATUS;
        else if (resume_req || resume_queued) state<=RESUME_REQ;
      end
      if (issued && done) begin
        issued<=0;
        if (response_error) begin error<=1; state<=HOST_FAULT; end
        else case (state)
          BOOT_WAIT_SAFE: if (response_data[5]) state<=BOOT_DRAIN_RX;
            else if (response_data[6]) state<=BOOT_CFG;
          BOOT_DRAIN_RX: state<=BOOT_WAIT_SAFE;
          BOOT_CFG: state<=BOOT_VERIFY;
          BOOT_VERIFY: if (response_data!=32'h03) begin error<=1; state<=HOST_FAULT; end
            else begin active_cfg<=5'h03; state<=BOOT_BAUD; end
          BOOT_BAUD: if (response_data>8) begin error<=1; state<=HOST_FAULT; end
            else begin active_baud_index<=response_data[3:0]; state<=POLL_RX; end
          POLL_RX: if (response_data[1]) begin parity_bad<=response_data[2]; state<=READ_META; end
          READ_META: begin frame_bad<=response_data[2]; state<=READ_RX; end
          READ_RX: if (parity_bad || frame_bad) begin temp_valid<=0; state<=POLL_RX; end
            else begin temp_byte<=response_data[7:0]; temp_valid<=1; state<=WAIT_TX; end
          WAIT_TX: if (response_data[0]) state<=WRITE_TX;
          WRITE_TX: state<=START_TX;
          START_TX: begin temp_valid<=0; state<=POLL_RX; end
          PAUSE_REQ: state<=DRAIN_STATUS;
          DRAIN_STATUS: if (response_data[5]) state<=DRAIN_RX;
            else if (response_data[6]) state<=APPLY_CFG;
          DRAIN_RX: state<=DRAIN_STATUS;
          APPLY_CFG: state<=APPLY_BAUD;
          APPLY_BAUD: state<=VERIFY_CFG;
          VERIFY_CFG: if (response_data!={27'b0,cfg_request}) begin error<=1; state<=HOST_FAULT; end
            else state<=VERIFY_BAUD;
          VERIFY_BAUD: if (response_data!={28'b0,baud_request_index} || response_data>8) begin
              error<=1; state<=HOST_FAULT;
            end else begin
              active_cfg<=cfg_request; active_baud_index<=baud_request_index;
              apply_queued<=0; state<=PAUSED_READY;
            end
          RESUME_REQ: begin pending<=0; resume_queued<=0; state<=POLL_RX; end
          default: begin error<=1; state<=HOST_FAULT; end
        endcase
      end
    end
endmodule

`default_nettype wire
