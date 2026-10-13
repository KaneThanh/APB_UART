# Kiến trúc UART APB — DE2-115

Mở `UART_APB_ARCHITECTURE.drawio.xml` hoặc `UART_APB_ARCHITECTURE.drawio` trong draw.io bằng **File → Open From → Device**. Hai file có cùng nội dung. Tất cả khối, cổng và dây là đối tượng vector chỉnh sửa được, không phải ảnh được chèn vào XML.

Bản cập nhật 13/10/2026 gồm **19 trang**: 01–13 giữ profile RTL Master, 14–19 bổ sung kiến trúc và flowchart CPU Nios II theo `../NIOS_LCD/firmware/app.c` và RTL peripheral mới. CPU system chưa generate/chạy trên board do bộ cài hiện tại thiếu Nios II IP; sơ đồ không khẳng định đã có SOF CPU.

## Các trang CPU mới

| Trang | Nội dung |
|---|---|
| 14 | NIOS_SYSTEM_ARCHITECTURE: CPU, RAM, Avalon→APB, UART, IO, LCD; tên bus và độ rộng |
| 15 | BOOT_AND_MAIN_LOOP: boot 8N1/B7, readback và vòng phục vụ không blocking |
| 16 | RX_TX_DATA_FLOW: đọc metadata trước pop, bỏ word lỗi, hàng đợi echo và TX START |
| 17 | SW_KEY_AND_REPORT: debounce, SW5 chọn register, SW6 gửi report, KEY Apply/Resume |
| 18 | APPLY_RESUME_CONFIG_FSM: Drain, Paused, Resume queued, timeout và FLOW_CTRL |
| 19 | LCD_RX_TEXT_AND_REFRESH: prefix16ký tự, CR/LF, idle gap, status dòng2 và RTL refresh |

Có bản riêng chứa 6 trang CPU: [NIOS_CPU_FLOWCHARTS.drawio](flowcharts/NIOS_CPU_FLOWCHARTS.drawio). Cả khối, chữ và dây đều chỉnh sửa được trong draw.io. Xem nhanh [trang CPU trong index](index.html#14).

`SIGNAL_CONNECTIONS.csv`, `validation.json` và `rtl_interface_audit.json` thuộc phạm vi 13 trang RTL; kiểm tra cấu trúc 6 trang CPU ở `cpu_diagram_validation.json`. `native_render_checks.json` bao gồm cả 19 trang. Sau khi tái tạo bộ RTL bằng script cũ, chạy `python build_cpu_diagrams.py`, `node render_drawio.mjs 14`, rồi `python finalize_artifacts.py` để bổ sung lại phần CPU và đóng gói.

Mở `index.html` để xem nhanh từng trang; ảnh SVG và PNG đầy đủ nằm trong `previews/`. `SIGNAL_CONNECTIONS.csv` liệt kê từng kết nối với nguồn, đích và độ rộng.

## Các trang

| Nhóm | Trang | Nội dung |
|---|---:|---|
| BOARD | 01 | SYSTEM_ARCHITECTURE: toàn hệ thống DE2-115, Board Controls, Echo Master, UART và PC |
| BOARD | 02 | TOP_INPUT_OUTPUT: cổng vật lý của de2_115_uart_top |
| HOST | 03 | APB_TRANSACTION_MASTER: request/response ứng dụng và giao dịch APB |
| UART | 04 | TOP_INPUT_OUTPUT: toàn bộ cổng uart_apb_top |
| UART | 05 | SIMPLE_DATAPATH: kết nối nội bộ UART, APB slave/registers, TX/RX và CTS/RTS |
| APB | 06 | SLAVE_INTERFACE: handshake tổ hợp và rd_fire/wr_fire |
| APB | 07 | REGISTERS_INTERFACE: giao diện đầy đủ uart_regs |
| APB | 08 | REGISTERS_DATAPATH: decoder/guard, storage/control và read mux/status |
| TX | 09 | FSM_INTERFACE: control và feedback của TX FSM |
| TX | 10 | DATAPATH: frame packing, shift, bit counter và baud tick ×1 |
| RX | 11 | FSM_INTERFACE: control và feedback của RX FSM |
| RX | 12 | DATAPATH: sync, sampling ×16, parity/stop, holding slot và RTS |
| COMMON | 13 | RESET_SYNC: module đồng bộ reset và startup ready dùng chung |

Thứ tự đọc: **BOARD → HOST → UART → APB → TX → RX → COMMON**. Board top chứa UART top; trang Simple Datapath chỉ mở rộng phần UART top. APB_MASTER trên trang này là peer ở ngoài UART IP.

## Cách đọc

- Tên cổng nằm cạnh đầu dây. `name [7:0]` là bus 8 bit; số giữa dây là độ rộng tính bằng bit. Mũi tên chỉ chiều producer → consumer.
- Những khối peer cùng tên xuất hiện ở hai phía của một trang là hai góc nhìn của cùng khối. Ví dụ, TX_FSM ở trái phát control và TX_FSM ở phải nhận feedback; không phải hai FSM TX được tạo riêng.
- Trang 01–02 là hệ thống board; trang 03 là host giao dịch; trang 04–05 là UART IP; trang 06–12 mở rộng các khối APB/TX/RX. COMMON RESET_SYNC ở cuối dùng được cho cả board và core. TOP_MODULE cũ đã xóa; số 07 hiện dùng cho REGISTERS_INTERFACE.
- Trang 01 là hệ thống board được chọn: BOARD_CONTROLS tạo yêu cầu, APB_ECHO_MASTER_FSM làm master RTL duy nhất.
- Các bản vẽ chỉ chứa tên khối, cổng và số bit. Ghi chú timing và lựa chọn thiết kế được đặt trong tài liệu này.

## Profile thiết kế được dùng

Đây là kiến trúc đề xuất cho hệ thống **một PC ↔ FPGA UART ↔ APB host**, dựa trên yêu cầu đã chốt và phần chia FSM/datapath trong NDM_UART. File UART hai PC được dùng làm tham khảo cách biểu diễn khối và dây.

- Clock core và APB dùng chung `clk` 50 MHz; `reset_n` được assert bất đồng bộ và release đồng bộ qua reset_sync. Interface UART top chỉ có một cặp clock/reset; pclk và presetn đã được xóa theo RTL.
- APB profile có address 12 bit dạng byte offset, data 32 bit và PSTRB 4 bit. `rd_fire`/`wr_fire` là enable tại cạnh hoàn tất thành công; request bị reject báo PSLVERR và không có write/pop/START side effect.
- Payload UART có storage 8 bit, hỗ trợ độ dài 5–8 bit. `cfg_active[4:0]` gồm data length 2 bit, parity enable 1 bit, parity even 1 bit, two stops 1 bit. Frame TX tối đa 12 bit.
- Baud số nguyên nội bộ dùng 18 bit, đủ chứa 230400. Bảng baud gồm 2400, 4800, 9600, 19200, 38400, 57600, 76800, 115200, 230400. Clock/baud mặc định khai báo bằng parameter; runtime baud selection là mở rộng được cho phép bằng `RUNTIME_BAUD_EN` để phục vụ nút chọn baud trong demo.
- TX dùng tick phân số ×1 trong TX_BIT_TIMER; RX dùng ×16 trong RX_TIMING. TX_OS_COUNTER đã bỏ; OS counter 4 bit giữ bên trong RX_TIMING. Tick là clock-enable.
- TX_FRAME_DATAPATH gộp packer, shift, bit counter và TX output. tx_advance đồng thời shift/đổi bit/giảm counter. TX_BIT_TIMER gộp baud snapshot và bộ tạo bit tick; tx_load chụp baud, tx_begin reset phase, tx_run chạy timer.
- RX_FRAME_DATAPATH gộp config snapshot, data/stop counters, shift/parity/errors. Index tự tăng theo sample enable. RX_TIMING gộp baud snapshot, tick ×16 và OS counter; rx_load reset phase, rx_os_clr căn lại count sau START midpoint.
- RX_BUFFER_FLOW gộp holding slot, full/drop logic và RTS output. Slot sở hữu duy nhất data/valid/metadata; RTS dùng next occupancy/pause/ready. Metadata giữ lỗi parity/stop của byte đang lưu; full không pop thì drop frame mới, giữ byte/metadata cũ.
- APB datapath còn 3 khối: ADDRESS_ACCESS_DECODE tính guard và access_error; TX_CFG_BAUD_FLOW_REGS giữ staging/config/index/pause; READ_DATA_MUX ghép status và zero-extend readback từ storage bus hẹp. Bỏ các bus readback 32 bit trùng dữ liệu và bus CTRL hằng 0.
- Bỏ STATUS_GUARD_PACK, ERROR_W1C_BANK và các event chỉ phục vụ sticky history. reg_sel rộng 8 bit, mapping TX_DATA/RX_DATA/CFG/CTRL/STATUS/EXT_STATUS/BAUD_SEL/FLOW_CTRL; offset còn lại giữ nguyên, 0x018 không map và trả PSLVERR. Guard dùng rx_sync thay cho fanout rx_fall tới APB.
- APB echo master đọc RX_DATA, giữ byte rồi ghi TX_DATA/START. Echo là công việc của host, không phải dây nối tắt RX sang TX bên trong IP.
- KEY0_N được nối vào CLOCK_RESET; KEY1 chọn index baud, KEY2 Apply, KEY3 Resume. SW được hoán vị thành CFG[4:0]={SW3,SW2,SW4,SW1,SW0}. BOARD_CONTROLS không điều khiển APB trực tiếp.
- UART tự phát hiện parity/framing và lưu metadata cùng RX slot. Master đọc STATUS/EXT_STATUS trước RX_DATA, bỏ byte lỗi hoặc echo byte tốt. PSLVERR/readback sai là lỗi host riêng.
- Demo board dùng KEY[3:0], SW[4:0], HEX0–5[6:0] và hai LED. Dùng sáu chữ số HEX để hiển thị trọn 230400; cấu hình chỉ có hiệu lực khi host thực hiện APB write hợp lệ.

## UART IP và tên chân DE2-115

Tên RTS/CTS của board khác tên tín hiệu handshake nhìn từ UART IP. Phải dùng chiều tín hiệu khi đấu nối:

| Cổng IP | Cổng board | Chiều tại FPGA | Chân FPGA |
|---|---|---|---|
| rx | UART_RXD | Input | G12 |
| tx | UART_TXD | Output | G9 |
| cts_n | UART_RTS | Input | J13 |
| rts_n | UART_CTS | Output | G14 |

Các dây RS-232 đi qua ZT3232 trên board; không đưa mức điện áp RS-232 trực tiếp vào GPIO FPGA. PC phía ngoài là một thiết bị UART/terminal. Khi dùng USB-to-UART TTL trên GPIO thay cho cổng RS-232 của board, phải thay wrapper chân và xác nhận mức logic/RTS/CTS của adapter.

## Nguồn tham khảo và kiểm tra

- NDM_UART.pdf, final_project_design_requirements_rev0p0p1.pdf, dti_uart.pdf và bộ specification hiện tại trong `../uart_design_20261011/`.
- `D:/Download/uart.drawio.xml` và ảnh đi kèm: tham khảo bố cục UART hai PC, không sao chép topology đó.
- Skill tìm được: [drawio-skill](https://github.com/keathmilligan/drawio-skill), hỗ trợ tạo XML architecture trực tiếp. Đây là nguồn tham khảo; không cài thêm skill vào môi trường.
- Cấu trúc XML theo [tài liệu chính thức draw.io](https://www.drawio.com/docs/reference/diagram-generation/), kiểm tra bằng [mxfile.xsd](https://github.com/jgraph/drawio-mcp/blob/main/shared/mxfile.xsd).

`validation.json` ghi kiểm tra endpoint, độ rộng dây, input chỉ có một driver và không chồng khối. `native_render_checks.json` ghi kết quả render từng trang bằng viewer của draw.io. `verification_summary.json` ghi kết quả schema và tổng kết. Các kiểm tra này xác nhận artifact sơ đồ; chưa thay thế mô phỏng RTL/testbench.

`build_uart_drawio.py` tạo lại XML và bảng kết nối bằng Python standard library. Bản SVG/PNG đã xuất sẵn để xem mà không cần runtime tạo ảnh.

## Bản rút gọn và tài liệu FSM

Xem [bảng FSM đầy đủ](../uart_design_20261011/11_FSM_TABLES.md). Trang 05 thể hiện các đường dữ liệu/control chính; tín hiệu lỗi chi tiết có ở trang 12. Các khối timing và frame datapath chứa nhiều thanh ghi nhưng vẫn dùng đúng một owner cho mỗi thanh ghi.

[Bảng interface từng khối](../uart_design_20261011/10_INTERFACE_CONTRACTS.md) ghi Input/Output, số bit, đầu nối và ý nghĩa theo XML hiện tại; có phần riêng cho TX/RX, APB/register datapath, Board Controls, Echo Master và board wrapper. Baud generator đã nằm trong TX_BIT_TIMER (×1) và RX_TIMING (×16).

[Flowchart RTL — draw.io 4 trang](flowcharts/APB_MASTER_FLOWCHARTS.drawio.xml): BOARD_CONTROLS, Echo Master Boot/Echo, Echo Master Apply/Resume và APB transaction. Xem [hướng dẫn triển khai FSM](../uart_design_20261011/12_APB_MASTER_FLOWCHART.md) hoặc mở [gallery flowchart](flowcharts/index.html).

Hai thư mục `revision_before_*` chỉ lưu lịch sử cũ và không được đóng vào ZIP bàn giao; không dùng chúng để viết RTL. Workbook specification v0.1 cũng chứa map/interface trước các cập nhật này; dùng XML và bảng Markdown hiện tại cho việc chia module, thanh ghi và tín hiệu.

## Độ đầy đủ của interface và mức giản lược

- Các khối module ở trang chi tiết có đầy đủ cổng đúng tên, chiều và độ rộng của RTL. `rtl_interface_audit.json` ghi kết quả đối chiếu tự động. Các hộp peer chỉ lặp lại những cổng liên quan đến trang đang xem, không phải một instance mới.
- Simple Datapath giữ đủ 9 dây APB: PSEL/PENABLE/PWRITE/PADDR[11:0]/PWDATA[31:0]/PSTRB[3:0] đi vào; PRDATA[31:0]/PREADY/PSLVERR đi ra. Register bank nối APB slave bằng access_error, wr_fire và rd_fire.
- Simple Datapath giữ đủ các đường chức năng: TX staging/config/baud/accept/busy; RX word/push/errors; slot data/valid/metadata/pop; CTS/RTS/pause; RX sync và guard/status readback. Chỉ ẩn fanout clock/reset/startup lặp lại ở từng khối; box SHARED CONTROL NETS là ký hiệu nối chung, không phải một module RTL mới.
- CLOCK_RESET ở trang 01 gom kết nối clock/reset của board. Trang 05 dùng đúng module RESET_SYNC và nối clk trực tiếp tới SHARED CONTROL NETS (WIRES). Trang 13 mô tả đầy đủ module reset_sync. `board_ready` từ reset_sync cấp board hiện không có consumer trong RTL; không giả tạo dây điều khiển từ tín hiệu này.
- Trang 08 chia logic bên trong uart_regs thành decoder, register bank và read mux. Đây không phải ba module Verilog độc lập. `RUNTIME_BAUD_EN` là parameter, không phải cổng runtime của uart_regs. Net nội bộ đúng tên là `baud_sel[3:0]`.
- Trang 03 mô tả submodule apb_transaction_master thực sự được apb_echo_master instantiate; nó nhận request từ logic ECHO_MASTER_FSM và trả response/done, giữ bus APB qua SETUP/ACCESS.
- Các thư mục `revision_before_*` là bản lưu lịch sử; không thuộc bộ sơ đồ đang dùng hoặc ZIP phát hành.

Chi tiết thay đổi: [REVIEW_CHANGES.md](REVIEW_CHANGES.md).
