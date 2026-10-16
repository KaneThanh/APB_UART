# Pin assignments UART APB — DE2-115

Cập nhật 15/10/2026. Device `EP4CE115F29C7`, top `de2_115_uart_top`.

Hai QSF [tại đây](uart.qsf) và [bản tương ứng](../../Quartus/UART_protocol.qsf) có cùng **98 location assignments và 98 I/O-standard assignments**. Đã đối chiếu với toàn bộ bit của cổng RTL: không thiếu, không thừa, không trùng chân vật lý.

## Chức năng mới

- KEY0 reset, KEY1 tăng baud và tự áp dụng, KEY2 để trống, KEY3 gửi STATUS rồi EXT_STATUS dạng hai dòng 32 ký tự `0/1`.
- SW[4:0] tự cấu hình sau sync/debounce; không có nút Apply/Pause/Resume.
- SW5=0: HEX5..0 hiển thị baud active, HEX7/6 tắt. SW5=1: HEX7..0 hiển thị bit7..0 của byte RX gần nhất.
- LEDG[8:0] = STATUS[8:0]; LEDR[17:0] = EXT_STATUS[17:0]. Bit bằng 1 thì LED sáng. Không còn cổng LED[1:0] pending/error.
- UART_RXD → RX; UART_RTS → CTS_n (input FPGA); UART_TXD ← TX; UART_CTS ← RTS_n (output FPGA).

## Điện áp và nguồn pinout

Pinout theo [Terasic DE2-115 User Manual](https://www.terasic.com.tw/attachment/archive/502/DE2_115_User_manual.pdf), bảng clock, KEY/SW, LED, HEX và RS232. Giữ cấu hình jumper mặc định JP6 = 3.3 V (7–8), JP7 = 2.5 V (5–6). Nếu jumper thực tế khác, phải đối chiếu lại VCCIO. Toàn bộ LEDG/LEDR dùng 2.5 V.

## Bảng chân đầy đủ

| Port bit | FPGA pin | I/O standard |
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
| `LEDG[0]` | `PIN_E21` | 2.5 V |
| `LEDG[1]` | `PIN_E22` | 2.5 V |
| `LEDG[2]` | `PIN_E25` | 2.5 V |
| `LEDG[3]` | `PIN_E24` | 2.5 V |
| `LEDG[4]` | `PIN_H21` | 2.5 V |
| `LEDG[5]` | `PIN_G20` | 2.5 V |
| `LEDG[6]` | `PIN_G22` | 2.5 V |
| `LEDG[7]` | `PIN_G21` | 2.5 V |
| `LEDG[8]` | `PIN_F17` | 2.5 V |
| `LEDR[0]` | `PIN_G19` | 2.5 V |
| `LEDR[1]` | `PIN_F19` | 2.5 V |
| `LEDR[2]` | `PIN_E19` | 2.5 V |
| `LEDR[3]` | `PIN_F21` | 2.5 V |
| `LEDR[4]` | `PIN_F18` | 2.5 V |
| `LEDR[5]` | `PIN_E18` | 2.5 V |
| `LEDR[6]` | `PIN_J19` | 2.5 V |
| `LEDR[7]` | `PIN_H19` | 2.5 V |
| `LEDR[8]` | `PIN_J17` | 2.5 V |
| `LEDR[9]` | `PIN_G17` | 2.5 V |
| `LEDR[10]` | `PIN_J15` | 2.5 V |
| `LEDR[11]` | `PIN_H16` | 2.5 V |
| `LEDR[12]` | `PIN_J16` | 2.5 V |
| `LEDR[13]` | `PIN_H17` | 2.5 V |
| `LEDR[14]` | `PIN_F15` | 2.5 V |
| `LEDR[15]` | `PIN_G15` | 2.5 V |
| `LEDR[16]` | `PIN_G16` | 2.5 V |
| `LEDR[17]` | `PIN_H15` | 2.5 V |

## Giới hạn kiểm chứng

Đã kiểm tra mapping QSF với RTL và hai bản QSF khớp nhau. Cảnh báo KEY2 không điều khiển logic là đúng yêu cầu. Drive strength/slew và constraint I/O/reset vẫn cần review; không coi kiểm tra pin là timing sign-off hay kiểm chứng board vật lý.
| `SW[5]` | `PIN_AC26` | 2.5 V |
| `HEX6[0]` | `PIN_AA17` | 3.3-V LVTTL |
| `HEX6[1]` | `PIN_AB16` | 3.3-V LVTTL |
| `HEX6[2]` | `PIN_AA16` | 3.3-V LVTTL |
| `HEX6[3]` | `PIN_AB17` | 3.3-V LVTTL |
| `HEX6[4]` | `PIN_AB15` | 3.3-V LVTTL |
| `HEX6[5]` | `PIN_AA15` | 3.3-V LVTTL |
| `HEX6[6]` | `PIN_AC17` | 3.3-V LVTTL |
| `HEX7[0]` | `PIN_AD17` | 3.3-V LVTTL |
| `HEX7[1]` | `PIN_AE17` | 3.3-V LVTTL |
| `HEX7[2]` | `PIN_AG17` | 3.3-V LVTTL |
| `HEX7[3]` | `PIN_AH17` | 3.3-V LVTTL |
| `HEX7[4]` | `PIN_AF17` | 3.3-V LVTTL |
| `HEX7[5]` | `PIN_AG18` | 3.3-V LVTTL |
| `HEX7[6]` | `PIN_AA14` | 3.3-V LVTTL |
