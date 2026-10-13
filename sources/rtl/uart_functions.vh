function [17:0] baud_value;
  input [3:0] index;
  begin
    case (index)
      0: baud_value=2400; 1: baud_value=4800; 2: baud_value=9600;
      3: baud_value=19200; 4: baud_value=38400; 5: baud_value=57600;
      6: baud_value=76800; 7: baud_value=115200; 8: baud_value=230400;
      default: baud_value=115200;
    endcase
  end
endfunction
function [3:0] baud_index;
  input integer baud;
  begin
    case (baud)
      2400: baud_index=0; 4800: baud_index=1; 9600: baud_index=2;
      19200: baud_index=3; 38400: baud_index=4; 57600: baud_index=5;
      76800: baud_index=6; 115200: baud_index=7; 230400: baud_index=8;
      default: baud_index=15;
    endcase
  end
endfunction
function integer uart_clog2;
  input integer value;
  integer remaining;
  begin
    remaining=value-1;
    uart_clog2=0;
    while (remaining>0) begin
      uart_clog2=uart_clog2+1;
      remaining=remaining>>1;
    end
  end
endfunction
