# Pin assignments DE2-115 cho UART

Cập nhật 12/10/2026. Device: `EP4CE115F29C7`; top: `de2_115_uart_top`.

Pinout lấy từ Terasic DE2-115 User Manual, bảng 4-1 (SW), 4-2 (KEY), 4-3 (LED), 4-4 (HEX), 4-5 (clock), 4-18 (UART).

Nguồn: [Terasic manual](https://www.terasic.com.tw/attachment/archive/502/DE2_115_User_manual.pdf).

Hai QSF dùng cùng 58 location assignments và 58 I/O-standard assignments: [uart.qsf](uart.qsf) và [UART_protocol.qsf](../../Quartus/UART_protocol.qsf). LED[0] nối LEDR0 (pending), LED[1] nối LEDR1 (host fault).

## Điện áp board

- JP6: short pins 7–8, 3.3 V mặc định (bảng 4-11).
- JP7: short pins 5–6, 2.5 V mặc định (bảng 4-8).
- QSF đang dùng hai mức trên. Nếu board đã đổi jumper, cần đổi I/O standard cho đúng VCCIO thực; không tự đổi tất cả chân thành 3.3 V.

## Bảng chân

| Cổng RTL | Chân FPGA | I/O standard |
|---|---|---|
| `CLOCK_50` | `PIN_Y2` | 3.3-V LVTTL |
| `KEY[0]` | `PIN_M23` | 2.5 V |
| `KEY[1]` | `PIN_M21` | 2.5 V |
| `KEY[2]` | `PIN_N21` | 2.5 V |
| `KEY[3]` | `PIN_R24` | 2.5 V |
| `SW[0]` | `PIN_AB28` | 2.5 V |
| `SW[1]` | `PIN_AC28` | 2.5 V |
| `SW[2]` | `PIN_AC27` | 2.5 V |
| `SW[3]` | `PIN_AD27` | 2.5 V |
| `SW[4]` | `PIN_AB27` | 2.5 V |
| `UART_RXD` | `PIN_G12` | 3.3-V LVTTL |
| `UART_RTS` | `PIN_J13` | 3.3-V LVTTL |
| `UART_TXD` | `PIN_G9` | 3.3-V LVTTL |
| `UART_CTS` | `PIN_G14` | 3.3-V LVTTL |
| `HEX0[0]` | `PIN_G18` | 2.5 V |
| `HEX0[1]` | `PIN_F22` | 2.5 V |
| `HEX0[2]` | `PIN_E17` | 2.5 V |
| `HEX0[3]` | `PIN_L26` | 2.5 V |
| `HEX0[4]` | `PIN_L25` | 2.5 V |
| `HEX0[5]` | `PIN_J22` | 2.5 V |
| `HEX0[6]` | `PIN_H22` | 2.5 V |
| `HEX1[0]` | `PIN_M24` | 2.5 V |
| `HEX1[1]` | `PIN_Y22` | 2.5 V |
| `HEX1[2]` | `PIN_W21` | 2.5 V |
| `HEX1[3]` | `PIN_W22` | 2.5 V |
| `HEX1[4]` | `PIN_W25` | 2.5 V |
| `HEX1[5]` | `PIN_U23` | 2.5 V |
| `HEX1[6]` | `PIN_U24` | 2.5 V |
| `HEX2[0]` | `PIN_AA25` | 2.5 V |
| `HEX2[1]` | `PIN_AA26` | 2.5 V |
| `HEX2[2]` | `PIN_Y25` | 2.5 V |
| `HEX2[3]` | `PIN_W26` | 2.5 V |
| `HEX2[4]` | `PIN_Y26` | 2.5 V |
| `HEX2[5]` | `PIN_W27` | 2.5 V |
| `HEX2[6]` | `PIN_W28` | 2.5 V |
| `HEX3[0]` | `PIN_V21` | 2.5 V |
| `HEX3[1]` | `PIN_U21` | 2.5 V |
| `HEX3[2]` | `PIN_AB20` | 3.3-V LVTTL |
| `HEX3[3]` | `PIN_AA21` | 3.3-V LVTTL |
| `HEX3[4]` | `PIN_AD24` | 3.3-V LVTTL |
| `HEX3[5]` | `PIN_AF23` | 3.3-V LVTTL |
| `HEX3[6]` | `PIN_Y19` | 3.3-V LVTTL |
| `HEX4[0]` | `PIN_AB19` | 3.3-V LVTTL |
| `HEX4[1]` | `PIN_AA19` | 3.3-V LVTTL |
| `HEX4[2]` | `PIN_AG21` | 3.3-V LVTTL |
| `HEX4[3]` | `PIN_AH21` | 3.3-V LVTTL |
| `HEX4[4]` | `PIN_AE19` | 3.3-V LVTTL |
| `HEX4[5]` | `PIN_AF19` | 3.3-V LVTTL |
| `HEX4[6]` | `PIN_AE18` | 3.3-V LVTTL |
| `HEX5[0]` | `PIN_AD18` | 3.3-V LVTTL |
| `HEX5[1]` | `PIN_AC18` | 3.3-V LVTTL |
| `HEX5[2]` | `PIN_AB18` | 3.3-V LVTTL |
| `HEX5[3]` | `PIN_AH19` | 3.3-V LVTTL |
| `HEX5[4]` | `PIN_AG19` | 3.3-V LVTTL |
| `HEX5[5]` | `PIN_AF18` | 3.3-V LVTTL |
| `HEX5[6]` | `PIN_AH18` | 3.3-V LVTTL |
| `LED[0]` | `PIN_G19` | 2.5 V |
| `LED[1]` | `PIN_F19` | 2.5 V |

## Phạm vi kiểm tra

Location/I/O standard đã bao phủ toàn bộ cổng board top. `uart.sdc` có clock 50 MHz, nhưng vẫn cần review ngoại lệ async và external I/O timing trước timing sign-off. Chưa có kiểm chứng trên board vật lý.

`sim/synthesize.tcl` và project `build/synthesis` chỉ phục vụ Analysis & Synthesis; pin constraints để fit board nằm trong hai QSF được liên kết ở trên.

Kết quả mới: Analysis & Synthesis và Fitter thành công, không còn cảnh báo 169085. Xem [report kiểm tra](../reports/DE2_115_PIN_ASSIGNMENT_CHECK.md) để biết các warning còn lại và giới hạn kiểm chứng.
