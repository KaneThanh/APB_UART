module lcd_text #(
  parameter integer CLK_HZ=50000000
) (
  input wire clk, reset_n,
  input wire wr,
  input wire [4:0] index,
  input wire [7:0] data,
  output reg [7:0] lcd_data,
  output reg lcd_rs,
  output wire lcd_rw,
  output reg lcd_en,
  output wire lcd_on, lcd_blon
);
  localparam integer US=(CLK_HZ/1000000 < 1) ? 1 : CLK_HZ/1000000;
  reg [7:0] text_mem [0:31];
  reg [31:0] timer;
  reg [2:0] state;
  reg [3:0] init_step;
  reg [5:0] cursor;
  integer i;
  assign lcd_rw=0;
  assign lcd_on=1;
  assign lcd_blon=0;
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      for (i=0;i<32;i=i+1) text_mem[i]<=8'h20;
    end else if (wr) text_mem[index]<=data;
  always @(posedge clk or negedge reset_n)
    if (!reset_n) begin
      timer<=50000*US; state<=0; init_step<=0; cursor<=0;
      lcd_en<=0; lcd_rs<=0; lcd_data<=0;
    end else if (timer!=0) timer<=timer-1;
    else case (state)
      0: begin
        lcd_rs<=0;
        case (init_step)
          0,1,2: lcd_data<=8'h30;
          3: lcd_data<=8'h38;
          4: lcd_data<=8'h08;
          5: lcd_data<=8'h01;
          6: lcd_data<=8'h06;
          7: lcd_data<=8'h0c;
          default: begin
            if (cursor==0) lcd_data<=8'h80;
            else if (cursor==17) lcd_data<=8'hc0;
            else begin
              lcd_rs<=1;
              if (cursor<17) lcd_data<=text_mem[cursor-1];
              else lcd_data<=text_mem[cursor-2];
            end
          end
        endcase
        timer<=US; state<=1;
      end
      1: begin lcd_en<=1; timer<=US; state<=2; end
      2: begin
        lcd_en<=0;
        timer<=5000*US;
        state<=3;
      end
      3: begin
        if (init_step<8) init_step<=init_step+1;
        else if (cursor==33) cursor<=0;
        else cursor<=cursor+1;
        state<=0;
      end
      default: state<=0;
    endcase
endmodule
